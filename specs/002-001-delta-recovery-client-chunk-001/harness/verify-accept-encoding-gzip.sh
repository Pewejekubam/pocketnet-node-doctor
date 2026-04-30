#!/usr/bin/env bash
# verify-accept-encoding-gzip.sh — Accept-Encoding: gzip negotiation contract.
#
# Usage: verify-accept-encoding-gzip.sh <chunk-url> <expected-uncompressed-sha256>
# Exit: 0 on conforming response, non-zero otherwise.
# Verifies: US-4 AS-2.

set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: verify-accept-encoding-gzip.sh <chunk-url> <expected-sha256>" >&2
  exit 2
fi

URL="$1"
EXPECTED="$2"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --compressed would auto-decode; we want raw bytes so we can verify the
# encoded format and decode separately. -D dumps headers into a separate
# file so the body file is exactly the on-wire bytes.
curl -sS -D "$TMP/headers" -H 'Accept-Encoding: gzip' --output "$TMP/body" "$URL" || {
  echo "verify-accept-encoding-gzip VIOLATION: curl failed for $URL" >&2; exit 1; }

if ! grep -qE '^HTTP/.* 200' "$TMP/headers"; then
  echo "verify-accept-encoding-gzip VIOLATION: status not 200" >&2
  cat "$TMP/headers" >&2; exit 1
fi
if ! grep -qiE '^content-encoding:[[:space:]]*gzip' "$TMP/headers"; then
  echo "verify-accept-encoding-gzip VIOLATION: Content-Encoding not gzip" >&2
  cat "$TMP/headers" >&2; exit 1
fi

if ! gzip -dc < "$TMP/body" > "$TMP/decoded" 2>/dev/null; then
  echo "verify-accept-encoding-gzip VIOLATION: gzip decode failed" >&2; exit 1
fi
GOT=$(sha256sum "$TMP/decoded" | awk '{print $1}')
if [ "$GOT" != "$EXPECTED" ]; then
  echo "verify-accept-encoding-gzip VIOLATION: hash $GOT != expected $EXPECTED" >&2; exit 1
fi
echo "accept-encoding-gzip OK ($GOT)"
exit 0
