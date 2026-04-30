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
    summary: Initial TDD gate baseline for Chunk 002 (`/speckit.superb.tdd`)
    changes:
      - "Record skill resolution, baseline test count, tasks.md TDD-ordering verification, and toolchain prerequisites flagged for /speckit.implement"
---

# TDD Gate Baseline — Chunk 002 (Client Foundation + Diagnose)

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

This is the **first chunk that introduces in-repo Go source code** (per
`tasks.md` Phase 1, T001–T004 initialise `go.mod` and the package skeleton). At
the moment the gate fires, the repo holds no `go.mod`, no `.go` files, and no
prior Go test surface; `go test ./...` has nothing to run.

The repository as a whole has no pre-existing test suite (per `CLAUDE.md`: "no
source code yet, no build, no test suite"). Chunk 001 is contract-spec only and
contributed no Go code. There is therefore no pre-existing test command to run
for a baseline tally.

| Metric | Value |
| --- | --- |
| baseline_test_count | 0 |
| baseline_passing | 0 |
| baseline_failing | 0 |

No unexpected failures: there is no test suite to be dirty.

## Toolchain prerequisites flagged for `/speckit.implement`

The implement phase will require a working Go toolchain on the executing host
(per `tasks.md` T001 — Go 1.23+ minimum, pinned to a specific minor from the
current stable line; per plan.md D1/D14 — iterator API requires 1.23). At the
moment the gate fires, `go` is **not on the executing agent's PATH**:

```
$ command -v go
$ go version
bash: go: command not found
```

This is recorded here, not as a gate halt, because:

1. The TDD gate's halt conditions are skill resolution failure, dirty baseline,
   or non-TDD-ordered `tasks.md` — none of which apply.
2. Toolchain provisioning is the operator's responsibility for the implement
   phase. `/speckit.implement` will halt cleanly on the first `go test` /
   `go build` invocation with a tool-not-found error if the toolchain is still
   absent at execution time, which is the correct contract-surface for this
   condition.
3. The reference-rig timing tests (T072, T073, T089) are explicitly gated
   behind `//go:build reference_rig` and run as a manual chunk-acceptance gate
   on the named reference rig (per plan.md § Known Coverage Gaps), not on the
   dev host.

If the implement phase is started on this host without first installing Go, the
expected halt is at T001 (`go mod init`).

## tasks.md TDD-ordering verification

Every implementing phase in `tasks.md` is structurally ordered as:

1. **Fixtures (test data)**
2. **RED tests (assertions written first; expected to fail)**
3. **Implementation (production code that makes RED → GREEN)**
4. **GREEN verification (`go test` invocation against the phase's surface)**

Phase-by-phase verification:

| Phase | Fixtures | RED tests | Implementation | GREEN |
| --- | --- | --- | --- | --- |
| Phase 2 — Foundational | T005, T006 | T007–T013 | T014–T020 | T021 |
| Phase 3 — US3 (manifest verifier) | T022, T023 | T024–T030 | T031–T035 | T036 |
| Phase 4 — US2 (predicates) | T037 | T038–T044 | T045–T051 | T052 |
| Phase 5 — US1 (diagnose) 🎯 MVP | T053 | T054–T074 | T075–T087 | T088, T089 |

`tasks.md` line 7 declares this discipline explicitly: "TDD ordering is
mandatory for this chunk per the chunk-runner discipline. Every user story
phase orders fixtures → RED tests → implementation → GREEN verification."
Lines 243–248 restate it as the within-each-user-story ordering rule and
reaffirm the chunk-runner halt: "If `speckit.superb.tdd` observes
implementation-before-test in any phase, the chunk halts."

Phase 1 (Setup, T001–T004) is project-skeleton initialization and precedes the
first RED test. Phase 6 (Polish, T090–T096) is help-text/version-text
implementation, build verification, quickstart smoke test, and the outbound
gate evidence bundle plus evidence matrix. Neither phase is TDD-cycled per se;
both are infrastructure surrounding the user-story phases.

**TDD-ordering verdict:** PASS — every user-story phase in `tasks.md` enforces
fixtures-before-RED-before-implementation-before-GREEN.

## What `/speckit.implement` will do

Per `tasks.md`, implement will execute 96 tasks in phase order, observing the
in-phase TDD discipline. For each user story phase:

1. Author the fixtures (synthetic SQLite-shaped page files, manifest corpora,
   rig harnesses).
2. Author the RED tests against not-yet-existent packages; run `go test` and
   capture failure output (build failure or assertion failure depending on
   stage).
3. Author the production code in `internal/<package>/` to satisfy each RED
   test.
4. Re-run the same `go test` invocation; capture pass output as GREEN evidence.

The pass logs themselves are the TDD evidence for each task and the inputs to
the outbound Gate 002 → 003 evidence bundle (T095) and the evidence matrix
(T096).

## Halt conditions deferred to implement

Per the chunk-runner contract, this gate halts only on:

- Skill resolution failure (mitigated above via plugin-cache install)
- Dirty baseline (n/a — empty baseline)
- Tasks.md not TDD-ordered (verified PASS above)

`/speckit.implement` halts on test regressions mid-run; that is its concern,
not this gate's. A missing Go toolchain at implement-time is also an
implement-phase halt, not a gate-phase one (see Toolchain prerequisites above).
