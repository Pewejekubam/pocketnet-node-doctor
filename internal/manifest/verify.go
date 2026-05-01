package manifest

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/pocketnet-team/pocketnet-node-doctor/internal/canonform"
)

// TrustRootMismatchError signals manifest-trust-root divergence (EC-008).
type TrustRootMismatchError struct {
	Computed string
	Expected string
}

func (e *TrustRootMismatchError) Error() string {
	return fmt.Sprintf("manifest trust-root mismatch: computed %s, expected %s", e.Computed, e.Expected)
}

// Verify re-serializes the parsed manifest via canonform and compares its
// SHA-256 to pinnedHash. Steps per D13: parse -> canonform-re-serialize ->
// SHA-256 -> compare.
func Verify(b []byte, pinnedHash string) error {
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.UseNumber()
	var generic any
	if err := dec.Decode(&generic); err != nil {
		return fmt.Errorf("manifest: parse for verify: %w", err)
	}
	canon, err := canonform.Marshal(generic)
	if err != nil {
		return fmt.Errorf("manifest: canonform: %w", err)
	}
	sum := sha256.Sum256(canon)
	got := hex.EncodeToString(sum[:])
	if got != pinnedHash {
		return &TrustRootMismatchError{Computed: got, Expected: pinnedHash}
	}
	return nil
}

// IsTrustRootMismatch reports whether err is a TrustRootMismatchError.
func IsTrustRootMismatch(err error) bool {
	var tr *TrustRootMismatchError
	return errors.As(err, &tr)
}
