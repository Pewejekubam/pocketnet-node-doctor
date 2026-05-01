package diagnose

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/pocketnet-team/pocketnet-node-doctor/internal/hashutil"
	"github.com/pocketnet-team/pocketnet-node-doctor/internal/manifest"
	"github.com/pocketnet-team/pocketnet-node-doctor/internal/plan"
)

// CompareFile hashes the local whole_file artifact and compares against the
// manifest entry's hash. Missing local file → divergence with
// expected_source: "fetch_full" (EC-001 / EC-002).
//
// Returns (Divergence, divergent=true, error). If local file matches
// canonical, divergent=false.
func CompareFile(pocketdbRoot string, entry manifest.Entry) (plan.Divergence, bool, error) {
	if entry.EntryKind != manifest.EntryKindWholeFile {
		return plan.Divergence{}, false, fmt.Errorf("file-compare: not a whole_file entry: %q", entry.Path)
	}
	path := joinRel(pocketdbRoot, entry.Path)
	if _, err := os.Stat(path); errors.Is(err, os.ErrNotExist) {
		return plan.Divergence{
			Kind:           plan.DivergenceKindWholeFile,
			Path:           entry.Path,
			ExpectedHash:   entry.Hash,
			ExpectedSource: "fetch_full",
		}, true, nil
	}
	got, err := hashutil.HashWholeFile(path)
	if err != nil {
		return plan.Divergence{}, false, fmt.Errorf("file-compare: hash %q: %w", path, err)
	}
	if got != entry.Hash {
		return plan.Divergence{
			Kind:         plan.DivergenceKindWholeFile,
			Path:         entry.Path,
			ExpectedHash: entry.Hash,
		}, true, nil
	}
	return plan.Divergence{}, false, nil
}

// joinRel joins a relative manifest path under pocketdbRoot, where the
// manifest path is rooted at the pocketnet data directory's parent (e.g.,
// "pocketdb/main.sqlite3"). pocketdbRoot is the operator-supplied
// `--pocketdb` path which IS that pocketdb directory; so we strip the
// leading "pocketdb/" prefix when present and join under pocketdbRoot.
//
// Examples:
//
//	pocketdbRoot=/var/lib/pocketnet/pocketdb entry="pocketdb/main.sqlite3"
//	  -> /var/lib/pocketnet/pocketdb/main.sqlite3
//	pocketdbRoot=/var/lib/pocketnet/pocketdb entry="blocks/000.dat"
//	  -> /var/lib/pocketnet/pocketdb/blocks/000.dat
func joinRel(pocketdbRoot, entryPath string) string {
	if strings.HasPrefix(entryPath, "pocketdb/") {
		return filepath.Join(pocketdbRoot, strings.TrimPrefix(entryPath, "pocketdb/"))
	}
	return filepath.Join(pocketdbRoot, entryPath)
}

// sortPages orders divergent pages by ascending offset.
func sortPages(pages []plan.Page) {
	sort.Slice(pages, func(i, j int) bool { return pages[i].Offset < pages[j].Offset })
}
