#!/usr/bin/env bash
# verify-schema.sh — validate a manifest against contracts/manifest.schema.json
#
# Usage: verify-schema.sh <manifest.json>
# Exit: 0 if the manifest validates, non-zero otherwise.
# Verifies: US-1 AS-2.

set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: verify-schema.sh <manifest.json>" >&2
  exit 2
fi

MANIFEST="$1"

# Resolve harness location so we can find the bundled venv + the schema regardless
# of the caller's working directory.
HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
SPEC_DIR="$(cd "$HARNESS_DIR/.." && pwd)"
SCHEMA="$SPEC_DIR/contracts/manifest.schema.json"
CHECKER="$HARNESS_DIR/.venv/bin/check-jsonschema"

if [ ! -x "$CHECKER" ]; then
  echo "verify-schema VIOLATION: $CHECKER not executable; run 'python3 -m venv harness/.venv && harness/.venv/bin/pip install check-jsonschema'" >&2
  exit 3
fi

if [ ! -f "$MANIFEST" ]; then
  echo "verify-schema VIOLATION: manifest '$MANIFEST' not found" >&2
  exit 4
fi

if "$CHECKER" --schemafile "$SCHEMA" "$MANIFEST"; then
  echo "schema OK"
  exit 0
fi

echo "verify-schema VIOLATION: $MANIFEST does not validate against $SCHEMA" >&2
exit 1
