#!/usr/bin/env bash
# verify-sampled-chunks.sh — fetch and verify three sampled chunks
# (one main.sqlite3 page, one blocks/, one chainstate/) against the
# manifest's recorded SHA-256.
#
# Usage: verify-sampled-chunks.sh <stub-base-url> <manifest.json>
# Exit: 0 if all three sampled chunks match, non-zero otherwise.
# Verifies: US-1 AS-3, AS-4, AS-5.

set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: verify-sampled-chunks.sh <stub-base-url> <manifest.json>" >&2
  exit 2
fi

BASE="$1"
MANIFEST="$2"

if [ ! -f "$MANIFEST" ]; then
  echo "verify-sampled-chunks VIOLATION: manifest '$MANIFEST' not found" >&2
  exit 4
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "verify-sampled-chunks VIOLATION: $1" >&2
  exit 1
}

verify_one() {
  local label="$1"; shift
  local url="$1"; shift
  local expected="$1"; shift
  local out="$TMP/${label}.bin"
  if ! curl -fsS -H 'Accept-Encoding: zstd' --output "$TMP/${label}.zst" "$url"; then
    fail "$label: curl failed for $url"
  fi
  if ! zstd -q -d -f "$TMP/${label}.zst" -o "$out" >/dev/null 2>&1; then
    fail "$label: zstd decode failed"
  fi
  local got
  got=$(sha256sum "$out" | awk '{print $1}')
  if [ "$got" != "$expected" ]; then
    fail "$label: hash mismatch (expected=$expected got=$got url=$url)"
  fi
  echo "  OK $label hash MATCH ($expected)"
}

# 1. main.sqlite3 first sqlite_pages page
PAGE_OFFSET=$(jq -r '.entries[] | select(.entry_kind=="sqlite_pages" and .path=="pocketdb/main.sqlite3") | .pages[0].offset' "$MANIFEST")
PAGE_HASH=$(  jq -r '.entries[] | select(.entry_kind=="sqlite_pages" and .path=="pocketdb/main.sqlite3") | .pages[0].hash'   "$MANIFEST")
[ -n "$PAGE_OFFSET" ] && [ -n "$PAGE_HASH" ] || fail "no sqlite_pages entry for pocketdb/main.sqlite3 in manifest"
verify_one "page0" "$BASE/files/pocketdb/main.sqlite3/pages/$PAGE_OFFSET" "$PAGE_HASH"

# 2. first whole_file under blocks/
BLOCK_PATH=$(jq -r '[.entries[] | select(.entry_kind=="whole_file" and (.path|startswith("blocks/"))) | .path][0]' "$MANIFEST")
[ "$BLOCK_PATH" != "null" ] || fail "no blocks/ whole_file entry in manifest"
BLOCK_HASH=$(jq -r --arg p "$BLOCK_PATH" '.entries[] | select(.path==$p) | .hash' "$MANIFEST")
verify_one "block" "$BASE/files/$BLOCK_PATH" "$BLOCK_HASH"

# 3. first whole_file under chainstate/
CS_PATH=$(jq -r '[.entries[] | select(.entry_kind=="whole_file" and (.path|startswith("chainstate/"))) | .path][0]' "$MANIFEST")
[ "$CS_PATH" != "null" ] || fail "no chainstate/ whole_file entry in manifest"
CS_HASH=$(jq -r --arg p "$CS_PATH" '.entries[] | select(.path==$p) | .hash' "$MANIFEST")
verify_one "chainstate" "$BASE/files/$CS_PATH" "$CS_HASH"

echo "sampled chunks MATCH (page=$PAGE_HASH block=$BLOCK_HASH chainstate=$CS_HASH)"
exit 0
