package diagnose

import (
	"errors"
	"fmt"
	"io"
	"os"

	"github.com/pocketnet-team/pocketnet-node-doctor/internal/hashutil"
	"github.com/pocketnet-team/pocketnet-node-doctor/internal/manifest"
	"github.com/pocketnet-team/pocketnet-node-doctor/internal/plan"
)

// ComparePages stream-iterates hashutil.HashSQLitePages over
// <pocketdbRoot>/<entry.Path>, comparing each (offset, hash) against the
// manifest's per-page hash. Returns the divergent pages.
//
// Special cases:
//   - File missing: every canonical page becomes a divergent entry.
//   - File shorter than canonical: every page beyond the local file's end
//     becomes a divergent entry.
//   - File longer than canonical: extra local pages are ignored (apply will
//     truncate to canonical length on swap).
func ComparePages(pocketdbRoot string, entry manifest.Entry) ([]plan.Page, error) {
	if entry.EntryKind != manifest.EntryKindSQLitePages {
		return nil, fmt.Errorf("page-compare: not an sqlite_pages entry: %q", entry.Path)
	}
	path := joinRel(pocketdbRoot, entry.Path)

	// Build canonical lookup: offset -> hash
	canonical := make(map[int64]string, len(entry.Pages))
	for _, p := range entry.Pages {
		canonical[p.Offset] = p.Hash
	}

	// Open local file. Missing → all canonical pages diverge.
	if _, err := os.Stat(path); errors.Is(err, os.ErrNotExist) {
		out := make([]plan.Page, 0, len(entry.Pages))
		for _, p := range entry.Pages {
			out = append(out, plan.Page{Offset: p.Offset, ExpectedHash: p.Hash})
		}
		return out, nil
	}

	const pageSize = 4096
	seq, err := hashutil.HashSQLitePages(path, pageSize)
	if err != nil {
		return nil, fmt.Errorf("page-compare: hash: %w", err)
	}

	matched := make(map[int64]bool)
	var divergent []plan.Page
	for ph, ierr := range seq {
		if ierr != nil {
			if errors.Is(ierr, io.ErrUnexpectedEOF) {
				// Page-misalignment: stop; remaining canonical pages will be
				// reported as divergent below.
				break
			}
			return nil, fmt.Errorf("page-compare: %w", ierr)
		}
		want, ok := canonical[ph.Offset]
		if !ok {
			// Local has a page beyond canonical's coverage; ignore.
			continue
		}
		matched[ph.Offset] = true
		if ph.Hash != want {
			divergent = append(divergent, plan.Page{Offset: ph.Offset, ExpectedHash: want})
		}
	}
	// Any canonical page not matched → file is shorter than canonical; emit divergent.
	for _, p := range entry.Pages {
		if !matched[p.Offset] {
			divergent = append(divergent, plan.Page{Offset: p.Offset, ExpectedHash: p.Hash})
		}
	}
	sortPages(divergent)
	return divergent, nil
}
