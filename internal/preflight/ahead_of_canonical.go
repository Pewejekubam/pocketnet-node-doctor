package preflight

import (
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/pocketnet-team/pocketnet-node-doctor/internal/exitcode"
	"github.com/pocketnet-team/pocketnet-node-doctor/internal/manifest"
)

// AheadOfCanonical implements the SQLite-header change_counter check (D7,
// FR-011). Refuses with exit code 3 when local change_counter exceeds the
// canonical's. Malformed/short header → fail-open with a generic-error
// sentinel diagnostic; the orchestrator maps that to exit 1, NOT exit 3.
func AheadOfCanonical(ctx PreflightContext) PredicateResult {
	if ctx.Manifest == nil {
		return Refused(exitcode.GenericError, "ahead-of-canonical: nil manifest")
	}
	canonicalCC, ok := manifestMainSQLiteCC(ctx.Manifest)
	if !ok {
		return Refused(exitcode.GenericError, "ahead-of-canonical: manifest missing pocketdb/main.sqlite3 change_counter")
	}
	path := filepath.Join(ctx.PocketDBPath, "main.sqlite3")
	localCC, err := readSQLiteChangeCounter(path)
	if err != nil {
		return Refused(exitcode.GenericError, fmt.Sprintf("ahead-of-canonical: %v", err))
	}
	if localCC > canonicalCC {
		return Refused(exitcode.AheadOfCanonical, fmt.Sprintf("ahead-of-canonical: local change_counter %d > canonical %d (operator's node has progressed past the canonical's block height)", localCC, canonicalCC))
	}
	return Pass()
}

// readSQLiteChangeCounter parses bytes [24:28] of a SQLite database header
// as a big-endian uint32 (D7). Returns (0, error) on malformed/short header
// so callers can fail-open with a generic-error sentinel.
func readSQLiteChangeCounter(path string) (uint32, error) {
	f, err := os.OpenFile(path, os.O_RDONLY, 0)
	if err != nil {
		return 0, err
	}
	defer f.Close()
	var hdr [100]byte
	if _, err := io.ReadFull(f, hdr[:]); err != nil {
		if errors.Is(err, io.ErrUnexpectedEOF) || errors.Is(err, io.EOF) {
			return 0, fmt.Errorf("short SQLite header (read < 100 bytes)")
		}
		return 0, err
	}
	const magic = "SQLite format 3\x00"
	if string(hdr[0:16]) != magic {
		return 0, fmt.Errorf("malformed SQLite header at %s (magic mismatch)", path)
	}
	return binary.BigEndian.Uint32(hdr[24:28]), nil
}

func manifestMainSQLiteCC(m *manifest.Manifest) (uint32, bool) {
	for _, e := range m.Entries {
		if e.EntryKind == manifest.EntryKindSQLitePages && e.Path == "pocketdb/main.sqlite3" {
			if e.ChangeCounter == nil {
				return 0, false
			}
			return uint32(*e.ChangeCounter), true
		}
	}
	return 0, false
}
