#!/usr/bin/env bash
# Unit tests for parse_args in run.sh
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
source "${REPO_ROOT}/tools/chunk-runner/run.sh"

PASS=0
FAIL=0

check() {
    local descr="$1" actual="$2" expected="$3"
    if [[ "$actual" == "$expected" ]]; then
        PASS=$((PASS + 1)); echo "PASS  $descr"
    else
        FAIL=$((FAIL + 1)); echo "FAIL  $descr"
        echo "      expected: $expected"
        echo "      actual:   $actual"
    fi
}

reset_state() {
    CHUNKING_DOC_ARG=""; CHUNK_ID_ARG=""
    RESUME_FROM=""; STAGES_LIST=""; RERUN_STAGE=""
    SUB_BEAD=""
    PARTIAL_RUN=0
}

# 1. Default: two positional args, no flags
reset_state
parse_args specs/foo.md 001
check "default: CHUNKING_DOC_ARG" "$CHUNKING_DOC_ARG" "specs/foo.md"
check "default: CHUNK_ID_ARG" "$CHUNK_ID_ARG" "001"
check "default: PARTIAL_RUN=0" "$PARTIAL_RUN" "0"

# 2. --resume-from before positionals
reset_state
parse_args --resume-from analyze specs/foo.md 001
check "resume-from: RESUME_FROM" "$RESUME_FROM" "analyze"
check "resume-from: PARTIAL_RUN=1" "$PARTIAL_RUN" "1"
check "resume-from: CHUNK_ID_ARG" "$CHUNK_ID_ARG" "001"

# 3. --stages with comma list
reset_state
parse_args --stages implement,superb_verify specs/foo.md 001
check "stages: STAGES_LIST" "$STAGES_LIST" "implement,superb_verify"
check "stages: PARTIAL_RUN=1" "$PARTIAL_RUN" "1"

# 4. --rerun single stage
reset_state
parse_args --rerun analyze specs/foo.md 001
check "rerun: RERUN_STAGE" "$RERUN_STAGE" "analyze"
check "rerun: PARTIAL_RUN=1" "$PARTIAL_RUN" "1"

# 5. Mutual exclusion: --resume-from + --stages
reset_state
rc=0
(parse_args --resume-from analyze --stages implement specs/foo.md 001) 2>/dev/null || rc=$?
check "mutex resume+stages exits 1" "$rc" "1"

# 6. Mutual exclusion: --stages + --rerun
reset_state
rc=0
(parse_args --stages analyze --rerun implement specs/foo.md 001) 2>/dev/null || rc=$?
check "mutex stages+rerun exits 1" "$rc" "1"

# 7. Unknown stage rejected
reset_state
rc=0
(parse_args --resume-from bogus specs/foo.md 001) 2>/dev/null || rc=$?
check "unknown stage exits 1" "$rc" "1"

# 8. Missing positional (only one given)
reset_state
rc=0
(parse_args --resume-from analyze specs/foo.md) 2>/dev/null || rc=$?
check "missing chunk-id exits 1" "$rc" "1"

# 9. --stages with whitespace is stripped
reset_state
parse_args --stages "analyze, superb_verify" specs/foo.md 001
check "stages: whitespace stripped" "$STAGES_LIST" "analyze,superb_verify"

# --- SELECTED_STAGES computation ---
reset_selection() { SELECTED_STAGES=(); }

reset_state; reset_selection
parse_args specs/foo.md 001
compute_selected_stages
check "default: 10 stages selected" "${#SELECTED_STAGES[@]}" "10"
check "default: first stage" "${SELECTED_STAGES[0]}" "specify"
check "default: last stage" "${SELECTED_STAGES[9]}" "post_verify"

reset_state; reset_selection
parse_args --resume-from analyze specs/foo.md 001
compute_selected_stages
check "resume-from analyze: count" "${#SELECTED_STAGES[@]}" "6"
check "resume-from analyze: first" "${SELECTED_STAGES[0]}" "analyze"
check "resume-from analyze: last" "${SELECTED_STAGES[5]}" "post_verify"

reset_state; reset_selection
parse_args --stages implement,superb_verify specs/foo.md 001
compute_selected_stages
check "stages subset: count" "${#SELECTED_STAGES[@]}" "2"
check "stages subset: [0]" "${SELECTED_STAGES[0]}" "implement"
check "stages subset: [1]" "${SELECTED_STAGES[1]}" "superb_verify"

# Order preserves PIPELINE even if user reorders
reset_state; reset_selection
parse_args --stages superb_verify,implement specs/foo.md 001
compute_selected_stages
check "stages order: PIPELINE order preserved" "${SELECTED_STAGES[0]}" "implement"
check "stages order: second" "${SELECTED_STAGES[1]}" "superb_verify"

reset_state; reset_selection
parse_args --rerun analyze specs/foo.md 001
compute_selected_stages
check "rerun: count" "${#SELECTED_STAGES[@]}" "1"
check "rerun: single" "${SELECTED_STAGES[0]}" "analyze"

# --- post_verify stage reachable via --rerun and --resume-from ---

reset_state; reset_selection
parse_args --rerun post_verify specs/foo.md 001
compute_selected_stages
check "rerun post_verify: count" "${#SELECTED_STAGES[@]}" "1"
check "rerun post_verify: stage" "${SELECTED_STAGES[0]}" "post_verify"

reset_state; reset_selection
parse_args --resume-from post_verify specs/foo.md 001
compute_selected_stages
check "resume-from post_verify: count" "${#SELECTED_STAGES[@]}" "1"
check "resume-from post_verify: stage" "${SELECTED_STAGES[0]}" "post_verify"

# --- --sub-bead flag ---

reset_state
parse_args --sub-bead pam-abc123 specs/foo.md 001
check "--sub-bead: SUB_BEAD set" "$SUB_BEAD" "pam-abc123"
check "--sub-bead: CHUNK_ID_ARG preserved" "$CHUNK_ID_ARG" "001"
check "--sub-bead: PARTIAL_RUN unchanged" "$PARTIAL_RUN" "0"

# --sub-bead without value should fail
reset_state
rc=0
(parse_args --sub-bead) 2>/dev/null || rc=$?
check "--sub-bead without value exits 1" "$rc" "1"

# --sub-bead alongside --resume-from (not mutually exclusive with stage selectors)
reset_state
parse_args --sub-bead pam-xyz --resume-from superb_verify specs/foo.md 001
check "--sub-bead + --resume-from: SUB_BEAD" "$SUB_BEAD" "pam-xyz"
check "--sub-bead + --resume-from: RESUME_FROM" "$RESUME_FROM" "superb_verify"

echo "========================="
echo "Results: $PASS pass, $FAIL fail"
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
