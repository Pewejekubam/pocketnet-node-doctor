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
// Both the manifest Pages slice and HashSQLitePages iterate in ascending
// offset order, so comparison is a single merge-pass with O(1) extra memory —
// no intermediate maps are built.
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

	// File missing → all canonical pages diverge.
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

	// Merge-compare: manifest pages and local pages are both in ascending
	// offset order. Walk them with a single index into entry.Pages.
	manifPages := entry.Pages
	manifIdx := 0
	var divergent []plan.Page

	for ph, ierr := range seq {
		if ierr != nil {
			if errors.Is(ierr, io.ErrUnexpectedEOF) {
				// Page-misalignment: stop; remaining canonical pages reported below.
				break
			}
			return nil, fmt.Errorf("page-compare: %w", ierr)
		}

		// Advance past any canonical pages whose offset is less than the
		// current local page — these are gaps in the local file (should not
		// happen for a well-formed SQLite, but treated as divergent below).
		for manifIdx < len(manifPages) && manifPages[manifIdx].Offset < ph.Offset {
			divergent = append(divergent, plan.Page{
				Offset:       manifPages[manifIdx].Offset,
				ExpectedHash: manifPages[manifIdx].Hash,
			})
			manifIdx++
		}

		if manifIdx >= len(manifPages) {
			// Local has pages beyond canonical's coverage; ignore.
			break
		}

		if manifPages[manifIdx].Offset == ph.Offset {
			// Matching offset: compare hashes.
			if ph.Hash != manifPages[manifIdx].Hash {
				divergent = append(divergent, plan.Page{
					Offset:       ph.Offset,
					ExpectedHash: manifPages[manifIdx].Hash,
				})
			}
			manifIdx++
		}
		// If manifPages[manifIdx].Offset > ph.Offset: extra local page not in
		// canonical; ignore it.
	}

	// Canonical pages not reached by the local file → divergent.
	for ; manifIdx < len(manifPages); manifIdx++ {
		divergent = append(divergent, plan.Page{
			Offset:       manifPages[manifIdx].Offset,
			ExpectedHash: manifPages[manifIdx].Hash,
		})
	}

	sortPages(divergent)
	return divergent, nil
}
