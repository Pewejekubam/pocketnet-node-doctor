package preflight

import (
	"encoding/binary"
	"os"
	"path/filepath"
	"testing"

	"github.com/pocketnet-team/pocketnet-node-doctor/internal/exitcode"
	"github.com/pocketnet-team/pocketnet-node-doctor/internal/manifest"
)

// T042: AheadOfCanonical refuses with exit code 3 when local change_counter
// > canonical's. Malformed/short header → fail-open with generic-error
// sentinel (exit 1 mapping by orchestrator), NOT the ahead-of-canonical code.
func TestAheadOfCanonical_LocalAhead_RefusesExit3(t *testing.T) {
	dir := t.TempDir()
	writeSyntheticSQLite(t, dir, 200) // local CC = 200
	cc := int64(100)                  // canonical CC = 100
	m := mfWithMainSQLiteCC(cc)
	res := AheadOfCanonical(PreflightContext{PocketDBPath: dir, Manifest: m})
	if res.Pass {
		t.Fatalf("want refuse; got pass")
	}
	if res.Refused.Code != exitcode.AheadOfCanonical {
		t.Errorf("code got %d want %d", res.Refused.Code, exitcode.AheadOfCanonical)
	}
}

func TestAheadOfCanonical_LocalEqualOrBehind_Passes(t *testing.T) {
	dir := t.TempDir()
	writeSyntheticSQLite(t, dir, 50)
	m := mfWithMainSQLiteCC(100)
	res := AheadOfCanonical(PreflightContext{PocketDBPath: dir, Manifest: m})
	if !res.Pass {
		t.Errorf("want pass; got refuse: %+v", res.Refused)
	}
}

func TestAheadOfCanonical_MalformedHeader_FailsOpen(t *testing.T) {
	dir := t.TempDir()
	// Write a too-short header (50 bytes, all zero — fails magic check).
	if err := os.WriteFile(filepath.Join(dir, "main.sqlite3"), make([]byte, 50), 0o600); err != nil {
		t.Fatal(err)
	}
	m := mfWithMainSQLiteCC(100)
	res := AheadOfCanonical(PreflightContext{PocketDBPath: dir, Manifest: m})
	if res.Pass {
		t.Fatalf("want refuse (generic-error fail-open); got pass")
	}
	if res.Refused.Code != exitcode.GenericError {
		t.Errorf("malformed-header must fail-open with GenericError, got %d", res.Refused.Code)
	}
}

func TestAheadOfCanonical_ManifestMissingCC_FailsOpen(t *testing.T) {
	dir := t.TempDir()
	writeSyntheticSQLite(t, dir, 1)
	m := &manifest.Manifest{} // no entries
	res := AheadOfCanonical(PreflightContext{PocketDBPath: dir, Manifest: m})
	if res.Pass {
		t.Fatalf("want refuse")
	}
	if res.Refused.Code != exitcode.GenericError {
		t.Errorf("got %d want GenericError", res.Refused.Code)
	}
}

// writeSyntheticSQLite writes a 100-byte SQLite-shaped header to <dir>/main.sqlite3
// with the given change_counter at offset 24 (BE uint32). Magic bytes set
// correctly so the parser proceeds to the change_counter field.
func writeSyntheticSQLite(t *testing.T, dir string, changeCounter uint32) {
	t.Helper()
	hdr := make([]byte, 100)
	copy(hdr[0:16], []byte("SQLite format 3\x00"))
	binary.BigEndian.PutUint32(hdr[24:28], changeCounter)
	path := filepath.Join(dir, "main.sqlite3")
	if err := os.WriteFile(path, hdr, 0o600); err != nil {
		t.Fatalf("write synthetic sqlite: %v", err)
	}
}

func mfWithMainSQLiteCC(cc int64) *manifest.Manifest {
	return &manifest.Manifest{
		Entries: []manifest.Entry{
			{
				EntryKind:     manifest.EntryKindSQLitePages,
				Path:          "pocketdb/main.sqlite3",
				ChangeCounter: &cc,
			},
		},
	}
}
