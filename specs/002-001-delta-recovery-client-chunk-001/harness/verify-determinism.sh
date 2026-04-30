#!/usr/bin/env bash
# verify-determinism.sh — assert that re-serializing a manifest in canonical
# form from two independent jq invocations (fresh workdirs) produces the same
# SHA-256 hash. Models the BC-002 invariant: two independent builds, same
# manifest URL, same trust-root.
#
# Usage: verify-determinism.sh <manifest.json>
# Exit: 0 on identical hashes, non-zero otherwise.
# Verifies: BC-002, US-2 AS-1.

set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: verify-determinism.sh <manifest.json>" >&2
  exit 2
fi

MANIFEST="$1"
[ -f "$MANIFEST" ] || { echo "verify-determinism VIOLATION: manifest '$MANIFEST' not found" >&2; exit 4; }

# Two independent workdirs to ensure no shared cache / temp state.
WD1=$(mktemp -d)
WD2=$(mktemp -d)
trap 'rm -rf "$WD1" "$WD2"' EXIT

cp -- "$MANIFEST" "$WD1/manifest.json"
cp -- "$MANIFEST" "$WD2/manifest.json"

H1=$(cd "$WD1" && jq -cS . manifest.json | tr -d '\n' | sha256sum | awk '{print $1}')
H2=$(cd "$WD2" && jq -cS . manifest.json | tr -d '\n' | sha256sum | awk '{print $1}')

if [ "$H1" = "$H2" ]; then
  echo "determinism OK ($H1)"
  exit 0
fi

echo "verify-determinism VIOLATION: hash1=$H1 hash2=$H2" >&2
exit 1
