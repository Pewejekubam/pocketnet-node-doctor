#!/usr/bin/env bash
# verify-change-counter.sh — assert that the manifest's pocketdb/main.sqlite3
# entry carries a non-negative integer change_counter, and no other
# sqlite_pages entry does.
#
# Usage: verify-change-counter.sh <manifest.json>
# Exit: 0 on conforming change_counter exposure, non-zero otherwise.
# Verifies: CR001-007, US-3 AS-1.

set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: verify-change-counter.sh <manifest.json>" >&2
  exit 2
fi

MANIFEST="$1"
[ -f "$MANIFEST" ] || { echo "verify-change-counter VIOLATION: manifest '$MANIFEST' not found" >&2; exit 4; }

# 1. main.sqlite3 entry MUST carry a non-negative integer change_counter
CC=$(jq -r '.entries[] | select(.entry_kind=="sqlite_pages" and .path=="pocketdb/main.sqlite3") | .change_counter' "$MANIFEST")
if [ -z "$CC" ] || [ "$CC" = "null" ]; then
  echo "verify-change-counter VIOLATION: pocketdb/main.sqlite3 entry has no change_counter" >&2
  exit 1
fi
if ! printf '%s' "$CC" | grep -qE '^[0-9]+$'; then
  echo "verify-change-counter VIOLATION: change_counter is not a non-negative integer (got '$CC')" >&2
  exit 1
fi

# 2. No other sqlite_pages entry may carry change_counter
OTHERS=$(jq -r '[.entries[] | select(.entry_kind=="sqlite_pages" and .path!="pocketdb/main.sqlite3" and (has("change_counter")))] | length' "$MANIFEST")
if [ "$OTHERS" != "0" ]; then
  echo "verify-change-counter VIOLATION: $OTHERS other sqlite_pages entry/entries carry change_counter" >&2
  exit 1
fi

echo "change_counter OK (main.sqlite3=$CC; no other sqlite_pages entry carries change_counter)"
exit 0
