#!/usr/bin/env bash
# chunk-runner dispatch.sh v0.2 — next-pending-chunk launcher
#
# Usage:
#   dispatch.sh <chunking-doc-path>
#   e.g. dispatch.sh specs/039-task-reconciliation-to-pod/pre-spec-strategic-chunking.md
#
# Reads the `## Progress Tracker` table in the chunking doc, finds the first
# row with status = `pending`, and invokes run.sh against that chunk id.
# Sequential execution per the 038 cadence — one chunk at a time.
#
# Exit codes (0/1/2 propagated from run.sh; 3 is dispatcher-level):
#   0 — chunk launched + completed, OR no pending chunks (silent no-op)
#   1 — runner-level error (propagated from run.sh)
#   2 — runner clean-halt (propagated from run.sh)
#   3 — dispatcher-level error (bad args, doc missing, table absent)

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
RUN_SH="${REPO_ROOT}/tools/chunk-runner/run.sh"

die() {
    echo "dispatch.sh: $1" >&2
    exit 3
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'HELP'
chunk-runner dispatch.sh — next-pending-chunk launcher

USAGE
    dispatch.sh <chunking-doc-path>
    dispatch.sh -h | --help

BEHAVIOR
    Parses the `## Progress Tracker` table in the chunking doc, finds the
    first row whose Status column is `pending` (case-insensitive), and
    exec's run.sh against that chunk id. Silently exits 0 if no pending
    chunks remain. Sequential enforcement is implicit in the table —
    upstream chunks must be marked `merged` before a later chunk can be
    the first pending row.

EXIT CODES
    0   dispatched + completed, OR no pending chunks (silent no-op)
    1   runner error (propagated from run.sh)
    2   runner clean halt (propagated from run.sh)
    3   dispatcher-level error (missing args, doc not found, table absent)

RELATED
    run.sh --help  for the downstream runner's full option surface
HELP
    exit 0
fi

[[ $# -lt 1 ]] && die "usage: dispatch.sh <chunking-doc-path>  (use -h for help)"
DOC="$1"
[[ -f "$DOC" ]] || die "chunking doc not found: $DOC"

# Find the first pending row under `## Progress Tracker`. The table shape is:
#   | Chunk | Title | Status | Feature Dir | Branch | Gate |
# We extract the first cell (chunk id) from rows whose third cell is "pending".
NEXT_CHUNK=$(awk '
    /^## Progress Tracker/ { in_tbl = 1; next }
    in_tbl && /^## / { exit }
    in_tbl && /^\|/ {
        # Split on |
        n = split($0, cells, "|")
        if (n < 4) next
        # cells[1] is the empty before the first |, cells[2] is Chunk, cells[4] is Status
        id = cells[2]
        status = cells[4]
        gsub(/^[ \t]+|[ \t]+$/, "", id)
        gsub(/^[ \t]+|[ \t]+$/, "", status)
        status = tolower(status)
        if (id == "Chunk" || id == "" || id ~ /^-+$/) next
        if (status == "pending") { print id; exit }
    }
' "$DOC")

if [[ -z "$NEXT_CHUNK" ]]; then
    echo "dispatch.sh: no pending chunks in $DOC" >&2
    exit 0
fi

echo "dispatch.sh: launching chunk ${NEXT_CHUNK} from $(basename "$DOC")" >&2
exec "$RUN_SH" "$DOC" "$NEXT_CHUNK"
