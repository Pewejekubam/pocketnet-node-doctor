#!/usr/bin/env bash
# verify-accept-encoding-406.sh — request with neither zstd nor gzip in
# Accept-Encoding must yield HTTP 406 with a body containing both literal
# substrings 'zstd' and 'gzip'.
#
# Usage: verify-accept-encoding-406.sh <chunk-url>
# Exit: 0 on conforming 406 response, non-zero otherwise.
# Verifies: US-4 AS-3, CR001-005.

set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: verify-accept-encoding-406.sh <chunk-url>" >&2
  exit 2
fi

URL="$1"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# curl exits non-zero on HTTP 4xx unless --fail is omitted (default behavior
# without -f returns 0). We want the 406 body and headers without aborting.
curl -sS -D "$TMP/headers" -H 'Accept-Encoding: identity' --output "$TMP/body" "$URL" || {
  echo "verify-accept-encoding-406 VIOLATION: curl failed for $URL" >&2; exit 1; }

if ! grep -qE '^HTTP/.* 406' "$TMP/headers"; then
  echo "verify-accept-encoding-406 VIOLATION: status not 406" >&2
  cat "$TMP/headers" >&2; exit 1
fi
if ! grep -q 'zstd' "$TMP/body"; then
  echo "verify-accept-encoding-406 VIOLATION: 406 body does not name 'zstd'" >&2; exit 1
fi
if ! grep -q 'gzip' "$TMP/body"; then
  echo "verify-accept-encoding-406 VIOLATION: 406 body does not name 'gzip'" >&2; exit 1
fi
echo "accept-encoding-406 OK ($(wc -c < "$TMP/body") body bytes; both 'zstd' and 'gzip' present)"
exit 0
