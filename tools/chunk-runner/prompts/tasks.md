You are running `/speckit.tasks` for Chunk ${CHUNK_ID} (${CHUNK_NAME}).

## Context

- Feature dir: ${FEATURE_DIR}
- Prior artifacts: ${PRIOR_ARTIFACTS}
- Chunking doc outbound-gate definition: ${CHUNKING_DOC_PATH} — §Gate surrounding Chunk ${CHUNK_ID}

## Task

Run `/speckit.tasks`. It will generate `tasks.md` — an actionable, dependency-ordered task list — from spec.md + plan.md.

## Discipline (038-ported)

### TDD ordering is mandatory

Every user story's tasks MUST be ordered:
1. Fixtures / test-data setup
2. RED tests (expected to fail)
3. Implementation
4. GREEN verification
5. Integration / cross-cutting tasks LAST

If the generator produces implementation-before-test ordering, correct in-place. This matters for `speckit.superb.tdd` downstream.

### Parallelism markers

Tasks that can run in parallel on independent files MUST carry a `[P]` marker. Tasks that share a file or have sequential data dependency MUST NOT carry `[P]`.

### Outbound-gate task

Every chunk with an outbound gate (check the chunking doc §Gate sections) MUST have a terminal task enumerating the outbound-gate evidence bundles. Naming convention from 038: "Tn: Outbound Gate <from>→<to> evidence — <bundle list>".

### Foundational-block discipline

If this chunk contributes foundational tasks consumed by prior-already-merged chunks (e.g. cross-chunk contracts updated), these MUST be Phase 1 tasks that block later phases until green.

### Task-count range guidance

- **20-35 tasks**: typical for a single-user-story chunk with tight scope.
- **35-70 tasks**: typical for a multi-story chunk with `[P]` decomposition of fixtures.
- **70-100 tasks**: typical for a large chunk with integration + cross-chunk foundational block.
- **>100 tasks**: probably over-decomposed or over-scoped — consider whether you need all of them or if the chunk should be split. If splitting is not an option at this stage, proceed but note the risk in next_stage_inputs.
- **<20 tasks**: possibly under-decomposed — confirm all FRs + SCs + ECs are covered by explicit tasks.

These ranges are heuristics from 038, not hard gates.

### Phase count

Typical 038 chunks organized tasks into 6-9 phases. Emit a phase count that corresponds to natural dependency boundaries (Phase 1 = foundational, Phase N = outbound gate). Don't invent phases for single tasks.

### Evidence-matrix task

Include a final task that emits an evidence matrix: FR → task(s) → SC → verification. The 038 pattern called this "T<final>: Evidence matrix — every FR and SC maps to concrete task output".

## Halt conditions

- Task count >100: STOP with halt_reason="tasks exceeds 100 — chunk over-scoped; requires human review"
- Any FR in spec.md has no corresponding task: STOP with halt_reason="FR-<id> has no task"

## When done

Commit tasks.md on the feature branch. The runner handles JSONL stage_completed events — do not write beads from within this prompt.

## Return contract

The runner parses the JSON between the === tags via `jq`. Values must be JSON-valid.

```
=== CHUNK-RUNNER RETURN ===
{
  "stage": "tasks",
  "status": "pass",
  "artifacts_touched": "${FEATURE_DIR}/tasks.md",
  "task_count": 0,
  "phase_count": 0,
  "parallel_markers": 0,
  "outbound_gate_task_present": true,
  "halt_reason": "",
  "next_stage_inputs": "<summary — any uncovered FRs, excess tasks, etc.>"
}
=== END ===
```
