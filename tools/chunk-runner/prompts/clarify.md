You are running `/speckit.clarify` for Chunk ${CHUNK_ID} (${CHUNK_NAME}).

## Context

- Feature dir: ${FEATURE_DIR}
- Spec already written: ${FEATURE_DIR}/spec.md
- Prior artifacts: ${PRIOR_ARTIFACTS}
- Pre-spec (scope authority): ${PRE_SPEC_PATH}
- Chunking doc: ${CHUNKING_DOC_PATH} — §Chunk ${CHUNK_ID}

## Task

Run `/speckit.clarify`. The command will:
1. Scan spec.md for underspecified areas
2. Ask up to 5 highly targeted clarification questions
3. Record each Q/A pair into a `## Clarifications` section in spec.md
4. Tighten affected FRs / SCs / ECs in-place

## Autonomous resolution discipline (038-ported)

You are running without a human orchestrator. Answer your own questions using this order of priority:

1. **Pre-spec text.** If the pre-spec answers the question explicitly or by strong implication, cite the passage and use it.
2. **Chunking doc text.** Same treatment for the `§Chunk ${CHUNK_ID}` section — including any `### Speckit Stop Resolutions` subsection within it.
3. **Established pattern in merged chunks.** If prior merged chunks (check `git log --oneline | head -40`) established a convention, follow it.
4. **Defensive default.** If none of the above applies, pick the narrower / more-testable / more-conservative option and mark the Q/A with a `Defensive default — revisit at /speckit.plan` note.

## Defer plan-layer decisions

Any answer that requires choosing a mechanism (library, data shape, retry strategy, etc.) is a plan-layer decision — do NOT resolve it here. Record the question as answered with "Deferred to /speckit.plan — see plan-layer decision D<N>: <subject>" and leave the resolution for the plan stage.

## No halts here — surface, don't block

Clarify is a question-asking stage. `/speckit.superb.review` is the blocking gate with the strongest reasoning context. Clarify's job is to resolve what it can autonomously and surface what it can't; never halt autonomously on ambiguity or volume.

For any question you cannot answer from pre-spec + chunking doc + prior merged chunks AND where a defensive default would substantively change the chunk's scope: do NOT halt. Instead, append a `## Known Issues` section to spec.md with an entry describing the unresolved question. `/speckit.superb.review` will read that section when assessing TDD-readiness and decide whether it blocks.

Entry format (one per unresolved question):

```markdown
## Known Issues

- **YYYY-MM-DD clarify I<n>** (scope|contract|ambiguity): <one-line summary of the question>.
  **What** — what spec.md passage is underspecified.
  **Why autonomous-unresolvable** — why the priority ladder didn't yield a non-scope-changing answer.
  **Decision needed by** — `/speckit.superb.review` / `/speckit.plan` / human review at a specific stage.
```

If the chunk surfaces many unresolvable questions (>5 in a single run), that's itself a signal the pre-spec / chunking doc is under-scoped. Record that observation in `next_stage_inputs` verbatim so superb.review and any review bead can cite it — but do not halt here.

## When done

Commit the spec.md edits on the feature branch. The runner handles JSONL stage_completed events + progress notes — do not write beads from within this prompt.

## Return contract

The runner parses the JSON between the === tags via `jq`. Values must be JSON-valid.

```
=== CHUNK-RUNNER RETURN ===
{
  "stage": "clarify",
  "status": "pass",
  "artifacts_touched": "${FEATURE_DIR}/spec.md",
  "questions_resolved": 0,
  "plan_layer_deferrals": 0,
  "known_issues_added": 0,
  "halt_reason": "",
  "next_stage_inputs": "<summary of deferrals + any scope notes + unresolved-question observation if >5>"
}
=== END ===
```
