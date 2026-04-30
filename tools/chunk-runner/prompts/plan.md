You are running `/speckit.plan` for Chunk ${CHUNK_ID} (${CHUNK_NAME}).

## Context

- Feature dir: ${FEATURE_DIR}
- Prior artifacts: ${PRIOR_ARTIFACTS}
- Pre-spec: ${PRE_SPEC_PATH}
- Chunking doc: ${CHUNKING_DOC_PATH} — §Chunk ${CHUNK_ID}

## Pre-declared plan-layer decisions (optional, from chunking doc)

Some chunking docs carry a `## Plan-Stage Decisions Across All Chunks` section with per-chunk bullets pre-declaring defaults. If this chunk has one, it appears below — use the bullet as the authoritative default for any decision it names. An empty block is normal: `docs/pre-spec-build/process.md` does not require pre-declaration. `/speckit.plan`'s job is to resolve plan-layer decisions in context.

```markdown
${PLAN_DECISIONS_MD}
```

## Task

Run `/speckit.plan`. It will:

1. Read spec.md (+ Clarifications section)
2. Identify plan-layer decisions surfaced during specify/clarify
3. Generate `plan.md`, `research.md`, `data-model.md`, `quickstart.md`, and `contracts/*` as appropriate for the chunk
4. Record resolved decisions in a `## Plan-Stage Decisions` section of plan.md

## Decision-resolution order

For each decision surfaced:

1. **Pre-declared default** (if the chunking-doc bullet above names it) — use it; record rationale as "Per chunking doc § Plan-Stage Decisions."
2. **Precedent from prior merged chunks** — grep `specs/*/plan.md` for similar decisions; follow established conventions.
3. **Pre-spec constraint** — does any option violate a constraint or non-goal in the pre-spec?
4. **Narrower / more-testable / more-conservative** — when no precedent or constraint applies.

Record every resolved decision in plan.md with option chosen + one-line rationale.

## Halt conditions

STOP only on genuine blockers — not on decision volume:

- A surfaced decision has multiple viable options with material, non-reversible trade-offs AND no precedent, constraint, or pre-declared default discriminates between them. Halt with halt_reason naming the decision and the viable options.
- A surfaced decision requires information not present in spec.md, pre-spec, or merged-chunk artifacts (e.g., an external system contract that hasn't been authored). Halt with halt_reason naming what's missing.

Decision count alone is not a halt trigger. A chunk with 8 straightforward decisions resolved from precedent + constraint is healthier than a chunk with 1 decision that requires invention.

## Artifact check

After plan.md is written, verify it declares:

- `## Artifacts Created` — list of new files
- `## Artifacts Updated` — list of files that will be edited
- `## Plan-Stage Decisions` — one heading per resolved decision, with option chosen + rationale
- `## Non-goals` — anything out of scope

If any section is missing from plan.md, rerun with an explicit ask for the missing section.

## When done

Commit plan artifacts on the feature branch. The runner handles JSONL stage_completed events — do not write beads from within this prompt.

## Return contract

The runner parses the JSON between the === tags via `jq`. Values must be JSON-valid.

```
=== CHUNK-RUNNER RETURN ===
{
  "stage": "plan",
  "status": "pass",
  "artifacts_touched": "<comma-separated — typically plan.md, research.md, data-model.md, quickstart.md, contracts/*>",
  "decisions_resolved": 0,
  "halt_reason": "",
  "next_stage_inputs": "<summary of resolved decisions + any scope notes for tasks>"
}
=== END ===
```
