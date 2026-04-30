---
version: 0.1.0
status: draft
created: 2026-04-30
last_modified: 2026-04-30
authors: [pewejekubam, claude]
related: ../tasks.md
changelog:
  - version: 0.1.0
    date: 2026-04-30
    summary: Initial TDD gate baseline for Chunk 001 (`/speckit.superb.tdd`)
    changes:
      - "Record skill resolution, baseline test count, and TDD-ordering verification of tasks.md"
---

# TDD Gate Baseline — Chunk 001

This file is the baseline evidence captured by `/speckit.superb.tdd` before
`/speckit.implement` runs. It records the state of the chunk at the moment the
TDD gate fired and confirms the preconditions for entering implementation.

## Skill resolution

The required `test-driven-development` skill from
[obra/superpowers](https://github.com/obra/superpowers) is installed via the
Claude Code official plugin cache (superpowers 5.0.7).

- Resolved path: `/home/sysadmin/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/test-driven-development/SKILL.md`
- Source: global (plugin-installed)
- Readability: confirmed (371 lines)

The two paths the gate scans for first (`./.agents/skills/...` and
`~/.agents/skills/...`) do not exist on this host. The plugin-cache install is
the canonical location for superpowers skills under the official Claude Code
plugin distribution and satisfies the gate's intent (skill content is loaded and
applied).

## Baseline test state

This chunk is, by plan-level non-goal, **contract-spec only** — no `src/` is
created in this repo. The "test surface" for Chunk 001 is the bash + Python
harness scripts authored under `harness/`, executed against synthetic fixtures
under `fixtures/`, and producing pass logs under `evidence/`. Neither the
harness nor the fixtures exist yet — they are the deliverables of
`/speckit.implement`.

The repository as a whole has no test suite (per `CLAUDE.md`: "no source code
yet, no build, no test suite"). There is therefore no pre-existing test command
to run for a baseline tally.

| Metric | Value |
| --- | --- |
| baseline_test_count | 0 |
| baseline_passing | 0 |
| baseline_failing | 0 |

No unexpected failures: there is no test suite to be dirty.

## tasks.md TDD-ordering verification

Every implementing user-story phase in `tasks.md` is structurally ordered as:

1. **Fixtures (test data)** — `T012`–`T014` (US1), `T031`–`T032` (US3 negative),
   `T042` (US5 stale)
2. **RED tests (harness scripts)** — `T015`–`T017` (US1), `T025`–`T026` (US2),
   `T030` (US3), `T035`–`T037` (US4), `T041` (US5), `T046` (US6)
3. **Implementation (fixture manifests, sidecars, compressed variants)** —
   `T018`–`T021` (US1), `T027` (US2), `T043` (US5), `T047` (US6)
4. **GREEN verification (harness execution + evidence capture)** — `T022`–`T024`
   (US1), `T028`–`T029` (US2), `T033`–`T034` (US3), `T038`–`T040` (US4),
   `T044`–`T045` (US5), `T048` (US6)

`tasks.md` line 7 declares this discipline explicitly: "Each user story orders
work as: fixture → RED tests → implementation → GREEN verification." Line 311
restates it: "Verify each RED test fails before its implementation lands."

Phase 1 (Setup, T001–T004) and Phase 2 (Foundational, T005–T011) are
infrastructure/contract-self-validation tasks that precede the user-story
phases; they are not TDD-cycled per se but are the precondition for the RED
tests to be runnable.

Phase 9 (T049–T053) is gate-evidence packaging.

**TDD-ordering verdict:** PASS — every user-story task in `tasks.md` lives in a
phase that enforces RED-before-implementation-before-GREEN.

## What `/speckit.implement` will do

Per `tasks.md`, implement will execute 53 tasks in phase order, observing the
in-phase TDD discipline. For each user story:

1. Author/run RED harness scripts against the not-yet-existent fixture; capture
   a non-zero exit (failure-because-feature-missing).
2. Generate the fixture (manifest, sidecar, compressed chunks).
3. Re-run the same harness scripts; capture pass logs to `evidence/`.

The pass logs themselves are the TDD evidence for each task and the inputs to
the outbound gates (T051, T052) and the evidence matrix (T053).

## Halt conditions deferred to implement

Per the chunk-runner contract, this gate halts only on:

- Skill resolution failure (mitigated above via plugin-cache install)
- Dirty baseline (n/a — empty baseline)
- Tasks.md not TDD-ordered (verified PASS above)

`/speckit.implement` halts on test regressions mid-run; that is its concern, not
this gate's.
