#!/usr/bin/env bash
# verify-accept-encoding-zstd.sh — Accept-Encoding: zstd negotiation contract.
#
# Usage: verify-accept-encoding-zstd.sh <chunk-url> <expected-uncompressed-sha256>
# Exit: 0 on conforming response, non-zero otherwise.
# Verifies: US-4 AS-1.

set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: verify-accept-encoding-zstd.sh <chunk-url> <expected-sha256>" >&2
  exit 2
fi

URL="$1"
EXPECTED="$2"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Use -D to dump headers to a separate file so the body file stays exactly
# the on-wire bytes (no awk-added newlines breaking binary content).
curl -sS -D "$TMP/headers" -H 'Accept-Encoding: zstd' --output "$TMP/body" "$URL" || {
  echo "verify-accept-encoding-zstd VIOLATION: curl failed for $URL" >&2; exit 1; }

if ! grep -qE '^HTTP/.* 200' "$TMP/headers"; then
  echo "verify-accept-encoding-zstd VIOLATION: status not 200" >&2
  cat "$TMP/headers" >&2; exit 1
fi
if ! grep -qiE '^content-encoding:[[:space:]]*zstd' "$TMP/headers"; then
  echo "verify-accept-encoding-zstd VIOLATION: Content-Encoding not zstd" >&2
  cat "$TMP/headers" >&2; exit 1
fi

if ! zstd -q -d -f "$TMP/body" -o "$TMP/decoded" >/dev/null 2>&1; then
  echo "verify-accept-encoding-zstd VIOLATION: zstd decode failed" >&2; exit 1
fi
GOT=$(sha256sum "$TMP/decoded" | awk '{print $1}')
if [ "$GOT" != "$EXPECTED" ]; then
  echo "verify-accept-encoding-zstd VIOLATION: hash $GOT != expected $EXPECTED" >&2; exit 1
fi
echo "accept-encoding-zstd OK ($GOT)"
exit 0
