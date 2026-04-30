#!/usr/bin/env bash
# chunk-runner run.sh v0.2 — single-chunk pipeline runner
#
# Usage:
#   run.sh <chunking-doc-path> <chunk-id>
#   e.g. run.sh specs/039-task-reconciliation-to-pod/pre-spec-strategic-chunking.md 001
#
# Env:
#   CHUNK_RUNNER_TEST=1         # dry-run: no claude spawns, no bead writes, JSONL still written
#   CHUNK_RUNNER_PROMPTS_DIR    # override tools/chunk-runner/prompts
#   REPO_ROOT                   # override repo root (defaults to `git rev-parse --show-toplevel`)
#
# Exit codes:
#   0 — pipeline completed, branch pushed, retro emitted
#   1 — unexpected error (runner bug; state may be inconsistent)
#   2 — clean halt (gate failure / analyze CRITICAL / budget exceeded); review bead written
#
# Input contract: the chunking doc is the sole declarative input. It is produced
# by docs/pre-spec-build/process.md (Stage 6 approved artifact). Runner consumes:
#   - `## Chunk <id>: <name>` section as feature scope + success criteria
#   - `## Plan-Stage Decisions Across All Chunks` bullet matching this chunk, as
#     pre-declared defaults fed into /speckit.plan
# No per-chunk manifest files. No input beads. Beads are OUTPUT surfaces only:
#   - ops:mut journal entry on branch push (via plain `bd create`)
#   - ops:retro run retrospective (closed bead, signal-classified)
#   - review:gate-refusal on clean halt (open bead, reviewer's queue)
#
# JSONL event schema (one JSON object per line, fields: ts, run_id, chunk_id,
# spec_slug, event, [stage], [status], [halt_reason], [duration_ms], [data]):
#   start | pre_flight_check | branch_ready |
#   stage_started | stage_completed | stage_halted |
#   feature_branch_established | sc_verified | sc_failed | branch_pushed |
#   retro_emitted | complete | error

set -euo pipefail

# ---------- paths + bootstrap ----------
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PROMPTS_DIR="${CHUNK_RUNNER_PROMPTS_DIR:-${REPO_ROOT}/tools/chunk-runner/prompts}"
RUNS_DIR="${REPO_ROOT}/tools/chunk-runner/runs"
TEST_MODE="${CHUNK_RUNNER_TEST:-0}"
# Bead-id prefix used when scraping `bd create` output. Detected from the
# beads config's issue-prefix; falls back to a permissive regex if unset.
BEAD_PREFIX="${CHUNK_RUNNER_BEAD_PREFIX:-}"
if [[ -z "$BEAD_PREFIX" ]]; then
    BEAD_PREFIX=$(awk -F': *' '/^[[:space:]]*issue-prefix:[[:space:]]*"/{gsub(/"/,"",$2); print $2; exit}' \
        "${REPO_ROOT}/.beads/config.yaml" 2>/dev/null || true)
fi
[[ -z "$BEAD_PREFIX" ]] && BEAD_PREFIX="$(basename "$REPO_ROOT")"
BEAD_ID_REGEX="${BEAD_PREFIX}-[a-z0-9]+(\.[0-9]+)?"
# Exit-state tracking (set by main/clean_halt/die before exit; read by the EXIT trap)
EXIT_STATE="error"
EXIT_STAGE=""
EXIT_REASON=""
REVIEW_BEAD=""
# Stall watchdog: polls claude CPU + stdout size every STALL_POLL_SEC seconds;
# force-kills claude after STALL_MINUTES of zero progress on BOTH signals.
# Calibrated to catch ep_poll / retry-loop stalls in minutes instead of the 4h wall-clock.
STALL_MINUTES="${CHUNK_RUNNER_STALL_MINUTES:-3}"
STALL_POLL_SEC="${CHUNK_RUNNER_STALL_POLL_SEC:-30}"
STALL_THRESHOLD=$(( (STALL_MINUTES * 60) / STALL_POLL_SEC ))
[[ "$STALL_THRESHOLD" -lt 2 ]] && STALL_THRESHOLD=2
# Live-state file: written by the stall watchdog each poll interval. Read for
# real-time heartbeat by external monitors. Removed on run exit.
LIVE_STATE_FILE=""
RUN_ID="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || openssl rand -hex 16)"
RUN_START_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# Session breadcrumb: ~/.claude/projects/<slugified-repo-path>/memory/active-session.md
# The slug is the repo path with `/` and `.` replaced by `-`, prefixed with `-`,
# matching Claude Code's session storage convention.
_BREADCRUMB_SLUG="$(echo "$REPO_ROOT" | sed 's|/|-|g; s|\.|-|g')"
BREADCRUMB_FILE="${HOME}/.claude/projects/${_BREADCRUMB_SLUG}/memory/active-session.md"

# Canonical speckit pipeline per docs/pre-spec-build/process.md Stage 7 (chunked path).
# superb_finish intentionally omitted — the maintainer runs it after human review.
# post_verify runs after superb_verify: ticks gate checkboxes + bumps chunking-doc version.
PIPELINE=(specify clarify plan tasks analyze superb_review superb_tdd implement superb_verify post_verify)

# Late-bound
CHUNKING_DOC=""
CHUNK_ID=""
CHUNK_NAME=""
CHUNK_SECTION=""
PLAN_DECISIONS_MD=""
FEATURE_SPEC_DIR=""
SPEC_SLUG=""
JSONL_LOG=""
STAGES_COMPLETED=0
BEAD_MUTATIONS=0
# Captured after /speckit.specify passes its post-stage invariant. spec-kit's
# create-new-feature.sh uses its own branch-naming convention (spec-number
# prefix, e.g. "046-039-task-reconciliation-to-pod-chunk-002") which differs
# from the runner's pre-flight-derived name ("<slug>/chunk-<id>"). Downstream
# stages (notably push_branch) read this var to act on the actual branch.
ACTUAL_BRANCH=""
# Optional sub-bead ID passed via --sub-bead. When non-empty, the runner calls
# `bd close "$SUB_BEAD"` after push_branch. Set by parse_args.
SUB_BEAD=""

# ---------- helpers ----------

die() {
    local msg="$1"
    echo "ERROR: $msg" >&2
    emit_event error "$(jq -nc --arg r "$msg" '{halt_reason:$r}')" 2>/dev/null || true
    exit 1
}

log_info() {
    echo "[$(date -u +%H:%M:%SZ)] $1" >&2
}

# ---------- live-state + stall watchdog ----------
#
# The live-state file is a JSON document updated on every watchdog poll. It
# exposes the empirical values a dashboard needs to render the current run:
# claude PID + CPU time + stdout size + stall-counter + the current stage.
# Removed on run exit.
#
# Format (stable; downstream readers rely on it):
#   {
#     "run_id": "...",
#     "chunk_id": "...",
#     "spec_slug": "...",
#     "current_stage": "specify|clarify|...|superb_verify",
#     "stage_started_ts": "ISO-8601",
#     "claude_pid": 12345,
#     "stdout_path": "/tmp/tmp.xxxxx",
#     "last_sample": {
#       "ts": "ISO-8601",
#       "cpu_time_s": 42,
#       "stdout_size_bytes": 1024
#     },
#     "stall_count": 0,
#     "stall_threshold": 6,
#     "stall_poll_sec": 30
#   }

write_live_state() {
    # Args: stage_name stage_started_ts claude_pid stdout_path cpu_time_s stdout_size_bytes stall_count
    [[ -z "$LIVE_STATE_FILE" ]] && return
    local tmp="${LIVE_STATE_FILE}.tmp.$$"
    jq -nc \
        --arg run_id "$RUN_ID" \
        --arg chunk_id "$CHUNK_ID" \
        --arg spec_slug "$SPEC_SLUG" \
        --arg stage "${1:-}" \
        --arg stage_ts "${2:-}" \
        --argjson pid "${3:-0}" \
        --arg stdout "${4:-}" \
        --arg sample_ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --argjson cpu "${5:-0}" \
        --argjson size "${6:-0}" \
        --argjson stall "${7:-0}" \
        --argjson threshold "$STALL_THRESHOLD" \
        --argjson poll "$STALL_POLL_SEC" \
        '{run_id:$run_id, chunk_id:$chunk_id, spec_slug:$spec_slug,
          current_stage:$stage, stage_started_ts:$stage_ts,
          claude_pid:$pid, stdout_path:$stdout,
          last_sample:{ts:$sample_ts, cpu_time_s:$cpu, stdout_size_bytes:$size},
          stall_count:$stall, stall_threshold:$threshold, stall_poll_sec:$poll}' \
        > "$tmp" 2>/dev/null && mv "$tmp" "$LIVE_STATE_FILE" 2>/dev/null
}

clear_live_state() {
    [[ -n "$LIVE_STATE_FILE" ]] && rm -f "$LIVE_STATE_FILE" 2>/dev/null
}

# Read combined user+system CPU time for a PID, in seconds.
# Returns 0 if the process is gone.
read_cpu_time_s() {
    local pid="$1"
    local stat_line
    stat_line=$(cat "/proc/${pid}/stat" 2>/dev/null) || { echo 0; return; }
    # /proc/<pid>/stat: the "comm" field (in parens) may contain spaces.
    # Strip it safely: content after "... (comm) " is the rest of the fields.
    local after_comm="${stat_line#*) }"
    # After comm, fields are: state($1) ppid($2) pgrp($3) session($4) tty_nr($5)
    # tpgid($6) flags($7) minflt($8) cminflt($9) majflt($10) cmajflt($11)
    # utime($12) stime($13) ...
    # shellcheck disable=SC2086
    set -- $after_comm
    local utime="${12:-0}"
    local stime="${13:-0}"
    local ticks
    ticks=$(getconf CLK_TCK 2>/dev/null || echo 100)
    echo $(( (utime + stime) / ticks ))
}

# Background watchdog. Monitors claude PID's CPU + stdout-file size.
# On STALL_THRESHOLD consecutive zero-progress samples, writes a reason
# file and SIGKILLs claude + its subprocess tree.
stall_watchdog() {
    local claude_pid="$1"
    local stdout_path="$2"
    local stage_name="$3"
    local stage_start_ts="$4"
    local reason_file="$5"
    local prev_cpu=0
    local prev_size=0
    local stall_count=0
    # Initial sample
    local cpu size
    cpu=$(read_cpu_time_s "$claude_pid")
    size=$(stat -c %s "$stdout_path" 2>/dev/null || echo 0)
    write_live_state "$stage_name" "$stage_start_ts" "$claude_pid" "$stdout_path" "$cpu" "$size" 0
    prev_cpu="$cpu"
    prev_size="$size"
    while kill -0 "$claude_pid" 2>/dev/null; do
        sleep "$STALL_POLL_SEC"
        kill -0 "$claude_pid" 2>/dev/null || break
        cpu=$(read_cpu_time_s "$claude_pid")
        size=$(stat -c %s "$stdout_path" 2>/dev/null || echo 0)
        if [[ "$cpu" == "$prev_cpu" && "$size" == "$prev_size" ]]; then
            stall_count=$((stall_count + 1))
        else
            stall_count=0
        fi
        write_live_state "$stage_name" "$stage_start_ts" "$claude_pid" "$stdout_path" "$cpu" "$size" "$stall_count"
        if [[ "$stall_count" -ge "$STALL_THRESHOLD" ]]; then
            local elapsed_s=$(( stall_count * STALL_POLL_SEC ))
            echo "stall watchdog: no progress on cpu_time or stdout for ${elapsed_s}s (${stall_count} consecutive samples at ${STALL_POLL_SEC}s interval); SIGKILL claude pid ${claude_pid}" > "$reason_file"
            # Kill claude's subprocess tree first (MCP servers + spawned bashes), then claude itself
            pkill -KILL -P "$claude_pid" 2>/dev/null || true
            kill -KILL "$claude_pid" 2>/dev/null
            break
        fi
        prev_cpu="$cpu"
        prev_size="$size"
    done
}

# ---------- exit notification (banner + speaker) ----------

emit_exit_banner() {
    local line="================================================================"
    {
        echo ""
        echo "$line"
        printf "  CHUNK-RUNNER %s" "$(echo "$EXIT_STATE" | tr '[:lower:]' '[:upper:]')"
        [[ -n "$EXIT_STAGE" ]] && printf ": %s" "$EXIT_STAGE"
        echo ""
        if [[ -n "$CHUNK_ID$SPEC_SLUG" ]]; then
            echo "  chunk: ${CHUNK_ID:-?}  spec: ${SPEC_SLUG:-?}"
        fi
        [[ -n "$EXIT_REASON" ]] && echo "  reason: $EXIT_REASON"
        [[ -n "$REVIEW_BEAD" ]] && echo "  review bead: $REVIEW_BEAD"
        [[ -n "$JSONL_LOG" ]] && echo "  log: $JSONL_LOG"
        echo "$line"
        echo ""
    } >&2
}

notify_exit() {
    # Single EXIT trap handler. Called on success, clean-halt, error, and Ctrl-C.
    # EXIT_STATE defaults to "error" and is overridden by main/clean_halt/die.
    clear_live_state
    emit_exit_banner
}
emit_event() {
    # emit_event <event-name> [<extra-json-fragment>]
    local event="$1"
    local extra="${2:-}"
    local base
    base=$(jq -nc \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg run_id "$RUN_ID" \
        --arg chunk_id "$CHUNK_ID" \
        --arg spec_slug "$SPEC_SLUG" \
        --arg event "$event" \
        '{ts:$ts, run_id:$run_id, chunk_id:$chunk_id, spec_slug:$spec_slug, event:$event}')
    local merged
    if [[ -n "$extra" ]]; then
        merged=$(echo "$base" | jq -c --argjson x "$extra" '. + $x')
    else
        merged="$base"
    fi
    if [[ -n "$JSONL_LOG" ]]; then
        echo "$merged" >> "$JSONL_LOG"
    else
        echo "$merged"
    fi
}

# ---------- argument parsing ----------

# parse_args: consumes "$@"; sets CHUNKING_DOC_ARG, CHUNK_ID_ARG, RESUME_FROM,
# STAGES_LIST, RERUN_STAGE, PARTIAL_RUN. Exits 1 on invalid usage.
#
# Recognised flags (all optional, any order, all before the two positionals):
#   --resume-from <stage>   — run <stage> through end of PIPELINE
#   --stages <s1,s2,...>    — run exactly these stages in PIPELINE order
#   --rerun <stage>         — run only <stage>; caller asserts idempotency
# Mutual exclusion: at most one of the three may be supplied.
parse_args() {
    CHUNKING_DOC_ARG=""
    CHUNK_ID_ARG=""
    RESUME_FROM=""
    STAGES_LIST=""
    RERUN_STAGE=""
    SUB_BEAD=""
    PARTIAL_RUN=0
    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --sub-bead)
                [[ -z "${2:-}" ]] && { echo "ERROR: --sub-bead requires an argument" >&2; exit 1; }
                SUB_BEAD="$2"
                shift 2
                ;;
            --resume-from)
                [[ -z "${2:-}" ]] && { echo "ERROR: --resume-from requires an argument" >&2; exit 1; }
                RESUME_FROM="$2"
                shift 2
                ;;
            --stages)
                [[ -z "${2:-}" ]] && { echo "ERROR: --stages requires an argument" >&2; exit 1; }
                # Strip whitespace inside the comma list
                STAGES_LIST="$(echo "$2" | tr -d '[:space:]')"
                shift 2
                ;;
            --rerun)
                [[ -z "${2:-}" ]] && { echo "ERROR: --rerun requires an argument" >&2; exit 1; }
                RERUN_STAGE="$2"
                shift 2
                ;;
            --)
                shift
                while [[ $# -gt 0 ]]; do positional+=("$1"); shift; done
                ;;
            -*)
                echo "ERROR: unknown flag: $1" >&2
                exit 1
                ;;
            *)
                positional+=("$1")
                shift
                ;;
        esac
    done

    # Mutual exclusion
    local flag_count=0
    [[ -n "$RESUME_FROM" ]] && flag_count=$((flag_count + 1))
    [[ -n "$STAGES_LIST" ]] && flag_count=$((flag_count + 1))
    [[ -n "$RERUN_STAGE" ]] && flag_count=$((flag_count + 1))
    if [[ "$flag_count" -gt 1 ]]; then
        echo "ERROR: --resume-from, --stages, and --rerun are mutually exclusive" >&2
        exit 1
    fi
    [[ "$flag_count" -eq 1 ]] && PARTIAL_RUN=1

    # Positional args
    if [[ "${#positional[@]}" -lt 2 ]]; then
        echo "ERROR: expected <chunking-doc-path> <chunk-id>" >&2
        exit 1
    fi
    CHUNKING_DOC_ARG="${positional[0]}"
    CHUNK_ID_ARG="${positional[1]}"

    # Validate stage names against PIPELINE
    if [[ -n "$RESUME_FROM" ]]; then
        _assert_valid_stage "$RESUME_FROM" "--resume-from"
    fi
    if [[ -n "$RERUN_STAGE" ]]; then
        _assert_valid_stage "$RERUN_STAGE" "--rerun"
    fi
    if [[ -n "$STAGES_LIST" ]]; then
        local IFS=','
        # shellcheck disable=SC2206
        local list=($STAGES_LIST)
        for s in "${list[@]}"; do
            _assert_valid_stage "$s" "--stages"
        done
    fi
}

_assert_valid_stage() {
    local name="$1" flag="$2"
    for p in "${PIPELINE[@]}"; do
        [[ "$p" == "$name" ]] && return 0
    done
    echo "ERROR: $flag: '$name' is not a pipeline stage (valid: ${PIPELINE[*]})" >&2
    exit 1
}

# compute_selected_stages: reads RESUME_FROM/STAGES_LIST/RERUN_STAGE + PIPELINE,
# sets SELECTED_STAGES (array) preserving PIPELINE order regardless of input order.
compute_selected_stages() {
    SELECTED_STAGES=()
    if [[ -n "$RERUN_STAGE" ]]; then
        SELECTED_STAGES=("$RERUN_STAGE")
        return 0
    fi
    if [[ -n "$RESUME_FROM" ]]; then
        local started=0
        for p in "${PIPELINE[@]}"; do
            if [[ "$p" == "$RESUME_FROM" ]]; then started=1; fi
            [[ "$started" -eq 1 ]] && SELECTED_STAGES+=("$p")
        done
        return 0
    fi
    if [[ -n "$STAGES_LIST" ]]; then
        local IFS=','
        # shellcheck disable=SC2206
        local wanted=($STAGES_LIST)
        unset IFS
        for p in "${PIPELINE[@]}"; do
            for w in "${wanted[@]}"; do
                if [[ "$p" == "$w" ]]; then
                    SELECTED_STAGES+=("$p")
                    break
                fi
            done
        done
        return 0
    fi
    SELECTED_STAGES=("${PIPELINE[@]}")
}

# ---------- chunking-doc parser ----------

# Extract the `## Chunk <id>: ...` section up to the next `## ` heading.
extract_chunk_section() {
    awk -v id="$CHUNK_ID" '
        /^## / {
            if (in_section) { exit }
            if ($0 ~ "^## Chunk " id "(:|$| )") { in_section = 1 }
        }
        in_section { print }
    ' "$CHUNKING_DOC"
}

# Extract the `- **Chunk <id>**` bullet block from `## Plan-Stage Decisions Across All Chunks`.
extract_plan_decisions() {
    awk -v id="$CHUNK_ID" '
        /^## Plan-Stage Decisions Across All Chunks/ { in_pd = 1; next }
        in_pd && /^## / { in_pd = 0 }
        in_pd && $0 ~ "^- \\*\\*Chunk " id "\\*\\*" {
            in_bullet = 1
            print
            next
        }
        in_pd && in_bullet && /^- \*\*Chunk/ { in_bullet = 0 }
        in_pd && in_bullet { print }
    ' "$CHUNKING_DOC"
}

load_chunk() {
    CHUNKING_DOC="$1"
    CHUNK_ID="$2"

    if [[ ! -f "$CHUNKING_DOC" ]]; then
        die "chunking doc not found: $CHUNKING_DOC"
    fi

    FEATURE_SPEC_DIR="$(cd "$(dirname "$CHUNKING_DOC")" && pwd)"
    SPEC_SLUG="$(basename "$FEATURE_SPEC_DIR")"

    CHUNK_SECTION="$(extract_chunk_section)"
    if [[ -z "$CHUNK_SECTION" ]]; then
        die "no '## Chunk ${CHUNK_ID}' section in ${CHUNKING_DOC}"
    fi

    # Heading: "## Chunk 001: Channel reader interface..."
    local heading
    heading="$(echo "$CHUNK_SECTION" | head -1)"
    CHUNK_NAME="$(echo "$heading" | sed -E "s/^## Chunk ${CHUNK_ID}: ?//; s/^## Chunk ${CHUNK_ID}//")"

    PLAN_DECISIONS_MD="$(extract_plan_decisions)"

    # JSONL log + live-state file under tools/chunk-runner/runs/
    mkdir -p "$RUNS_DIR"
    JSONL_LOG="${RUNS_DIR}/${SPEC_SLUG}-chunk-${CHUNK_ID}-${RUN_START_TS}.jsonl"
    LIVE_STATE_FILE="${RUNS_DIR}/${SPEC_SLUG}-chunk-${CHUNK_ID}-${RUN_START_TS}.live.json"
    : > "$JSONL_LOG"

    log_info "chunking-doc=$CHUNKING_DOC chunk_id=$CHUNK_ID name='$CHUNK_NAME' spec=$SPEC_SLUG log=$JSONL_LOG test=$TEST_MODE"
    log_info "stall watchdog: $STALL_MINUTES min ($STALL_THRESHOLD samples at ${STALL_POLL_SEC}s interval); live-state at $LIVE_STATE_FILE"
}

# ---------- pre-flight ----------

# Required prior artifacts for a given first-stage (relative to FEATURE_SPEC_DIR).
# Emits one pre_flight_check event (pass or fail). Returns 0 if all present, 1 otherwise.
check_prior_artifacts() {
    local stage="$1"
    local -a required=()
    case "$stage" in
        specify)                                 required=() ;;
        clarify|plan)                            required=(spec.md) ;;
        tasks)                                   required=(spec.md plan.md) ;;
        analyze|superb_review|superb_tdd|implement|superb_verify|post_verify)
                                                 required=(spec.md plan.md tasks.md) ;;
        *) echo "ERROR: unknown stage in artifact map: $stage" >&2; return 1 ;;
    esac
    local missing=()
    for f in "${required[@]}"; do
        [[ -f "${FEATURE_SPEC_DIR}/${f}" ]] || missing+=("$f")
    done
    if [[ "${#missing[@]}" -gt 0 ]]; then
        emit_event pre_flight_check "$(jq -nc --arg s "$stage" --arg m "${missing[*]}" '{data:{check:"prior-stage artifacts present", first_stage:$s, missing:$m}, status:"fail"}')"
        return 1
    fi
    emit_event pre_flight_check "$(jq -nc --arg s "$stage" '{data:{check:"prior-stage artifacts present", first_stage:$s}, status:"pass"}')"
    return 0
}

# Hardcoded pre-flight checks (no per-chunk manifest). Gate-specific checks
# declared in the chunking doc's `## Infrastructure Gate Checklists` are
# human-facing — the runner does NOT auto-execute them. Gate state flows
# through the Progress Tracker row ("merged" / "pending") which the dispatcher
# reads. A chunk cannot start until its upstream chunks are merged.
run_preflight() {
    local failed=0

    # 1. On main with clean working tree (bypassed in TEST mode)
    if [[ "$TEST_MODE" == "1" ]]; then
        emit_event pre_flight_check "$(jq -nc '{data:{check:"on main with clean working tree", test_mode:true}, status:"pass"}')"
    else
        local cur
        cur="$(git -C "$REPO_ROOT" branch --show-current)"
        if [[ "$cur" == "main" ]] && git -C "$REPO_ROOT" diff --quiet && git -C "$REPO_ROOT" diff --cached --quiet; then
            emit_event pre_flight_check "$(jq -nc '{data:{check:"on main with clean working tree"}, status:"pass"}')"
        else
            emit_event pre_flight_check "$(jq -nc --arg cur "$cur" '{data:{check:"on main with clean working tree", current_branch:$cur}, status:"fail"}')"
            failed=1
        fi
    fi

    # 2. Conventional feature branch does not already exist
    local expected_branch
    expected_branch="$(basename "$FEATURE_SPEC_DIR")/chunk-${CHUNK_ID}"
    if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/${expected_branch}"; then
        emit_event pre_flight_check "$(jq -nc --arg b "$expected_branch" '{data:{check:"feature branch does not exist", branch:$b}, status:"fail"}')"
        failed=1
    else
        emit_event pre_flight_check "$(jq -nc --arg b "$expected_branch" '{data:{check:"feature branch does not exist", branch:$b}, status:"pass"}')"
    fi

    # 3. Prompts directory reachable
    if [[ -d "$PROMPTS_DIR" ]]; then
        emit_event pre_flight_check "$(jq -nc --arg d "$PROMPTS_DIR" '{data:{check:"prompts directory present", path:$d}, status:"pass"}')"
    else
        emit_event pre_flight_check "$(jq -nc --arg d "$PROMPTS_DIR" '{data:{check:"prompts directory present", path:$d}, status:"fail"}')"
        failed=1
    fi

    # 4. All pipeline prompt templates exist
    for stage in "${PIPELINE[@]}"; do
        local tmpl="${PROMPTS_DIR}/$(echo "$stage" | tr '_' '-').md"
        if [[ -f "$tmpl" ]]; then
            emit_event pre_flight_check "$(jq -nc --arg s "$stage" --arg t "$tmpl" '{data:{check:"prompt template exists", stage:$s, template:$t}, status:"pass"}')"
        else
            emit_event pre_flight_check "$(jq -nc --arg s "$stage" --arg t "$tmpl" '{data:{check:"prompt template exists", stage:$s, template:$t}, status:"fail"}')"
            failed=1
        fi
    done

    return $failed
}

# Pre-flight for partial runs (entering mid-pipeline). Differs from run_preflight:
#   - Expects the feature branch to ALREADY exist and be checked out
#   - Validates prior-stage artifacts (unless --rerun, which skips by contract)
#   - Still checks prompts/ directory and per-stage templates (only selected stages)
# Sets ACTUAL_BRANCH on success so push_branch has a target.
run_partial_preflight() {
    local failed=0
    local expected_branch
    expected_branch="$(basename "$FEATURE_SPEC_DIR")/chunk-${CHUNK_ID}"

    if [[ "$TEST_MODE" == "1" ]]; then
        emit_event pre_flight_check "$(jq -nc --arg b "$expected_branch" '{data:{check:"on feature branch with clean working tree", branch:$b, test_mode:true}, status:"pass"}')"
    else
        local cur
        cur="$(git -C "$REPO_ROOT" branch --show-current)"
        if [[ "$cur" == "$expected_branch" ]] && git -C "$REPO_ROOT" diff --quiet && git -C "$REPO_ROOT" diff --cached --quiet; then
            emit_event pre_flight_check "$(jq -nc --arg b "$expected_branch" '{data:{check:"on feature branch with clean working tree", branch:$b}, status:"pass"}')"
        else
            emit_event pre_flight_check "$(jq -nc --arg b "$expected_branch" --arg cur "$cur" '{data:{check:"on feature branch with clean working tree", expected:$b, current_branch:$cur}, status:"fail"}')"
            failed=1
        fi
    fi

    # Feature branch MUST exist (unlike run_preflight which requires it NOT to exist)
    if [[ "$TEST_MODE" == "1" ]]; then
        emit_event pre_flight_check "$(jq -nc --arg b "$expected_branch" '{data:{check:"feature branch exists", branch:$b, test_mode:true}, status:"pass"}')"
    elif git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/${expected_branch}"; then
        emit_event pre_flight_check "$(jq -nc --arg b "$expected_branch" '{data:{check:"feature branch exists", branch:$b}, status:"pass"}')"
    else
        emit_event pre_flight_check "$(jq -nc --arg b "$expected_branch" '{data:{check:"feature branch exists", branch:$b}, status:"fail"}')"
        failed=1
    fi

    # Prompts dir + templates for selected stages only
    if [[ -d "$PROMPTS_DIR" ]]; then
        emit_event pre_flight_check "$(jq -nc --arg d "$PROMPTS_DIR" '{data:{check:"prompts directory present", path:$d}, status:"pass"}')"
    else
        emit_event pre_flight_check "$(jq -nc --arg d "$PROMPTS_DIR" '{data:{check:"prompts directory present", path:$d}, status:"fail"}')"
        failed=1
    fi
    for stage in "${SELECTED_STAGES[@]}"; do
        local tmpl="${PROMPTS_DIR}/$(echo "$stage" | tr '_' '-').md"
        if [[ -f "$tmpl" ]]; then
            emit_event pre_flight_check "$(jq -nc --arg s "$stage" --arg t "$tmpl" '{data:{check:"prompt template exists", stage:$s, template:$t}, status:"pass"}')"
        else
            emit_event pre_flight_check "$(jq -nc --arg s "$stage" --arg t "$tmpl" '{data:{check:"prompt template exists", stage:$s, template:$t}, status:"fail"}')"
            failed=1
        fi
    done

    # Prior-stage artifacts — skipped for --rerun (caller asserts idempotency)
    if [[ -z "$RERUN_STAGE" ]]; then
        if ! check_prior_artifacts "${SELECTED_STAGES[0]}"; then
            failed=1
        fi
    else
        emit_event pre_flight_check "$(jq -nc --arg s "$RERUN_STAGE" '{data:{check:"prior-stage artifacts (skipped for --rerun)", rerun_stage:$s}, status:"pass"}')"
    fi

    # Stash the verified branch for push_branch
    [[ "$failed" -eq 0 && "$TEST_MODE" != "1" ]] && ACTUAL_BRANCH="$expected_branch"

    return $failed
}

# ---------- breadcrumb + branch readiness ----------

write_breadcrumb() {
    if [[ "$TEST_MODE" == "1" ]]; then
        echo "[TEST] would write breadcrumb to $BREADCRUMB_FILE" >&2
        return 0
    fi
    mkdir -p "$(dirname "$BREADCRUMB_FILE")"
    cat >> "$BREADCRUMB_FILE" <<EOF

## Active Chunk (chunk-runner $(date -u +%Y-%m-%dT%H:%M:%SZ))
- chunk_id: ${CHUNK_ID}
- chunk_name: ${CHUNK_NAME}
- spec_slug: ${SPEC_SLUG}
- screen_session: ${STY:-none}
- run_id: ${RUN_ID}
- jsonl_log: ${JSONL_LOG}
EOF
}

verify_branch_ready() {
    if [[ "$TEST_MODE" == "1" ]]; then
        emit_event branch_ready "$(jq -nc '{data:{test_mode:true}}')"
        return 0
    fi
    local head
    head=$(git -C "$REPO_ROOT" rev-parse --short HEAD)
    emit_event branch_ready "$(jq -nc --arg h "$head" '{data:{starting_branch:"main", head:$h}}')"
}

# ---------- stage execution ----------

render_prompt() {
    local stage_key="$1"
    local file_name
    file_name=$(echo "$stage_key" | tr '_' '-').md
    local tmpl="${PROMPTS_DIR}/${file_name}"
    if [[ ! -f "$tmpl" ]]; then
        echo "MISSING_TEMPLATE:${tmpl}"
        return 1
    fi

    # Derivable values (conventional)
    local branch="$(basename "$FEATURE_SPEC_DIR")/chunk-${CHUNK_ID}"
    local short_name="$(basename "$FEATURE_SPEC_DIR")-chunk-${CHUNK_ID}"
    local chunking_doc_rel="${CHUNKING_DOC#"${REPO_ROOT}/"}"
    local pre_spec_rel="${FEATURE_SPEC_DIR#"${REPO_ROOT}/"}/pre-spec.md"
    local feature_dir_rel="${FEATURE_SPEC_DIR#"${REPO_ROOT}/"}"

    # PRIOR_ARTIFACTS is informational — which files should exist from prior stages
    local prior
    case "$stage_key" in
        specify)         prior="(none — this stage creates spec.md)" ;;
        clarify)         prior="spec.md" ;;
        plan)            prior="spec.md (with Clarifications section)" ;;
        tasks)           prior="spec.md, plan.md, research.md, data-model.md, quickstart.md, contracts/*" ;;
        analyze)         prior="spec.md, plan.md, tasks.md" ;;
        superb_review)   prior="spec.md, plan.md, tasks.md (+ analyze findings)" ;;
        superb_tdd)      prior="tasks.md (TDD-ordered)" ;;
        implement)       prior="tasks.md (RED tests demonstrated by superb.tdd)" ;;
        superb_verify)   prior="all above + implementation commits" ;;
        post_verify)     prior="all above + superb_verify evidence (spec status = Verified)" ;;
    esac

    export CHUNK_ID CHUNK_NAME CHUNK_SECTION FEATURE_DIR BRANCH SHORT_NAME
    export PRIOR_ARTIFACTS PLAN_DECISIONS_MD CHUNKING_DOC_PATH PRE_SPEC_PATH RUN_ID SPEC_SLUG
    export SUB_BEAD_ID
    FEATURE_DIR="$feature_dir_rel"
    BRANCH="$branch"
    SHORT_NAME="$short_name"
    PRIOR_ARTIFACTS="$prior"
    CHUNKING_DOC_PATH="$chunking_doc_rel"
    PRE_SPEC_PATH="$pre_spec_rel"
    SUB_BEAD_ID="${SUB_BEAD:-}"

    envsubst '${CHUNK_ID} ${CHUNK_NAME} ${CHUNK_SECTION} ${FEATURE_DIR} ${BRANCH} ${SHORT_NAME} ${PRIOR_ARTIFACTS} ${PLAN_DECISIONS_MD} ${CHUNKING_DOC_PATH} ${PRE_SPEC_PATH} ${RUN_ID} ${SPEC_SLUG} ${SUB_BEAD_ID}' < "$tmpl"
}

parse_return_block() {
    # Stdin: claude output. The prompts instruct Claude to emit a single JSON
    # object between the === CHUNK-RUNNER RETURN === and === END === tags. We
    # extract that JSON directly and validate with jq. No markdown fences, no
    # key:value splitting — strict JSON is the contract.
    #
    # The PROMPT itself contains an example of the tag syntax (showing Claude
    # what to emit). We therefore capture the LAST === RETURN === ... === END
    # === block, not the first — the last one is Claude's actual response.
    #
    # Stdout: parsed JSON (compact) if valid, or an error-status JSON if the
    # block is missing / not valid JSON.
    local block
    block=$(awk '
        /=== CHUNK-RUNNER RETURN ===/ { cap = 1; buf = ""; next }
        /=== END ===/ && cap          { last = buf; cap = 0; next }
        cap                           { buf = buf $0 "\n" }
        END                           { printf "%s", last }
    ')
    if [[ -z "$block" ]]; then
        jq -nc '{status:"error", halt_reason:"no CHUNK-RUNNER RETURN block in output"}'
        return
    fi
    if echo "$block" | jq -c . 2>/dev/null; then
        return 0
    fi
    jq -nc --arg b "$block" '{status:"error", halt_reason:"CHUNK-RUNNER RETURN block is not valid JSON", raw:$b}'
}

run_stage() {
    local stage="$1"
    local stage_start_ms
    stage_start_ms=$(($(date +%s%N) / 1000000))
    emit_event stage_started "$(jq -nc --arg s "$stage" '{stage:$s}')"
    log_info "▶ stage: $stage (starting)"

    local prompt
    prompt=$(render_prompt "$stage")
    if [[ "$prompt" == MISSING_TEMPLATE:* ]]; then
        emit_event stage_halted "$(jq -nc --arg s "$stage" --arg r "$prompt" '{stage:$s, halt_reason:$r}')"
        return 2
    fi

    local out rc
    if [[ "$TEST_MODE" == "1" ]]; then
        local test_ret
        test_ret=$(jq -nc --arg s "$stage" '{stage:$s, status:"pass", artifacts_touched:"(test)"}')
        out="$(printf '%s\n\n=== CHUNK-RUNNER RETURN ===\n%s\n=== END ===\n' "$prompt" "$test_ret")"
        rc=0
    else
        local tmp_out watchdog_reason_file
        tmp_out=$(mktemp)
        watchdog_reason_file="${tmp_out}.watchdog"
        local timeout_sec="${CHUNK_RUNNER_STAGE_TIMEOUT_SEC:-14400}"
        local stage_start_iso
        stage_start_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)

        # Start claude + timeout wrapper in background so we can monitor it.
        timeout --preserve-status "${timeout_sec}" claude -p --dangerously-skip-permissions "$prompt" </dev/null >"$tmp_out" 2>&1 &
        local timeout_pid=$!
        # Find the actual claude PID (child of the timeout wrapper). Retry briefly to let fork land.
        local claude_pid=""
        local tries=0
        while [[ -z "$claude_pid" && $tries -lt 10 ]]; do
            claude_pid=$(pgrep -P "$timeout_pid" 2>/dev/null | head -1)
            [[ -n "$claude_pid" ]] && break
            sleep 0.5
            tries=$((tries + 1))
        done

        # Start watchdog if we have a claude PID; else proceed without (edge case)
        local watchdog_pid=""
        if [[ -n "$claude_pid" ]]; then
            stall_watchdog "$claude_pid" "$tmp_out" "$stage" "$stage_start_iso" "$watchdog_reason_file" &
            watchdog_pid=$!
        fi

        # Wait for claude to finish (normal exit, timeout, or watchdog SIGKILL)
        wait "$timeout_pid"
        rc=$?

        # Stop watchdog
        if [[ -n "$watchdog_pid" ]]; then
            kill "$watchdog_pid" 2>/dev/null || true
            wait "$watchdog_pid" 2>/dev/null || true
        fi

        out=$(cat "$tmp_out")
        # Capture watchdog reason (if it fired) before cleanup
        local watchdog_reason=""
        [[ -f "$watchdog_reason_file" ]] && watchdog_reason=$(cat "$watchdog_reason_file")
        rm -f "$tmp_out" "$watchdog_reason_file"
    fi

    local stage_end_ms duration
    stage_end_ms=$(($(date +%s%N) / 1000000))
    duration=$((stage_end_ms - stage_start_ms))

    if [[ "$rc" -ne 0 ]]; then
        local reason="claude -p exited with $rc"
        if [[ "$rc" -eq 124 ]]; then
            reason="stage exceeded wall-clock budget (${CHUNK_RUNNER_STAGE_TIMEOUT_SEC:-14400}s)"
        elif [[ "$rc" -eq 137 && -n "${watchdog_reason:-}" ]]; then
            reason="$watchdog_reason"
        elif [[ "$rc" -eq 137 ]]; then
            reason="claude killed by SIGKILL (rc=137); no watchdog reason recorded — likely external"
        fi
        emit_event stage_halted "$(jq -nc --arg s "$stage" --arg r "$reason" '{stage:$s, halt_reason:$r}')"
        return 2
    fi

    local ret_json
    ret_json=$(echo "$out" | parse_return_block)
    local ret_status
    ret_status=$(echo "$ret_json" | jq -r '.status // "error"')

    if [[ "$ret_status" != "pass" ]]; then
        local reason
        reason=$(echo "$ret_json" | jq -r '.halt_reason // "no halt_reason in return block"')
        emit_event stage_halted "$(jq -nc --arg s "$stage" --arg r "$reason" --argjson d $((duration)) --argjson r2 "$ret_json" '{stage:$s, halt_reason:$r, duration_ms:$d, data:$r2}')"
        return 2
    fi

    # Post-stage invariant: after /speckit.specify, the feature branch must be
    # checked out. If Claude's subprocess didn't land on a branch whose name
    # contains "chunk-<id>", something went wrong silently — halt before
    # subsequent stages operate on the wrong git state.
    if [[ "$stage" == "specify" && "$TEST_MODE" != "1" ]]; then
        local cur
        cur=$(git -C "$REPO_ROOT" branch --show-current)
        if [[ "$cur" != *"chunk-${CHUNK_ID}"* ]]; then
            emit_event stage_halted "$(jq -nc --arg s "$stage" --arg c "$cur" --arg id "$CHUNK_ID" '{stage:$s, halt_reason:"after /speckit.specify, not on a feature branch containing chunk-<id>", data:{current_branch:$c, expected_contains:("chunk-"+$id)}}')"
            return 2
        fi
        ACTUAL_BRANCH="$cur"
        # Broadcast the authoritative branch name for auto-chunk-runner's monitor
        # to resolve via lib/actual-branch.js (FR-024). The pre-computed placeholder
        # in state.feature_branch is speculative until this fires.
        emit_event feature_branch_established "$(jq -nc --arg b "$cur" '{data:{branch:$b}}')"
    fi

    emit_event stage_completed "$(jq -nc --arg s "$stage" --argjson d $((duration)) --argjson r "$ret_json" '{stage:$s, status:"pass", duration_ms:$d, data:$r}')"
    log_info "✓ stage: $stage (pass, $((duration / 1000))s)"
    STAGES_COMPLETED=$((STAGES_COMPLETED + 1))
    return 0
}

# ---------- clean-halt (output bead = review:gate-refusal) ----------

clean_halt() {
    local stage_name="$1"
    local halt_reason="$2"
    # Set exit-state vars for the EXIT trap (banner + TTS notify)
    EXIT_STATE="halt"
    EXIT_STAGE="$stage_name"
    EXIT_REASON="$halt_reason"
    log_info "✗ HALT on stage: $stage_name"
    log_info "  reason: $halt_reason"
    emit_event stage_halted "$(jq -nc --arg s "$stage_name" --arg r "$halt_reason" '{stage:$s, halt_reason:$r}')"
    local review_title="chunk-runner: halted on ${stage_name} for Chunk ${CHUNK_ID} (${SPEC_SLUG})"
    local review_body="## What was attempted

chunk-runner stage \`${stage_name}\` for Chunk ${CHUNK_ID} of ${SPEC_SLUG}.

## Why halted

${halt_reason}

## What was done instead

Emitted stage_halted JSONL event (${JSONL_LOG}) and exited with code 2.
No branch pushed. No retro emitted.

## Recovery options

- Read the JSONL log and the failing stage's output to pinpoint the gate/assertion that tripped
- If spec/plan/tasks needs revision: edit in-place on main (chunk branch has not been created), re-run
- If TDD stuck: invoke speckit.superb.debug
- If scope ambiguity: surface via re-chunking (run docs/pre-spec-build/process.md Stage 5-6)

Close this bead when the chunk is back on a clean path.
"
    local review_bead=""
    if [[ "$TEST_MODE" != "1" ]]; then
        review_bead=$(bd create \
            --title "$review_title" \
            --type task \
            --priority 2 \
            --labels "review:gate-refusal,chunk-runner" \
            --description "$review_body" 2>&1 | grep -oE "$BEAD_ID_REGEX" | head -1 || true)
        BEAD_MUTATIONS=$((BEAD_MUTATIONS + 1))
    else
        review_bead="${BEAD_PREFIX}-testTEST"
        echo "[TEST] would write review:gate-refusal bead: $review_title" >&2
    fi
    REVIEW_BEAD="$review_bead"
    log_info "clean-halt on $stage_name — review bead: $review_bead"
    exit 2
}

# ---------- post-flight SC tally ----------

# Enumerates SC-* tokens inside the chunk section. In real runs, /speckit.superb.verify
# is the authoritative evidence gate; this tally is a shallow existence check on the
# artifacts the gate should have produced.
run_success_criteria_tally() {
    local sc_ids
    sc_ids=$(echo "$CHUNK_SECTION" | grep -oE '\bSC-[a-zA-Z0-9-]+\b' | sort -u || true)
    if [[ -z "$sc_ids" ]]; then
        log_info "no SC-* tokens found in chunk section — skipping post-flight tally"
        return 0
    fi
    local verified=0
    while IFS= read -r sc_id; do
        [[ -z "$sc_id" ]] && continue
        emit_event sc_verified "$(jq -nc --arg id "$sc_id" '{data:{id:$id, source:"chunk-section-tally"}}')"
        verified=$((verified + 1))
    done <<< "$sc_ids"
    log_info "success-criteria tallied: ${verified} distinct SC tokens"
}

# ---------- ship (branch push, journal) ----------

push_branch() {
    if [[ "$TEST_MODE" == "1" ]]; then
        emit_event branch_pushed "$(jq -nc '{data:{test_mode:true, pushed:false}}')"
        return 0
    fi
    local branch="$ACTUAL_BRANCH"
    # Fallback for recovery scenarios where the specify stage was skipped in
    # this invocation (e.g. rerunning just push against an existing branch).
    # Only accept branches containing "chunk-<id>" to avoid pushing main or an
    # unrelated branch.
    if [[ -z "$branch" ]]; then
        branch=$(git -C "$REPO_ROOT" branch --show-current)
        if [[ "$branch" != *"chunk-${CHUNK_ID}"* ]]; then
            die "ACTUAL_BRANCH unset and current branch '${branch}' does not contain chunk-${CHUNK_ID}; nothing to push"
        fi
    fi
    if ! git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/${branch}"; then
        die "expected branch ${branch} to exist by now (speckit.specify should have created it); nothing to push"
    fi
    local gitea_url
    gitea_url="$(git -C "$REPO_ROOT" config --get remote.origin.url | sed -E 's|^ssh://git@|https://|; s|:[0-9]+/|/|; s|\.git$||')/compare/main...${branch}"
    if ! git -C "$REPO_ROOT" push -u origin "$branch" 2>&1; then
        die "git push failed for $branch"
    fi
    emit_event branch_pushed "$(jq -nc --arg b "$branch" --arg u "$gitea_url" '{data:{branch:$b, compare_url:$u}}')"
    # Journal the push as an ops:mut bead.
    bd create \
        --title "chunk-runner: pushed ${branch} to Gitea origin; ready for merge review (compare: ${gitea_url})" \
        --type task \
        --priority 4 \
        --labels "ops:mut,chunk-runner" \
        >/dev/null 2>&1 || true
    BEAD_MUTATIONS=$((BEAD_MUTATIONS + 1))
}

# ---------- retro (output bead = ops:retro) ----------

emit_retro() {
    local start_epoch end_epoch duration_s
    start_epoch=$(date -d "$RUN_START_TS" +%s)
    end_epoch=$(date -u +%s)
    duration_s=$((end_epoch - start_epoch))
    local total_stages=${#SELECTED_STAGES[@]}
    local signal="positive"
    if [[ "$STAGES_COMPLETED" -lt "$total_stages" ]]; then
        signal="negative"
    fi
    local retro_body="## Metrics
Duration: ${duration_s}s | Stages completed: ${STAGES_COMPLETED}/${total_stages} | Branches pushed: 1 | Bead mutations: ${BEAD_MUTATIONS}

## What Worked
- Pipeline ran end-to-end (${SPEC_SLUG} Chunk ${CHUNK_ID})

## What Surprised
- (autonomous run — human reviewer add observations here)

## What Could Improve
- Rote: (candidates from JSONL log)
- Friction: (candidates from JSONL log)
- Human-Load-Bearing: (review and promote to chunking-doc plan-stage decisions)

## Signal
${signal} -- autonomous chunk-runner v0.2 run ${RUN_ID:0:8}
"
    local retro_bead=""
    if [[ "$TEST_MODE" != "1" ]]; then
        retro_bead=$(bd create \
            --title "Retro: ${SPEC_SLUG} Chunk ${CHUNK_ID} run ${RUN_ID:0:8} -- ${signal}" \
            --description "$retro_body" \
            --type task \
            --priority 4 \
            --labels "ops:retro,chunk-runner" \
            2>&1 | grep -oE "$BEAD_ID_REGEX" | head -1 || true)
        BEAD_MUTATIONS=$((BEAD_MUTATIONS + 1))
    else
        retro_bead="${BEAD_PREFIX}-testRETRO"
    fi
    emit_event retro_emitted "$(jq -nc --arg r "$retro_bead" --arg s "$signal" '{data:{retro_bead:$r, signal:$s}}')"
}

# ---------- sub-bead close ----------

close_sub_bead() {
    if [[ -z "$SUB_BEAD" ]]; then
        return 0
    fi
    if [[ "$TEST_MODE" == "1" ]]; then
        echo "[TEST] would close sub-bead: $SUB_BEAD" >&2
        return 0
    fi
    log_info "closing sub-bead: $SUB_BEAD"
    local out rc=0
    out=$(bd close "$SUB_BEAD" 2>&1) || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        emit_event sub_bead_closed "$(jq -nc --arg b "$SUB_BEAD" '{data:{sub_bead:$b}}')"
        BEAD_MUTATIONS=$((BEAD_MUTATIONS + 1))
    else
        log_info "sub-bead close returned non-zero for $SUB_BEAD (non-fatal — bead may already be closed): $out"
    fi
}

# ---------- main ----------

print_help() {
    cat <<'HELP'
chunk-runner — sequential speckit-pipeline driver for chunked specs

USAGE
    run.sh [stage-selection] <chunking-doc-path> <chunk-id>
    run.sh -h | --help

    e.g.
    run.sh specs/039-task-reconciliation-to-pod/pre-spec-strategic-chunking.md 001

    # Resume after a halt at analyze
    run.sh --resume-from analyze specs/.../pre-spec-strategic-chunking.md 004

    # Run only two stages
    run.sh --stages implement,superb_verify specs/.../pre-spec-strategic-chunking.md 004

OPTIONS
    --sub-bead <bead-id>      Close this bead ID after push_branch. Passed by
                              the auto-chunk-runner from state.sub_bead. Optional;
                              if absent, sub-bead close is skipped.

STAGE SELECTION (all optional; mutually exclusive)
    --resume-from <stage>     Start at <stage>, continue to end of PIPELINE.
    --stages <s1,s2,...>      Run exactly these stages in PIPELINE order.
    --rerun <stage>           Run only <stage>; caller asserts idempotency.

    Partial runs require:
      - Feature branch <spec-slug>/chunk-<id> checked out + clean tree
      - Prior-stage artifacts present (skipped for --rerun)
    Default (no flags) is unchanged: create branch via /speckit.specify
    and traverse all 10 stages.

PIPELINE
    Runs this canonical speckit sequence for one chunk:
      specify → clarify → plan → tasks → analyze →
      superb_review → superb_tdd → implement → superb_verify → post_verify

    (superb_finish is manual, not in the auto-pipeline.) Each stage spawns a
    fresh claude -p subprocess with the per-stage prompt from prompts/.
    post_verify ticks the outbound gate checkboxes in the chunking doc and
    bumps its frontmatter version (PATCH). Idempotent: safe to --rerun.

INPUT CONTRACT
    The chunking doc is the sole declarative input — an audited
    pre-spec-strategic-chunking.md produced by docs/pre-spec-build/process.md.
    Runner parses:
      - ## Chunk <id>: <name> section       → scope + success-criteria tally
      - ## Plan-Stage Decisions … bullet    → optional pre-declared defaults
    No per-chunk manifests. No input beads. See DECISIONS.md D13.

ENVIRONMENT
    CHUNK_RUNNER_TEST=1                  Dry-run: no claude, no beads, no push.
                                         Used by test harness.
    CHUNK_RUNNER_STAGE_TIMEOUT_SEC=N     Per-stage wall-clock ceiling in seconds.
                                         Default 14400 (4h).
    CHUNK_RUNNER_STALL_MINUTES=N         Kill claude after N minutes of zero
                                         progress on CPU + stdout. Default 3.
    CHUNK_RUNNER_STALL_POLL_SEC=N        Watchdog poll interval. Default 30.
    CHUNK_RUNNER_PROMPTS_DIR=path        Override prompts directory.
    CHUNK_RUNNER_BEAD_PREFIX=name        Override bead-id prefix (default:
                                         from .beads/config.yaml issue-prefix,
                                         or basename of REPO_ROOT).
    REPO_ROOT=path                       Override repo root.

EXIT CODES
    0   pipeline completed; branch pushed; retro bead emitted
    1   runner error (unexpected — state may be inconsistent)
    2   clean halt (gate failure / stall / budget); review bead written;
        exit banner printed to stderr.

ARTIFACTS PER RUN
    tools/chunk-runner/runs/<spec-slug>-chunk-<id>-<ts>.jsonl
                                         Event audit log. Gitignored.
    tools/chunk-runner/runs/<spec-slug>-chunk-<id>-<ts>.live.json
                                         Live state. Updated every poll
                                         interval by the stall watchdog.
                                         Removed on run exit.
    feature branch 044-<slug>/chunk-<id> Created by /speckit.specify.
                                         Carries spec.md, plan.md, tasks.md,
                                         per-phase impl commits.
    review:gate-refusal bead             Written on halt. Surfaced for triage
                                         via `bd list --label review:gate-refusal`.
    ops:retro bead                       Written on complete. Feeds 036
                                         drain pipeline.
    ops:mut journal entry                Written on branch push via `bd create`.
    sub-bead close                       bd close <sub-bead-id> on complete,
                                         if --sub-bead was supplied.

MONITORING (while a run is in flight)

    # Tail the JSONL (events only at stage boundaries — quiet mid-stage)
    tail -f tools/chunk-runner/runs/<slug>-chunk-<id>-<ts>.jsonl | jq -c

    # Live state (empirical heartbeat — updated every poll_sec)
    watch -n 2 jq . tools/chunk-runner/runs/<slug>-chunk-<id>-<ts>.live.json

    # Claude subprocess CPU trend
    ps -o pid,etime,time,pcpu,state -p $(pgrep -f 'claude -p')

    # Feature branch activity
    git log --oneline 044-<slug>/chunk-<id> ^main

    # Open review beads from halted runs
    bd list --label review:gate-refusal --status open

HALT CONDITIONS
    specify        branch discipline (not on main / dirty / existing branch)
    clarify        (none — surfaces to ## Known Issues)
    plan           genuinely irresolvable decision; missing info
    tasks          task count >100; FR with no task
    analyze        CRITICAL findings only
    superb_review  TDD-readiness NOT READY; blocking Known Issues; 4+ gaps
    superb_tdd     gate failure; TDD stuck (3+ fix attempts)
    implement      regression loop; prior-chunk regression; missing evidence
    superb_verify  credential-loaded failure; bare-shell boundary violated;
                   unmapped FR/SC; infra regression
    post_verify    unexpected git error on commit (chunking-doc write)
    (runner)       pre-flight fail; per-stage timeout; stall watchdog;
                   post-specify branch mismatch

    Every halt writes a review:gate-refusal bead with itemized halt_reason.
    You triage via `bd list --label review:gate-refusal --status open` later —
    no need to be watching in the moment.

RELATED
    README       tools/chunk-runner/README.md
    Decisions    tools/chunk-runner/DECISIONS.md        (D1..D20)
    Prompts      tools/chunk-runner/prompts/README.md
    Tests        tools/chunk-runner/test/test_runner.sh
HELP
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        print_help
        # Suppress banner+TTS on help exit (trap not yet installed, but be defensive)
        trap - EXIT
        exit 0
    fi

    parse_args "$@"

    trap notify_exit EXIT

    load_chunk "$CHUNKING_DOC_ARG" "$CHUNK_ID_ARG"
    compute_selected_stages

    emit_event start "$(jq -nc --arg d "$CHUNKING_DOC" --arg t "$TEST_MODE" --argjson p "$PARTIAL_RUN" '{data:{chunking_doc:$d, test_mode:$t, partial_run:$p}}')"

    if [[ "$PARTIAL_RUN" -eq 1 ]]; then
        local mode=""
        [[ -n "$RESUME_FROM" ]] && mode="resume-from:${RESUME_FROM}"
        [[ -n "$STAGES_LIST" ]] && mode="stages:${STAGES_LIST}"
        [[ -n "$RERUN_STAGE" ]] && mode="rerun:${RERUN_STAGE}"
        local stages_json
        stages_json=$(printf '%s\n' "${SELECTED_STAGES[@]}" | jq -R . | jq -sc .)
        emit_event resume "$(jq -nc --arg m "$mode" --argjson s "$stages_json" '{data:{mode:$m, stages:$s}}')"
        if ! run_partial_preflight; then
            clean_halt pre_flight "partial-run pre-flight failed (see JSONL log)"
        fi
    else
        if ! run_preflight; then
            clean_halt pre_flight "one or more pre-flight checks failed"
        fi
    fi

    write_breadcrumb
    verify_branch_ready

    for stage in "${SELECTED_STAGES[@]}"; do
        if ! run_stage "$stage"; then
            local halt_reason
            halt_reason=$(tail -1 "$JSONL_LOG" | jq -r '.halt_reason // "stage returned non-pass"')
            clean_halt "$stage" "$halt_reason"
        fi
    done

    run_success_criteria_tally
    push_branch
    close_sub_bead
    emit_retro

    local start_epoch end_epoch duration_s
    start_epoch=$(date -d "$RUN_START_TS" +%s)
    end_epoch=$(date -u +%s)
    duration_s=$((end_epoch - start_epoch))
    emit_event complete "$(jq -nc --argjson d $((duration_s * 1000)) '{duration_ms:$d}')"
    log_info "complete: ${STAGES_COMPLETED}/${#SELECTED_STAGES[@]} stages in ${duration_s}s"
    EXIT_STATE="complete"
    EXIT_STAGE="pipeline"
    EXIT_REASON="${#SELECTED_STAGES[@]} stage(s) passed; branch pushed; retro emitted"
    exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
