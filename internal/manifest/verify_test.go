package manifest

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/pocketnet-team/pocketnet-node-doctor/internal/canonform"
)

// T026: Verify re-serializes via canonform and compares SHA-256 to pinnedHash.
// PASS when computed == pinned; REFUSE with TrustRootMismatchError when ≠.
func TestVerify_ValidV1_PassesAgainstComputedTrustRoot(t *testing.T) {
	raw := readFixture(t, "valid_v1.json")
	pinned := computeTrustRoot(t, raw)
	if err := Verify(raw, pinned); err != nil {
		t.Errorf("Verify(valid_v1, computed-pin) = %v; want nil", err)
	}
}

func TestVerify_TamperedManifest_ReturnsTrustRootMismatch(t *testing.T) {
	validRaw := readFixture(t, "valid_v1.json")
	pinned := computeTrustRoot(t, validRaw)
	tamperedRaw := readFixture(t, "tampered.json")
	err := Verify(tamperedRaw, pinned)
	if err == nil {
		t.Fatalf("want TrustRootMismatchError; got nil")
	}
	var tr *TrustRootMismatchError
	if !errors.As(err, &tr) {
		t.Fatalf("want TrustRootMismatchError; got %T: %v", err, err)
	}
	if tr.Expected != pinned {
		t.Errorf("Expected = %s; want %s", tr.Expected, pinned)
	}
	if len(tr.Computed) != 64 {
		t.Errorf("Computed not 64-hex: %q", tr.Computed)
	}
}

func TestVerify_InvalidJSON_ReturnsError(t *testing.T) {
	if err := Verify([]byte("not json"), "deadbeef"); err == nil {
		t.Errorf("want error on invalid JSON")
	}
}

func readFixture(t *testing.T, name string) []byte {
	t.Helper()
	raw, err := os.ReadFile(filepath.Join("..", "..", "tests", "integration", "testdata", "manifests", name))
	if err != nil {
		t.Fatalf("read fixture %s: %v", name, err)
	}
	return raw
}

func computeTrustRoot(t *testing.T, raw []byte) string {
	t.Helper()
	// Parse generic, canonform, sha256 — the same pipeline Verify uses.
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	var generic any
	if err := dec.Decode(&generic); err != nil {
		t.Fatalf("decode for trust-root: %v", err)
	}
	canon, err := canonform.Marshal(generic)
	if err != nil {
		t.Fatalf("canonform: %v", err)
	}
	sum := sha256.Sum256(canon)
	return hex.EncodeToString(sum[:])
}
