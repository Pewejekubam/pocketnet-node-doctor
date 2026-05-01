package diagnose

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"strings"

	"github.com/pocketnet-team/pocketnet-node-doctor/internal/exitcode"
	"github.com/pocketnet-team/pocketnet-node-doctor/internal/manifest"
	"github.com/pocketnet-team/pocketnet-node-doctor/internal/plan"
	"github.com/pocketnet-team/pocketnet-node-doctor/internal/preflight"
	"github.com/pocketnet-team/pocketnet-node-doctor/internal/stderrlog"
)

// Options is the diagnose pathway's input.
type Options struct {
	CanonicalURL string
	PocketDBPath string
	PlanOutPath  string
	PinnedHash   string
	Logger       *stderrlog.Logger
	Transport    http.RoundTripper // optional; nil for production
}

// Diagnose executes the read-only diagnose pathway per cli-surface.md
// § Predicate Sequence. Returns the typed exit code and a wrapped error
// (nil on Success). The orchestrator stops at the first refusal and
// emits the diagnostic to stderr via opts.Logger.
//
// Sequence:
//  1. Argument validation (caller's responsibility before invoking)
//  2. running-node predicate
//  3. Manifest fetch + verify + parse + format_version + trust_anchors
//  4. version-mismatch -> volume-capacity -> permission-readonly -> ahead-of-canonical
//  5. plan-out writability probe
//  6. Hash phase (page-compare + file-compare)
//  7. Plan emission (atomic write)
//  8. Summary emission
func Diagnose(ctx context.Context, opts Options) (exitcode.Code, error) {
	logger := opts.Logger
	if logger == nil {
		logger = stderrlog.New(false)
	}

	// 1. running-node predicate (PRE-manifest per D8)
	pre := preflight.PreManifest()
	if res := pre.Fn(preflight.PreflightContext{PocketDBPath: opts.PocketDBPath, Logger: logger}); !res.Pass {
		logger.Info(res.Refused.Diagnostic)
		return res.Refused.Code, fmt.Errorf("%s", res.Refused.Diagnostic)
	}

	// 2. Manifest fetch + verify + parse + format_version + trust_anchors
	body, err := manifest.Fetch(ctx, opts.CanonicalURL, opts.Transport)
	if err != nil {
		logger.Info("manifest fetch failed: %v", err)
		return exitcode.GenericError, err
	}
	if err := manifest.Verify(body, opts.PinnedHash); err != nil {
		logger.Info("manifest verify failed: %v", err)
		if manifest.IsTrustRootMismatch(err) {
			return exitcode.GenericError, err
		}
		return exitcode.GenericError, err
	}
	m, err := manifest.Parse(body)
	if err != nil {
		logger.Info("manifest parse failed: %v", err)
		return exitcode.GenericError, err
	}
	if err := manifest.CheckFormatVersion(m); err != nil {
		logger.Info("manifest format_version refused: %v", err)
		if manifest.IsFormatVersionUnrecognized(err) {
			return exitcode.ManifestFormatVersionUnrecognized, err
		}
		return exitcode.GenericError, err
	}
	if _, err := manifest.ParseTrustAnchors(m); err != nil {
		logger.Info("manifest trust_anchors absent: %v", err)
		return exitcode.GenericError, err
	}

	// 3. Post-manifest predicates
	pctx := preflight.PreflightContext{PocketDBPath: opts.PocketDBPath, Manifest: m, Logger: logger}
	if name, res, _ := preflight.EvaluateOrdered(pctx, preflight.PostManifestOrder()); !res.Pass {
		logger.Info("preflight refused (%s): %s", name, res.Refused.Diagnostic)
		return res.Refused.Code, fmt.Errorf("%s: %s", name, res.Refused.Diagnostic)
	}

	// 4. Plan-out writability probe (D6)
	if err := ProbeWritable(opts.PlanOutPath); err != nil {
		logger.Info("plan-out writability probe failed: %v", err)
		return exitcode.GenericError, err
	}

	// 5. Hash phase
	prog := NewProgressEmitter(logger)
	divergences, err := computeDivergences(opts.PocketDBPath, m, prog)
	if err != nil {
		logger.Info("hash phase failed: %v", err)
		return exitcode.GenericError, err
	}

	// 6. Plan emission
	manifestHash := sha256OfBytes(body)
	p := plan.Plan{
		FormatVersion: plan.FormatVersion,
		CanonicalIdentity: plan.CanonicalIdentity{
			BlockHeight:          m.CanonicalIdentity.BlockHeight,
			ManifestHash:         opts.PinnedHash,
			PocketnetCoreVersion: m.CanonicalIdentity.PocketnetCoreVersion,
		},
		Divergences: divergences,
	}
	selfHash, err := plan.ComputeSelfHash(p)
	if err != nil {
		return exitcode.GenericError, err
	}
	p.SelfHash = selfHash
	_ = manifestHash // for future use; the canonical-identity manifest_hash uses the verified pinned hash

	if err := WritePlanAtomic(p, opts.PlanOutPath); err != nil {
		logger.Info("plan write failed: %v", err)
		return exitcode.GenericError, err
	}

	// 7. Summary emission
	EmitSummary(stderrWriter(logger), p, m)

	return exitcode.Success, nil
}

// computeDivergences runs page-compare on sqlite_pages entries and file-compare
// on whole_file entries. Returns the divergence list ordered: sqlite_pages
// first (sorted by path), then whole_file (sorted by path).
func computeDivergences(pocketdbRoot string, m *manifest.Manifest, prog *ProgressEmitter) ([]plan.Divergence, error) {
	var sqliteDivs, wfDivs []plan.Divergence
	classCounts := map[string]int{} // for progress

	for _, e := range m.Entries {
		switch e.EntryKind {
		case manifest.EntryKindSQLitePages:
			started := prog.Enter(e.Path)
			pages, err := ComparePages(pocketdbRoot, e)
			if err != nil {
				return nil, err
			}
			prog.Exit(e.Path, started)
			if len(pages) > 0 {
				sqliteDivs = append(sqliteDivs, plan.Divergence{
					Kind:  plan.DivergenceKindSQLitePages,
					Path:  e.Path,
					Pages: pages,
				})
			}
		case manifest.EntryKindWholeFile:
			class := classOf(e.Path)
			classCounts[class]++
			div, divergent, err := CompareFile(pocketdbRoot, e)
			if err != nil {
				return nil, err
			}
			if divergent {
				wfDivs = append(wfDivs, div)
			}
		}
	}

	out := make([]plan.Divergence, 0, len(sqliteDivs)+len(wfDivs))
	out = append(out, sqliteDivs...)
	out = append(out, wfDivs...)
	return out, nil
}

func classOf(path string) string {
	if i := strings.IndexByte(path, '/'); i > 0 {
		return path[:i]
	}
	return path
}

func sha256OfBytes(b []byte) string {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

// stderrWriter exposes the logger's underlying writer for io.Writer-shaped
// callers (EmitSummary). The logger writes to os.Stderr by default; tests
// that need to capture stderr inject their own io.Writer at construction.
type loggerWriter struct{ l *stderrlog.Logger }

func (lw loggerWriter) Write(p []byte) (int, error) {
	if lw.l == nil {
		return 0, nil
	}
	lw.l.Info("%s", strings.TrimRight(string(p), "\n"))
	return len(p), nil
}

func stderrWriter(l *stderrlog.Logger) loggerWriter { return loggerWriter{l: l} }
