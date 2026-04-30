You are running `/speckit.superb.tdd` for Chunk ${CHUNK_ID} (${CHUNK_NAME}).

## Context

- Feature dir: ${FEATURE_DIR}
- tasks.md with TDD-ordered phases

## Task

Run `/speckit.superb.tdd`. This is the mandatory pre-implement TDD gate. It:
1. Resolves the installed `test-driven-development` skill (from `.agents/skills/test-driven-development/SKILL.md` or the global path)
2. Records the baseline test count
3. Enforces RED → GREEN → REFACTOR → COMMIT for every task in tasks.md
4. Pastes RED failure + GREEN pass evidence inline per task

## Gate behavior

The command either:
- Proceeds cleanly (all tasks' RED/GREEN cycles run) — you then continue into `/speckit.implement` from the gate's context
- FAILS a specific task (e.g., production code written before test, test doesn't fail as expected)

**If the gate fails, STOP with halt_reason="superb.tdd gate failure on <task-id>: <reason>".**

## TDD-stuck escalation (038-ported)

If the same task's RED test requires 3+ fix attempts to pass, STOP with halt_reason="TDD stuck on <task-id> — 3+ failed fixes; requires /speckit.superb.debug". Do NOT attempt fix #3 without escalation.

## Baseline validation

If the baseline test count shows unexpected failures (tests that were passing on `main` before this chunk started), STOP with halt_reason="test baseline dirty: <n> tests failing on chunk branch but not expected on main".

## Note: this stage overlaps with implement

In the 038 cadence, `superb.tdd` and `implement` were often run as a paired flow. This harness runs them as separate stages because halt conditions differ:
- superb.tdd halts on gate failure (no implementation yet)
- implement halts on test regressions mid-run

That separation enables the runner to emit distinct JSONL events.

## When done

Commit the baseline + RED test evidence on the feature branch. The runner handles JSONL stage_completed events — do not write beads from within this prompt.

## Return contract

The runner parses the JSON between the === tags via `jq`. Values must be JSON-valid.

```
=== CHUNK-RUNNER RETURN ===
{
  "stage": "superb_tdd",
  "status": "pass",
  "tasks_tdd_gated": 0,
  "baseline_test_count": 0,
  "baseline_passing": 0,
  "baseline_failing": 0,
  "halt_reason": "",
  "next_stage_inputs": "<any partial TDD evidence to be continued in implement>"
}
=== END ===
```
