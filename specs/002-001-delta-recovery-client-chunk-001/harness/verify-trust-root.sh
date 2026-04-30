#!/usr/bin/env bash
# verify-trust-root.sh — verify the published trust-root sidecar matches
# SHA-256 of the canonical-form re-serialization of the manifest.
#
# Usage: verify-trust-root.sh <manifest.json> <trust-root.sha256>
# Exit: 0 on match, non-zero on mismatch or precondition failure.
# Verifies: US-1 AS-1, CR001-006.

set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: verify-trust-root.sh <manifest.json> <trust-root.sha256>" >&2
  exit 2
fi

MANIFEST="$1"
SIDECAR="$2"

if [ ! -f "$MANIFEST" ]; then
  echo "verify-trust-root VIOLATION: manifest '$MANIFEST' not found" >&2
  exit 4
fi
if [ ! -f "$SIDECAR" ]; then
  echo "verify-trust-root VIOLATION: sidecar '$SIDECAR' not found" >&2
  exit 4
fi

# Sidecar shape: 64 lowercase hex chars + LF == 65 bytes.
SIDECAR_BYTES=$(wc -c < "$SIDECAR" | tr -d ' ')
if [ "$SIDECAR_BYTES" -ne 65 ]; then
  echo "verify-trust-root VIOLATION: sidecar must be 65 bytes (got $SIDECAR_BYTES)" >&2
  exit 5
fi

EXPECTED=$(head -c 64 "$SIDECAR")
if ! printf '%s' "$EXPECTED" | grep -qE '^[0-9a-f]{64}$'; then
  echo "verify-trust-root VIOLATION: sidecar first 64 chars are not 64 lowercase hex" >&2
  exit 5
fi

# Canonical-form re-serialization: jq -cS . | tr -d '\n'
COMPUTED=$(jq -cS . "$MANIFEST" | tr -d '\n' | sha256sum | awk '{print $1}')

if [ "$EXPECTED" = "$COMPUTED" ]; then
  echo "trust-root MATCH"
  exit 0
fi

echo "verify-trust-root VIOLATION: expected=$EXPECTED computed=$COMPUTED" >&2
exit 1
