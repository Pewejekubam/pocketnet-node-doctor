You are running `/speckit.superb.review` for Chunk ${CHUNK_ID} (${CHUNK_NAME}).

## Context

- Feature dir: ${FEATURE_DIR}
- Analyze findings deferred from prior stage: see the analyze stage's `next_stage_inputs` return-block field in the JSONL log AND any `## Known Issues` sections `/speckit.analyze` appended to spec.md / plan.md / tasks.md

## This stage is the blocking gate

You are the strongest-reasoning layer in the pipeline before implementation. `/speckit.analyze` surfaces findings but only halts on CRITICAL; every HIGH finding it couldn't fix mechanically is either in a `## Known Issues` section of the relevant artifact or noted in its `next_stage_inputs`. Your job is to read those, assess them against the spec/plan/tasks, and make the real TDD-readiness call.

When you halt, be specific: name each blocking finding verbatim. A human reviewer reads your halt reason from a `review:gate-refusal` bead later — the better the halt_reason, the faster the triage.

## Task

Run `/speckit.superb.review`. It produces:
1. **Spec-coverage matrix** — every FR, SC, EC mapped to one or more tasks
2. **Task-quality report** — naming, phase ordering, [P] marker correctness, outbound-gate task presence
3. **Known-Issues review** — consume every `## Known Issues` entry from /speckit.analyze; classify each as blocking (halt), acknowledge (proceed but cite), or resolved-in-session (fix + remove entry)
4. **TDD-readiness assessment** — can `speckit.superb.tdd` run against this task set without gaps?

## Gate behavior

The command returns one of:
- `TDD-readiness: READY` — proceed to /speckit.superb.tdd
- `TDD-readiness: NOT READY — <reasons>` — halt

**If NOT READY, STOP with halt_reason="superb.review gate: TDD not ready — <reasons>".**

## Partial-coverage discipline (038-ported)

Some FRs/SCs have "partial" coverage — mapped to a task but the task's verification is weaker than the FR's assertion. The 038 convention:

- If a partial-coverage flag blocks TDD readiness: fix the affected task to tighten its verification, re-run review.
- If a partial-coverage flag is acknowledged non-blocking (e.g., FR covered structurally + behaviorally by adjacent tasks): record in plan.md's `## Known Coverage Gaps` and proceed. Cite the adjacent-task justification explicitly.

Do NOT silently accept partials. Every partial gets an acknowledgment line.

## Coverage-gap threshold

- 0 gaps: proceed clean
- 1-3 gaps, all mechanical: fix or acknowledge + proceed
- 4+ gaps OR any gap with a behavioral assertion: STOP with halt_reason="spec coverage below threshold — <n> gaps: <enumerate>"

## Known-Issues handling

For each `## Known Issues` entry produced by /speckit.analyze:

- **If resolvable in-session** (you can make the decision the analyze stage couldn't, e.g., picking between two equally-reasonable plan options given full context): resolve it. Edit the affected artifact, remove the Known Issues entry, note the resolution in `next_stage_inputs`.
- **If blocking** (no viable way to proceed with TDD without a plan-level decision that requires human input, or an unresolvable spec↔plan↔tasks inconsistency): halt. `halt_reason` MUST itemize each blocking issue by ID + one-line summary of why it blocks.
- **If acknowledge-and-proceed** (known limitation but implementation is still well-defined; e.g., a deferred-to-future-chunk decision): leave the entry in place, cite in `next_stage_inputs`. Implementation proceeds with the limitation documented.

Never silently ignore a `## Known Issues` entry. Every entry gets a decision recorded here.

## When done

Commit any coverage-gap fixes on the feature branch. The runner handles JSONL stage_completed events — do not write beads from within this prompt.

## Return contract

The runner parses the JSON between the === tags via `jq`. Values must be JSON-valid.

```
=== CHUNK-RUNNER RETURN ===
{
  "stage": "superb_review",
  "status": "pass",
  "artifacts_touched": "<any spec/plan/tasks fix edits>",
  "coverage_gaps_total": 0,
  "coverage_gaps_fixed": 0,
  "coverage_gaps_acknowledged": 0,
  "known_issues_resolved": 0,
  "known_issues_acknowledged": 0,
  "known_issues_blocking": 0,
  "tdd_readiness": "READY",
  "halt_reason": "",
  "next_stage_inputs": "<gap acknowledgments + known-issues decisions + any partials to watch during tdd>"
}
=== END ===
```
