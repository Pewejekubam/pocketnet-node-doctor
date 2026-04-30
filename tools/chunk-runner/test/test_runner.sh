#!/usr/bin/env bash
# chunk-runner test harness — dry-run validation against a synthetic chunking doc.
#
# Creates a throwaway pre-spec-strategic-chunking.md in a tmp dir, runs run.sh
# with CHUNK_RUNNER_TEST=1, asserts JSONL events emitted in expected order,
# cleans up. No real beads mutated, no claude spawned.
#
# Usage:
#   tools/chunk-runner/test/test_runner.sh
#
# Exit:
#   0 — all assertions passed
#   1 — one or more assertions failed

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RUN_SH="${REPO_ROOT}/tools/chunk-runner/run.sh"

PASS=0
FAIL=0
FIXTURES_DIR=""
CLEANUP_RUNS=()

cleanup() {
    [[ -n "$FIXTURES_DIR" && -d "$FIXTURES_DIR" ]] && rm -rf "$FIXTURES_DIR"
    for f in "${CLEANUP_RUNS[@]}"; do
        [[ -f "$f" ]] && rm -f "$f"
    done
}
trap cleanup EXIT

assert() {
    local descr="$1" actual="$2" expected="$3"
    if [[ "$actual" == "$expected" ]]; then
        PASS=$((PASS + 1))
        echo "PASS  $descr"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL  $descr"
        echo "      expected: $expected"
        echo "      actual:   $actual"
    fi
}

assert_contains() {
    local descr="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        PASS=$((PASS + 1))
        echo "PASS  $descr"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL  $descr"
        echo "      searched for: $needle"
        echo "      in:           ${haystack:0:200}..."
    fi
}

# ----- fixture builder -----

build_fixture() {
    FIXTURES_DIR=$(mktemp -d /tmp/chunk-runner-fixture.XXXXXX)
    # Mimic the chunking-doc structure: frontmatter + Progress Tracker +
    # Plan-Stage Decisions + per-chunk ## Chunk <id> sections
    cat > "${FIXTURES_DIR}/pre-spec-strategic-chunking.md" <<'MD'
---
version: 0.1.0
status: draft
created: 2026-04-20
last_modified: 2026-04-20
authors: [fixture]
related: pre-spec.md
---

# Fixture Chunking Doc

This is a synthetic chunking doc for chunk-runner dry-run tests.

## Progress Tracker

| Chunk | Title | Status | Feature Dir | Branch | Gate |
|-------|-------|--------|-------------|--------|------|
| TEST | Synthetic fixture chunk | pending | _(TBD)_ | _(TBD)_ | none |

## Plan-Stage Decisions Across All Chunks

- **Chunk TEST**: D1 = A (fixture default); D2 = B (fixture default). No runtime resolution needed.

## Chunk TEST: Synthetic fixture chunk

### Scope

Exercises chunk-runner mechanics against a throwaway chunking doc.

### Success Criteria

- SC-fixture-1: Runner parses the chunking doc and emits start event.
- SC-fixture-2: Runner traverses all 9 pipeline stages in test mode.

### Post-Implementation Verification

- [ ] JSONL log written
- [ ] No real bead writes in test mode

## Session Breadcrumbs

### Chunk TEST

- **Status:** pending
- **Next action:** run this fixture
MD
    # Also create a stub pre-spec.md so ${PRE_SPEC_PATH} references resolve
    cat > "${FIXTURES_DIR}/pre-spec.md" <<'MD'
---
version: 0.1.0
status: draft
---
# Fixture Pre-Spec
Synthetic stub for chunk-runner fixture tests.
MD
    echo "$FIXTURES_DIR"
}

# ----- Test cases -----

test_happy_path() {
    echo "--- test: happy-path fixture with all stages pass ---"
    local fixture
    fixture=$(build_fixture)
    local doc="${fixture}/pre-spec-strategic-chunking.md"

    local exit_code=0
    CHUNK_RUNNER_TEST=1 "$RUN_SH" "$doc" TEST > /tmp/cr-test-stdout 2> /tmp/cr-test-stderr || exit_code=$?

    assert "exit code == 0 (happy path)" "$exit_code" "0"

    local spec_slug
    spec_slug="$(basename "$fixture")"
    local log_file
    log_file=$(ls -t "${REPO_ROOT}/tools/chunk-runner/runs/${spec_slug}-chunk-TEST-"*.jsonl 2>/dev/null | head -1)
    if [[ -z "$log_file" ]]; then
        FAIL=$((FAIL + 1))
        echo "FAIL  JSONL log file exists (looked for ${spec_slug}-chunk-TEST-*.jsonl)"
        return
    fi
    CLEANUP_RUNS+=("$log_file")
    PASS=$((PASS + 1))
    echo "PASS  JSONL log file exists ($(basename "$log_file"))"

    local events
    events=$(jq -r '.event' "$log_file" | tr '\n' ',')

    assert_contains "start event first" "$events" "start,"
    assert_contains "pre_flight_check events" "$events" "pre_flight_check,"
    assert_contains "branch_ready event" "$events" "branch_ready,"
    assert_contains "stage_started event" "$events" "stage_started,"
    assert_contains "stage_completed event" "$events" "stage_completed,"
    assert_contains "sc_verified event" "$events" "sc_verified,"
    assert_contains "branch_pushed event" "$events" "branch_pushed,"
    assert_contains "retro_emitted event" "$events" "retro_emitted,"
    assert_contains "complete event last" "$events" ",complete,"

    # Count stage events — 10 stages in the canonical pipeline
    local started completed
    started=$(jq -c 'select(.event == "stage_started")' "$log_file" | wc -l)
    completed=$(jq -c 'select(.event == "stage_completed")' "$log_file" | wc -l)
    assert "10 stage_started events (canonical pipeline)" "$started" "10"
    assert "10 stage_completed events" "$completed" "10"

    # chunk_id populated correctly
    local chunk_id_seen
    chunk_id_seen=$(jq -r '.chunk_id' "$log_file" | sort -u | head -1)
    assert "chunk_id = TEST in all events" "$chunk_id_seen" "TEST"

    # spec_slug populated
    local slug_seen
    slug_seen=$(jq -r '.spec_slug' "$log_file" | sort -u | head -1)
    assert "spec_slug matches fixture dir" "$slug_seen" "$spec_slug"
}

test_missing_chunk_id() {
    echo "--- test: nonexistent chunk id exits 1 ---"
    local fixture
    fixture=$(build_fixture)
    local doc="${fixture}/pre-spec-strategic-chunking.md"

    local exit_code=0
    CHUNK_RUNNER_TEST=1 "$RUN_SH" "$doc" NONEXISTENT > /dev/null 2>&1 || exit_code=$?
    assert "nonexistent chunk id exits 1 (die)" "$exit_code" "1"
}

test_missing_chunking_doc() {
    echo "--- test: missing chunking doc exits 1 ---"
    local exit_code=0
    CHUNK_RUNNER_TEST=1 "$RUN_SH" /tmp/does-not-exist-$$.md TEST > /dev/null 2>&1 || exit_code=$?
    assert "missing chunking doc exits 1" "$exit_code" "1"
}

test_dispatch_picks_pending() {
    echo "--- test: dispatch.sh finds first pending chunk ---"
    local fixture
    fixture=$(build_fixture)
    local doc="${fixture}/pre-spec-strategic-chunking.md"

    # dispatch.sh with this fixture should pick "TEST" (only pending row)
    local picked
    picked=$(awk '
        /^## Progress Tracker/ { in_tbl = 1; next }
        in_tbl && /^## / { exit }
        in_tbl && /^\|/ {
            n = split($0, cells, "|")
            if (n < 4) next
            id = cells[2]; status = cells[4]
            gsub(/^[ \t]+|[ \t]+$/, "", id); gsub(/^[ \t]+|[ \t]+$/, "", status)
            if (id == "Chunk" || id == "" || id ~ /^-+$/) next
            if (status == "pending") { print id; exit }
        }
    ' "$doc")
    assert "dispatch parser picks TEST" "$picked" "TEST"
}

test_resume_from_analyze() {
    echo "--- test: --resume-from analyze runs 5 stages with resume event ---"
    local fixture
    fixture=$(build_fixture)
    local doc="${fixture}/pre-spec-strategic-chunking.md"

    # TEST mode bypasses the branch-exists / working-tree checks so this
    # doesn't need a real feature branch. The artifact check is real —
    # create the three files --resume-from analyze expects.
    : > "${fixture}/spec.md"
    : > "${fixture}/plan.md"
    : > "${fixture}/tasks.md"

    local exit_code=0
    CHUNK_RUNNER_TEST=1 "$RUN_SH" --resume-from analyze "$doc" TEST > /tmp/cr-resume-stdout 2> /tmp/cr-resume-stderr || exit_code=$?

    assert "resume exit code == 0" "$exit_code" "0"

    local spec_slug
    spec_slug="$(basename "$fixture")"
    local log_file
    log_file=$(ls -t "${REPO_ROOT}/tools/chunk-runner/runs/${spec_slug}-chunk-TEST-"*.jsonl 2>/dev/null | head -1)
    [[ -n "$log_file" ]] && CLEANUP_RUNS+=("$log_file")

    local events
    events=$(jq -r '.event' "$log_file" | tr '\n' ',')
    assert_contains "resume event present" "$events" ",resume,"

    # Exactly six stage_started events for analyze..post_verify
    local started
    started=$(jq -c 'select(.event == "stage_started")' "$log_file" | wc -l)
    assert "6 stage_started events on resume" "$started" "6"

    local first_stage
    first_stage=$(jq -r 'select(.event == "stage_started") | .stage' "$log_file" | head -1)
    assert "first started stage is analyze" "$first_stage" "analyze"
}

test_stages_subset() {
    echo "--- test: --stages implement,superb_verify runs exactly 2 stages ---"
    local fixture
    fixture=$(build_fixture)
    local doc="${fixture}/pre-spec-strategic-chunking.md"
    : > "${fixture}/spec.md"; : > "${fixture}/plan.md"; : > "${fixture}/tasks.md"

    local exit_code=0
    CHUNK_RUNNER_TEST=1 "$RUN_SH" --stages implement,superb_verify "$doc" TEST > /dev/null 2> /tmp/cr-subset-stderr || exit_code=$?
    assert "stages-subset exit code == 0" "$exit_code" "0"

    local spec_slug
    spec_slug="$(basename "$fixture")"
    local log_file
    log_file=$(ls -t "${REPO_ROOT}/tools/chunk-runner/runs/${spec_slug}-chunk-TEST-"*.jsonl 2>/dev/null | head -1)
    [[ -n "$log_file" ]] && CLEANUP_RUNS+=("$log_file")

    local started
    started=$(jq -c 'select(.event == "stage_started")' "$log_file" | wc -l)
    assert "2 stage_started events on subset" "$started" "2"
}

test_resume_artifact_missing_halts() {
    echo "--- test: --resume-from analyze with missing tasks.md halts ---"
    local fixture
    fixture=$(build_fixture)
    local doc="${fixture}/pre-spec-strategic-chunking.md"
    # Intentionally NOT creating tasks.md
    : > "${fixture}/spec.md"; : > "${fixture}/plan.md"

    local exit_code=0
    CHUNK_RUNNER_TEST=1 "$RUN_SH" --resume-from analyze "$doc" TEST > /dev/null 2>&1 || exit_code=$?
    assert "missing-artifact halt exits 2" "$exit_code" "2"

    local spec_slug
    spec_slug="$(basename "$fixture")"
    local log_file
    log_file=$(ls -t "${REPO_ROOT}/tools/chunk-runner/runs/${spec_slug}-chunk-TEST-"*.jsonl 2>/dev/null | head -1)
    [[ -n "$log_file" ]] && CLEANUP_RUNS+=("$log_file")
    local failed_check
    failed_check=$(jq -c 'select(.event == "pre_flight_check" and .status == "fail")' "$log_file" | head -1)
    assert_contains "pre_flight_check fail mentions tasks.md" "$failed_check" "tasks.md"
}

# ----- Main -----

echo "chunk-runner dry-run test harness (v0.2)"
echo "=========================================="

test_happy_path
test_missing_chunk_id
test_missing_chunking_doc
test_dispatch_picks_pending
test_resume_from_analyze
test_stages_subset
test_resume_artifact_missing_halts

echo "=========================================="
echo "Results: $PASS pass, $FAIL fail"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
exit 0
