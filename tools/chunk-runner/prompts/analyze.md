You are running `/speckit.analyze` for Chunk ${CHUNK_ID} (${CHUNK_NAME}).

## Context

- Feature dir: ${FEATURE_DIR}
- Artifacts to analyze: spec.md, plan.md, tasks.md (+ research.md, data-model.md if present)
- Pre-spec: ${PRE_SPEC_PATH}

## Task

Run `/speckit.analyze`. It performs a cross-artifact consistency and quality review — looking for:

- Spec claims not backed by plan decisions
- Plan decisions not reflected in tasks
- Tasks with no corresponding spec requirement
- Inconsistent terminology across artifacts
- Missing non-goals
- Orphan FR/SC/EC coverage

## Finding-severity buckets

Findings are bucketed by severity: **CRITICAL**, **HIGH**, **MEDIUM**, **LOW**.

## Halt rule

Halt only on **CRITICAL** findings. Analyze's job is to surface issues; `/speckit.superb.review` is the blocking gate for TDD-readiness and has the stronger reasoning context to decide whether a HIGH finding blocks implementation.

- **CRITICAL** → STOP with `halt_reason="analyze CRITICAL finding: <one-line summary>"`. Surface all CRITICAL finding text verbatim. A CRITICAL is something that makes the artifact set structurally unusable (e.g., a requirement that cannot be tested as written, a plan decision that contradicts a chunking-doc constraint).
- **HIGH / MEDIUM / LOW** → never halt. Handle per the triage discipline below, pass findings forward.

## Triage discipline

For every **HIGH** finding:

- **If mechanical** (typo, terminology drift, explicit omission, internal inconsistency between artifacts): fix in-session. Edit the affected artifact directly, commit on the feature branch.
- **If non-mechanical** (plan-level rework, design-shape question, ambiguous contract): do NOT halt. Instead, append a `## Known Issues` section to the most affected artifact (plan.md for plan-level, tasks.md for task-level, spec.md for requirement-level) with a dated entry describing the finding. `/speckit.superb.review` will read that section when assessing TDD-readiness and decide whether it blocks.

For every **MEDIUM** finding:

- Fix in-session if mechanical and localized.
- Otherwise, defer via `next_stage_inputs` (and optionally record in `## Known Issues`).

For **LOW** findings:

- Never fix automatically. Defer via `next_stage_inputs`. `/speckit.superb.review` may pick them up.

## `## Known Issues` format

When you add entries, use this shape (one entry per finding):

```markdown
## Known Issues

- **YYYY-MM-DD analyze I<n>** (severity): <one-line summary>.
  **What** — what was observed.
  **Why non-mechanical** — why analyze did not fix it in-session.
  **Decision needed by** — `/speckit.superb.review` / `/speckit.plan` (rerun) / etc.
```

Never mutate an existing `## Known Issues` entry; append only. If an existing entry covers the same finding, increment its revision footer.

## When done

Commit any in-session fixes on the feature branch. The runner handles JSONL stage_completed events — do not write beads from within this prompt.

## Return contract

The runner parses the JSON between the === tags via `jq`. Values must be JSON-valid.

```
=== CHUNK-RUNNER RETURN ===
{
  "stage": "analyze",
  "status": "pass",
  "artifacts_touched": "<list — spec.md, plan.md, tasks.md etc. that were edited during triage>",
  "findings_critical": 0,
  "findings_high": 0,
  "findings_medium": 0,
  "findings_low": 0,
  "fixes_applied_in_session": 0,
  "known_issues_added": 0,
  "halt_reason": "",
  "next_stage_inputs": "<summary of HIGH findings passed to superb.review via Known Issues sections; plus MED/LOW deferrals>"
}
=== END ===
```

On status != pass (CRITICAL only), include the CRITICAL finding text verbatim in `halt_reason`.
