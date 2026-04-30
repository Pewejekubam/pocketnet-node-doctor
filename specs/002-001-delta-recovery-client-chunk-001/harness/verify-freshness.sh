#!/usr/bin/env bash
# verify-freshness.sh — assert the manifest's canonical_identity.created_at
# is within 30 days of "now" (UTC). Models CR001-008 / US-5 AS-1.
#
# Usage: verify-freshness.sh <manifest.json>
# Exit: 0 on freshness OK, non-zero on freshness VIOLATION.

set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: verify-freshness.sh <manifest.json>" >&2
  exit 2
fi

MANIFEST="$1"
[ -f "$MANIFEST" ] || { echo "verify-freshness VIOLATION: manifest '$MANIFEST' not found" >&2; exit 4; }

CREATED_AT=$(jq -r '.canonical_identity.created_at' "$MANIFEST")
if [ -z "$CREATED_AT" ] || [ "$CREATED_AT" = "null" ]; then
  echo "verify-freshness VIOLATION: canonical_identity.created_at missing" >&2
  exit 1
fi

NOW_EPOCH=$(date -u +%s)
PAST_EPOCH=$(date -u -d "$CREATED_AT" +%s 2>/dev/null) || {
  echo "verify-freshness VIOLATION: created_at '$CREATED_AT' is not RFC 3339 / parseable by date(1)" >&2
  exit 1; }

DELTA=$(( NOW_EPOCH - PAST_EPOCH ))
DAYS=$(( DELTA / 86400 ))

if [ "$DELTA" -lt 0 ]; then
  echo "verify-freshness VIOLATION: created_at is in the future ($CREATED_AT)" >&2
  exit 1
fi

if [ "$DAYS" -le 30 ]; then
  echo "freshness OK ($DAYS days since $CREATED_AT; threshold = 30)"
  exit 0
fi

echo "freshness VIOLATION: $DAYS days > 30 (created_at=$CREATED_AT)" >&2
exit 1
