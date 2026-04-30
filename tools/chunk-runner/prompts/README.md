# chunk-runner Prompt Templates

Per-speckit-stage prompt bodies. The runner (`tools/chunk-runner/run.sh`) loads
these and substitutes `${VAR}` placeholders before spawning `claude -p "<rendered prompt>"`.

## Variables

All supplied by the runner at render time. Strings unless noted.

| Variable | Source | Example |
|---|---|---|
| `${CHUNK_ID}` | CLI arg | `"001"`, `"003a"`, `"1b"` |
| `${CHUNK_NAME}` | parsed from `## Chunk <id>: <name>` heading | `"Channel reader interface + existing-tool refactors"` |
| `${CHUNK_SECTION}` | the full markdown block under `## Chunk <id>` through next `## ` | multi-line markdown blob |
| `${PLAN_DECISIONS_MD}` | parsed from `## Plan-Stage Decisions Across All Chunks § Chunk <id>` bullet | multi-line markdown |
| `${FEATURE_DIR}` | derived — dirname of chunking doc | `"specs/039-task-reconciliation-to-pod"` |
| `${BRANCH}` | conventional — `<spec-slug>/chunk-<id>` | `"039-task-reconciliation-to-pod/chunk-001"` |
| `${SHORT_NAME}` | conventional — `<spec-slug>-chunk-<id>` | `"039-task-reconciliation-to-pod-chunk-001"` |
| `${PRIOR_ARTIFACTS}` | computed from stage position in pipeline | `"spec.md, plan.md, tasks.md"` |
| `${CHUNKING_DOC_PATH}` | CLI arg (relative to repo root) | `"specs/039-task-reconciliation-to-pod/pre-spec-strategic-chunking.md"` |
| `${PRE_SPEC_PATH}` | conventional — sibling of chunking doc | `"specs/039-task-reconciliation-to-pod/pre-spec.md"` |
| `${SPEC_SLUG}` | basename of feature spec dir | `"039-task-reconciliation-to-pod"` |
| `${RUN_ID}` | UUID for the run | `"01JAB0XYZ..."` |

## Substitution

Runner uses `envsubst '$VAR1 $VAR2 …'` with an explicit allowlist (not naked
`envsubst`, which would expand `$` inside code fences). Variables MUST appear
in templates as `${VAR}` (brace form); bare `$VAR` is NOT expanded.

## Return contract

Each prompt ends by asking Claude to print a tagged final block containing a single JSON object:

```
=== CHUNK-RUNNER RETURN ===
{
  "stage": "<stage-name>",
  "status": "pass",
  "artifacts_touched": "<comma-separated relative paths>",
  "halt_reason": "",
  "next_stage_inputs": "<free-form notes for downstream stage>"
}
=== END ===
```

The runner extracts the content between the === tags and parses it with `jq`.
Values must be JSON-valid: strings quoted, numbers unquoted, no trailing commas.
`"status"` is one of `"pass"`, `"halt"`, `"error"` — anything other than `pass`
triggers a clean halt and requires a non-empty `halt_reason`.

Important: templates may contain example return blocks inside their instruction
text. The runner intentionally captures only the LAST `=== CHUNK-RUNNER RETURN
=== ... === END ===` block in the claude output — so the example inside the
prompt doesn't get mistaken for the real return.

## Pipeline

Templates exist for the canonical speckit pipeline per
`docs/pre-spec-build/process.md` Stage 7 (chunked path):

1. `specify.md`    — kickoff; creates branch via `create-new-feature.sh`
2. `clarify.md`    — ≤5 Qs; autonomous-resolution priority ladder
3. `plan.md`       — consumes `${PLAN_DECISIONS_MD}` as pre-declared defaults
4. `tasks.md`      — TDD ordering; [P] markers; outbound-gate task
5. `analyze.md`    — CRITICAL halts; HIGH fixed in-session; MED triage
6. `superb-review.md` — coverage matrix; TDD-readiness gate
7. `superb-tdd.md` — RED/GREEN/REFACTOR; 3-fix stuck escalation
8. `implement.md`  — credential-loaded regression discipline; phase commits
9. `superb-verify.md` — credential-loaded + bare-shell I-4 boundary pair

`superb-finish.md` is provided for manual invocation after human review —
it is NOT part of the runner's auto-pipeline.

## Bead writes from prompts — DO NOT

Templates should not contain `bd update` / `bd create` commands. The runner
handles all per-stage state writes (JSONL events, stage_completed bead notes,
retro bead at completion, review:gate-refusal on halt). Keeping bead writes
out of prompts means the templates stay reusable across specs that use
different bead structures (or no beads at all).
