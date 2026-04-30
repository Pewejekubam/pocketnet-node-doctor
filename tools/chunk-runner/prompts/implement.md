You are running `/speckit.implement` for Chunk ${CHUNK_ID} (${CHUNK_NAME}).

## Context

- Feature dir: ${FEATURE_DIR}
- tasks.md with TDD-ordered phases (RED tests already demonstrated by /speckit.superb.tdd)
- Plan decisions: see `${FEATURE_DIR}/plan.md § Plan-Stage Decisions`

## Task

Run `/speckit.implement`. It executes tasks.md phase by phase:
1. Write the minimum code to turn RED → GREEN
2. Run the full test suite after each task (no regressions)
3. Commit green state per task or per logical group
4. Apply REFACTOR where the task calls for it (no behavior change)

## Credential-loaded test discipline (038-ported)

The PAM host has two test modes:
- **Credential-loaded** — env vars like `PAM_SUBSTRATE_PG_PASSWORD` are present. External integrations reachable. Tests that require the store / RingCentral API / Google API / etc. run.
- **Bare-shell** — credentials absent. Autonomy-denial boundary tests run (every write tool SHOULD fail with a credential-absence error).

This stage runs in **credential-loaded** mode. The expectation is that ALL tests the chunk introduces run and PASS. Any test that requires credentials but won't run here — STOP with halt_reason="credential-loaded test cannot run: <test-name> — missing <env-var>".

Bare-shell boundary-proof runs are the `/speckit.superb.verify` stage's concern.

## Regression discipline

After EVERY task completion, run the full test suite. If any previously-passing test fails:

1. **First failure within a task**: debug the introduced code; do NOT skip the task. Fix within 2 attempts.
2. **Second failure on the same task**: STOP with halt_reason="regression loop on <task-id> after 2 attempts — requires /speckit.superb.debug".
3. **Failure appears in a prior-chunk test**: STOP with halt_reason="regression in previously-merged chunk: <test-name>" — this means the new chunk's changes break an earlier contract.

## Phase-boundary commits

At each phase boundary, create a git commit with message format:
```
feat(NNN): Chunk ${CHUNK_ID} Phase <p> — <short summary> (T<task-range>)
```

This matches the 038 commit cadence (e.g., `feat(043): Chunk 3 Phase 5+6+7 — US3 cache writer + US4 hook + US5 SC-007 (T029-T048)`).

## Outbound-gate task

The last task (or phase) should be the outbound-gate evidence-aggregation task — produces the evidence bundle that `/speckit.superb.verify` will then validate against. If the outbound-gate task's evidence bundle fails to assemble, STOP with halt_reason="outbound-gate evidence cannot be assembled: <what's missing>".

## When done

Spec status flip: the /speckit.implement command synchronizes the spec status to `Implementing`. Upon completion of all tasks, manually flip to `Implemented`.

Commit per-phase on the feature branch. The runner handles JSONL stage_completed events — do not write beads from within this prompt.

## Return contract

The runner parses the JSON between the === tags via `jq`. Values must be JSON-valid.

```
=== CHUNK-RUNNER RETURN ===
{
  "stage": "implement",
  "status": "pass",
  "artifacts_touched": "<comma-separated — all files created or modified across phases>",
  "tasks_completed": 0,
  "tasks_total": 0,
  "test_count_after": 0,
  "test_passing": 0,
  "test_failing": 0,
  "phase_commits": 0,
  "halt_reason": "",
  "next_stage_inputs": "<evidence bundle summary for superb.verify>"
}
=== END ===
```
