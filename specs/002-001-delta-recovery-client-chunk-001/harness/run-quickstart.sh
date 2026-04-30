#!/usr/bin/env bash
# run-quickstart.sh — drive the quickstart.md Steps 1-6 end-to-end against the
# in-repo synthetic fixture (T050).
#
# Usage: run-quickstart.sh [<stub-base-url>]
#         default stub-base-url: http://127.0.0.1:8081
#
# Pre-conditions: stub-server.py is running and serving fixtures/canonical/served/.

set -eu

BASE="${1:-http://127.0.0.1:8081}"
HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
SPEC_DIR="$(cd "$HARNESS_DIR/.." && pwd)"
MANIFEST="$SPEC_DIR/fixtures/canonical/served/manifest.json"
SIDECAR="$SPEC_DIR/fixtures/canonical/served/trust-root.sha256"
HEIGHT=$(jq -r '.canonical_identity.block_height' "$MANIFEST")

echo "=== quickstart Step 1 — schema validation ==="
"$HARNESS_DIR/verify-schema.sh" "$MANIFEST"
jq -r '.format_version, .canonical_identity, (.entries | length), .trust_anchors' "$MANIFEST"

echo
echo "=== quickstart Step 2 — trust-root verification ==="
"$HARNESS_DIR/verify-trust-root.sh" "$MANIFEST" "$SIDECAR"

echo
echo "=== quickstart Step 3 — sampled chunks (page, blocks, chainstate) ==="
"$HARNESS_DIR/verify-sampled-chunks.sh" "$BASE" "$MANIFEST"

echo
echo "=== quickstart Step 4 — Accept-Encoding contract ==="
PAGE_HASH=$(jq -r '.entries[] | select(.path=="pocketdb/main.sqlite3") | .pages[0].hash' "$MANIFEST")
URL="$BASE/files/pocketdb/main.sqlite3/pages/0"
"$HARNESS_DIR/verify-accept-encoding-zstd.sh" "$URL" "$PAGE_HASH"
"$HARNESS_DIR/verify-accept-encoding-gzip.sh" "$URL" "$PAGE_HASH"
"$HARNESS_DIR/verify-accept-encoding-406.sh"  "$URL"

echo
echo "=== quickstart Step 5 — freshness ==="
"$HARNESS_DIR/verify-freshness.sh" "$MANIFEST"

echo
echo "=== quickstart Step 6 — change_counter on main.sqlite3 ==="
"$HARNESS_DIR/verify-change-counter.sh" "$MANIFEST"

echo
echo "=== quickstart end-to-end PASS (height=$HEIGHT) ==="
