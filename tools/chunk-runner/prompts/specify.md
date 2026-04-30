You are kicking off Chunk ${CHUNK_ID} (${CHUNK_NAME}) from ${SPEC_SLUG}.

## Context

- Chunking doc (authoritative scoping + SC + plan-stage decisions): ${CHUNKING_DOC_PATH} — see §Chunk ${CHUNK_ID}
- Pre-spec (source of truth for US/FR/SC): ${PRE_SPEC_PATH}
- Target branch: ${BRANCH} (will be created by `create-new-feature.sh` during /speckit.specify)
- Short name for feature dir: ${SHORT_NAME}
- Run id: ${RUN_ID}

## This chunk's section (verbatim from the chunking doc)

${CHUNK_SECTION}

## Task

Run `/speckit.specify` with a feature description that references the chunk by name + chunking doc + pre-spec. The `/speckit.specify` implementation will:

1. Invoke `.specify/scripts/bash/create-new-feature.sh` which creates `specs/<NNN>-${SHORT_NAME}/` and the feature branch
2. Write `spec.md` against the feature spec template, with §Chunk ${CHUNK_ID} scope narrowed from the chunking doc above
3. Write a requirements checklist

## Discipline (ported from 038's cadence)

- **Defer plan-layer decisions.** Any decision about HOW to implement (library choice, data-structure shape, tiebreaker rules, retry policy, etc.) belongs in `/speckit.plan`, not here. If the spec template tempts you to pick a mechanism, DO NOT pick it — record the decision surface as a plan-layer deferral and name it in the spec body so `/speckit.plan` can resolve it.
- **Name plan-layer deferrals explicitly.** Every deferral gets a short line like "Plan-layer decision: <one-line subject>".
- **Chunking doc + pre-spec are the sole scope sources.** Do not add scope beyond what §Chunk ${CHUNK_ID} names. Do not subtract scope it requires. For US/FR/SC text, follow references back to the pre-spec.
- **Requirements checklist must enumerate every FR/SC/EC the chunking doc lists for this chunk.** No silent omissions.

## Branch discipline

Verify at start: `git branch --show-current` must equal `main`, and `git status` must be clean. If not, STOP with halt_reason="not on main or working tree dirty".

## Return contract

End your response with exactly this block (the runner parses the JSON between the === tags via `jq`; values must be JSON-valid — strings quoted, numbers unquoted, no trailing commas):

```
=== CHUNK-RUNNER RETURN ===
{
  "stage": "specify",
  "status": "pass",
  "artifacts_touched": "<comma-separated paths — e.g. specs/NNN-${SHORT_NAME}/spec.md, specs/NNN-${SHORT_NAME}/checklists/requirements.md>",
  "feature_dir": "specs/NNN-${SHORT_NAME}",
  "plan_layer_deferrals": 0,
  "halt_reason": "",
  "next_stage_inputs": "<deferrals + any pre-filter notes for clarify>"
}
=== END ===
```

Use `"status": "halt"` or `"status": "error"` with a non-empty `halt_reason` when anything goes wrong.

If /speckit.specify fails to run, return status=halt with halt_reason describing what broke (missing script, dirty tree, existing branch, etc.).
