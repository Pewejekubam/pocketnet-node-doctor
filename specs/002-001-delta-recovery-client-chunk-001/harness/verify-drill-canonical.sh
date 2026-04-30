#!/usr/bin/env bash
# verify-drill-canonical.sh — assert that the canonical at <drill-height>
# under <base> exists, has a publishable manifest + trust-root sidecar, and
# the sidecar value equals <expected-trust-root-hex> (the value the drill
# rig's doctor build pins at compile time).
#
# Usage: verify-drill-canonical.sh <base> <drill-height> <expected-trust-root-hex>
# Exit: 0 on conforming drill canonical, non-zero otherwise.
# Verifies: CSC001-003, US-6 AS-1.

set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: verify-drill-canonical.sh <base> <drill-height> <expected-trust-root-hex>" >&2
  exit 2
fi

BASE="$1"
HEIGHT="$2"
EXPECTED="$3"

if ! printf '%s' "$EXPECTED" | grep -qE '^[0-9a-f]{64}$'; then
  echo "verify-drill-canonical VIOLATION: expected trust-root must be 64 lowercase hex (got '$EXPECTED')" >&2
  exit 5
fi

HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PREFIX="$BASE/canonicals/$HEIGHT"

if ! curl -fsS "$PREFIX/manifest.json" -o "$TMP/manifest.json"; then
  echo "verify-drill-canonical VIOLATION: cannot fetch $PREFIX/manifest.json" >&2
  exit 1
fi
if ! curl -fsS "$PREFIX/trust-root.sha256" -o "$TMP/trust-root.sha256"; then
  echo "verify-drill-canonical VIOLATION: cannot fetch $PREFIX/trust-root.sha256" >&2
  exit 1
fi

# 1. Sidecar internal consistency: SHA-256(canonical_form(manifest)) == sidecar
if ! "$HARNESS_DIR/verify-trust-root.sh" "$TMP/manifest.json" "$TMP/trust-root.sha256" >/dev/null; then
  echo "verify-drill-canonical VIOLATION: drill canonical's published manifest does not hash to its sidecar" >&2
  exit 1
fi

# 2. Sidecar value matches the drill rig's compiled-in pin
PUBLISHED=$(head -c 64 "$TMP/trust-root.sha256")
if [ "$PUBLISHED" != "$EXPECTED" ]; then
  echo "verify-drill-canonical VIOLATION: published trust-root '$PUBLISHED' != drill-rig pin '$EXPECTED'" >&2
  exit 1
fi

echo "drill-canonical OK (height=$HEIGHT trust-root=$PUBLISHED)"
exit 0
