#!/usr/bin/env bash
# verify-tamper-rejection.sh — assert that a manifest tampered in any value
# field hashes to a different SHA-256 than the published trust-root sidecar.
# Models the BC-001 invariant: a doctor binary built against trust-root T
# refuses any manifest whose canonical-form-hash != T.
#
# Usage: verify-tamper-rejection.sh <good-manifest.json> <trust-root.sha256> <tampered-manifest.json>
# Exit: 0 if tampered hash differs from sidecar AND good hash equals sidecar
#       (both invariants hold simultaneously), non-zero otherwise.
# Verifies: BC-001, US-2 AS-2.

set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: verify-tamper-rejection.sh <good> <trust-root.sha256> <tampered>" >&2
  exit 2
fi

GOOD="$1"
SIDECAR="$2"
TAMPERED="$3"

for f in "$GOOD" "$SIDECAR" "$TAMPERED"; do
  [ -f "$f" ] || { echo "verify-tamper-rejection VIOLATION: '$f' not found" >&2; exit 4; }
done

EXPECTED=$(head -c 64 "$SIDECAR")
GOOD_HASH=$(jq -cS . "$GOOD" | tr -d '\n' | sha256sum | awk '{print $1}')
TAMPERED_HASH=$(jq -cS . "$TAMPERED" | tr -d '\n' | sha256sum | awk '{print $1}')

if [ "$GOOD_HASH" != "$EXPECTED" ]; then
  echo "verify-tamper-rejection VIOLATION: good manifest hash != trust-root (expected=$EXPECTED got=$GOOD_HASH)" >&2
  exit 5
fi

if [ "$TAMPERED_HASH" = "$EXPECTED" ]; then
  echo "verify-tamper-rejection VIOLATION: tampered manifest hash MATCHES trust-root (no detection: $TAMPERED_HASH)" >&2
  exit 1
fi

echo "tamper REJECTED (good=$GOOD_HASH tampered=$TAMPERED_HASH expected=$EXPECTED)"
exit 0
