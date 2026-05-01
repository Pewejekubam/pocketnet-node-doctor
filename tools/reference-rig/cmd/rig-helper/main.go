// Package main is the reference-rig manifest-minting helper.
//
// Mints a v1 canonical manifest from a source SQLite file (and optional
// whole-file artifacts), serializes it via internal/canonform, computes
// the SHA-256 trust-root, writes manifest.json next to the source, and
// prints the trust-root hex on stdout so the operator can pass it to
// `tools/reference-rig/deploy.sh <trust-root>`.
//
// This is a chunk-002-side stopgap until the proper chunk-001 manifest
// generator workflow exists. The output schema is identical to chunk-001's
// frozen manifest schema (specs/002-001-delta-recovery-client-chunk-001/
// contracts/manifest.schema.json).
//
// Usage:
//
//	rig-helper mint \
//	  --sqlite <path-to-canonical-main.sqlite3> \
//	  --pocketnet-core-version <version> \
//	  --block-height <int> \
//	  --created-at <RFC3339> \
//	  --out <path-to-manifest.json> \
//	  [--whole-file <relpath>=<absolute-path>]...
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"iter"
	"os"
	"sort"
	"strings"

	"github.com/pocketnet-team/pocketnet-node-doctor/internal/canonform"
	"github.com/pocketnet-team/pocketnet-node-doctor/internal/hashutil"
)

// stringList is a flag.Value that accumulates repeated --whole-file flags.
type stringList []string

func (s *stringList) String() string     { return strings.Join(*s, ",") }
func (s *stringList) Set(v string) error { *s = append(*s, v); return nil }

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(64)
	}
	switch os.Args[1] {
	case "mint":
		os.Exit(runMint(os.Args[2:]))
	case "-h", "--help", "help":
		usage()
		os.Exit(0)
	default:
		fmt.Fprintf(os.Stderr, "rig-helper: unknown subcommand %q\n", os.Args[1])
		usage()
		os.Exit(64)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, `rig-helper — mint a v1 canonical manifest for the reference rig.

Subcommands:
  mint --sqlite <path> --pocketnet-core-version <v> --block-height <n>
       --created-at <rfc3339> --out <manifest.json>
       [--whole-file <relpath>=<absolute-path>]...

Mints a manifest.json from <sqlite> (page-level entries at 4096-byte boundaries
with a change_counter from the SQLite header) plus zero-or-more whole_file
entries, serializes via the canonical-form rule (sorted keys, no insignificant
whitespace, UTF-8), computes SHA-256 of that payload, prints the trust-root
hex on stdout.`)
}

func runMint(args []string) int {
	fs := flag.NewFlagSet("mint", flag.ContinueOnError)
	var (
		sqlitePath  = fs.String("sqlite", "", "path to canonical main.sqlite3 (required)")
		coreVersion = fs.String("pocketnet-core-version", "", "pocketnet-core version string (required)")
		blockHeight = fs.Int64("block-height", 0, "canonical block height (required)")
		createdAt   = fs.String("created-at", "", "RFC 3339 / ISO-8601 timestamp (required)")
		out         = fs.String("out", "", "path to write manifest.json (required)")
		wholeFiles  stringList
	)
	fs.Var(&wholeFiles, "whole-file", "<relpath>=<absolute-path>; repeatable")
	if err := fs.Parse(args); err != nil {
		return 64
	}
	missing := []string{}
	if *sqlitePath == "" {
		missing = append(missing, "--sqlite")
	}
	if *coreVersion == "" {
		missing = append(missing, "--pocketnet-core-version")
	}
	if *blockHeight == 0 {
		missing = append(missing, "--block-height")
	}
	if *createdAt == "" {
		missing = append(missing, "--created-at")
	}
	if *out == "" {
		missing = append(missing, "--out")
	}
	if len(missing) > 0 {
		fmt.Fprintf(os.Stderr, "missing required flags: %s\n", strings.Join(missing, ", "))
		fs.PrintDefaults()
		return 64
	}

	manifest, err := mint(*sqlitePath, *coreVersion, *blockHeight, *createdAt, wholeFiles)
	if err != nil {
		fmt.Fprintf(os.Stderr, "mint failed: %v\n", err)
		return 1
	}
	body, err := canonformBytes(manifest)
	if err != nil {
		fmt.Fprintf(os.Stderr, "canonform failed: %v\n", err)
		return 1
	}
	sum := sha256.Sum256(body)
	trustRoot := hex.EncodeToString(sum[:])

	if err := os.WriteFile(*out, body, 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "write %s: %v\n", *out, err)
		return 1
	}

	fmt.Fprintf(os.Stderr, "manifest written: %s (%d bytes)\n", *out, len(body))
	fmt.Fprintf(os.Stderr, "page entries: %d\n", manifestPageCount(manifest))
	fmt.Fprintf(os.Stderr, "whole_file entries: %d\n", len(wholeFiles))
	fmt.Fprintf(os.Stderr, "trust-root SHA-256:\n")
	fmt.Println(trustRoot)
	return 0
}

// manifest is a minimal mirror of the chunk-001 v1 schema sufficient for
// minting. It is NOT shared with internal/manifest because that package's
// types are tuned for the doctor-side parse contract; the on-rig minter
// has different needs (e.g., emits trust_anchors:[]).
type manifest struct {
	FormatVersion     int               `json:"format_version"`
	CanonicalIdentity canonicalIdentity `json:"canonical_identity"`
	Entries           []entry           `json:"entries"`
	TrustAnchors      []any             `json:"trust_anchors"`
}

type canonicalIdentity struct {
	BlockHeight          int64  `json:"block_height"`
	PocketnetCoreVersion string `json:"pocketnet_core_version"`
	CreatedAt            string `json:"created_at"`
}

// entry is the v1 oneOf — only the fields relevant to whichever entry_kind
// is set are non-zero. Discriminated by EntryKind.
type entry struct {
	EntryKind     string `json:"entry_kind"`
	Path          string `json:"path"`
	Pages         []page `json:"pages,omitempty"`
	ChangeCounter *int64 `json:"change_counter,omitempty"`
	Hash          string `json:"hash,omitempty"`
}

type page struct {
	Offset int64  `json:"offset"`
	Hash   string `json:"hash"`
}

func mint(sqlitePath, coreVersion string, blockHeight int64, createdAt string, wholeFiles []string) (*manifest, error) {
	pages, cc, err := hashSQLitePages(sqlitePath, 4096)
	if err != nil {
		return nil, fmt.Errorf("sqlite_pages on %s: %w", sqlitePath, err)
	}
	mainEntry := entry{
		EntryKind:     "sqlite_pages",
		Path:          "pocketdb/main.sqlite3",
		Pages:         pages,
		ChangeCounter: &cc,
	}

	wfEntries := make([]entry, 0, len(wholeFiles))
	for _, spec := range wholeFiles {
		eq := strings.IndexByte(spec, '=')
		if eq <= 0 || eq == len(spec)-1 {
			return nil, fmt.Errorf("--whole-file %q: expected <relpath>=<absolute-path>", spec)
		}
		relPath := spec[:eq]
		absPath := spec[eq+1:]
		hash, err := hashutil.HashWholeFile(absPath)
		if err != nil {
			return nil, fmt.Errorf("hash %s: %w", absPath, err)
		}
		wfEntries = append(wfEntries, entry{
			EntryKind: "whole_file",
			Path:      relPath,
			Hash:      hash,
		})
	}
	sort.Slice(wfEntries, func(i, j int) bool { return wfEntries[i].Path < wfEntries[j].Path })

	entries := append([]entry{mainEntry}, wfEntries...)
	return &manifest{
		FormatVersion: 1,
		CanonicalIdentity: canonicalIdentity{
			BlockHeight:          blockHeight,
			PocketnetCoreVersion: coreVersion,
			CreatedAt:            createdAt,
		},
		Entries:      entries,
		TrustAnchors: []any{},
	}, nil
}

// hashSQLitePages drains the per-page iterator into a slice and reads the
// SQLite header's change_counter (offset 24, BE uint32).
func hashSQLitePages(path string, pageSize int) ([]page, int64, error) {
	cc, err := readChangeCounter(path)
	if err != nil {
		return nil, 0, err
	}
	seq, err := hashutil.HashSQLitePages(path, pageSize)
	if err != nil {
		return nil, 0, err
	}
	out := []page{}
	for ph, ierr := range seq {
		if ierr != nil {
			return nil, 0, ierr
		}
		out = append(out, page{Offset: ph.Offset, Hash: ph.Hash})
	}
	return out, cc, nil
}

func readChangeCounter(path string) (int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return 0, err
	}
	defer f.Close()
	var hdr [100]byte
	if _, err := io.ReadFull(f, hdr[:]); err != nil {
		return 0, err
	}
	const magic = "SQLite format 3\x00"
	if string(hdr[0:16]) != magic {
		return 0, fmt.Errorf("not a SQLite-3 file: magic mismatch")
	}
	cc := int64(uint32(hdr[24])<<24 | uint32(hdr[25])<<16 | uint32(hdr[26])<<8 | uint32(hdr[27]))
	return cc, nil
}

func canonformBytes(m *manifest) ([]byte, error) {
	// Round-trip through stdlib JSON so canonform sees a generic any.
	tmp, err := json.Marshal(m)
	if err != nil {
		return nil, err
	}
	var generic any
	dec := json.NewDecoder(strings.NewReader(string(tmp)))
	dec.UseNumber()
	if err := dec.Decode(&generic); err != nil {
		return nil, err
	}
	return canonform.Marshal(generic)
}

func manifestPageCount(m *manifest) int {
	for _, e := range m.Entries {
		if e.EntryKind == "sqlite_pages" {
			return len(e.Pages)
		}
	}
	return 0
}

// Ensure the iter import isn't dropped if a future refactor doesn't use it.
var _ iter.Seq[int]
