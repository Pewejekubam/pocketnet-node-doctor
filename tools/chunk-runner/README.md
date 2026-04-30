# chunk-runner

Sequential speckit-pipeline driver for chunked specs. Takes an audited `pre-spec-strategic-chunking.md`, picks one chunk, runs the full speckit pipeline against it under TDD discipline, writes a JSONL audit log + live-state file, announces results on the office speaker.

See [`tools/chunk-runner/run.sh --help`](run.sh) for a terse command-line reference. This README is the narrative companion.

---

## What it does

For one chunk of a chunked spec, runs this canonical speckit pipeline:

```
specify → clarify → plan → tasks → analyze →
superb_review → superb_tdd → implement → superb_verify
```

Each stage spawns a fresh `claude -p` subprocess with the stage-specific prompt from [prompts/](prompts/). The subprocess invokes the matching speckit slash-command, produces artifacts on the feature branch, and emits a tagged JSON return block the runner parses.

`superb_finish` is intentionally omitted from the auto-pipeline — run it manually after human review of the pushed branch.

## Input contract

The chunking doc is the **sole declarative input**. It's produced by [docs/pre-spec-build/process.md](../../docs/pre-spec-build/process.md) — a human-authored, adversarially-audited artifact. Nothing else (no manifests, no input beads) is consumed by the runner.

Runner parses:

| Section of chunking doc | What the runner does with it |
|---|---|
| `## Chunk <id>: <name>` | Extracts the markdown blob into `${CHUNK_SECTION}` for the specify prompt. Scope + SC + all subsections are passed verbatim. |
| `## Plan-Stage Decisions Across All Chunks` — the `- **Chunk <id>**` bullet | Optional. If present, passed into the plan prompt as `${PLAN_DECISIONS_MD}` pre-declared defaults. Absent is fine — `/speckit.plan` resolves in context. |
| `## Progress Tracker` — status column | Dispatcher reads this to find the first `pending` row. Case-insensitive. |

See [DECISIONS.md D13](DECISIONS.md) for the rationale against the prior manifest layer.

## Invocation

```bash
# Direct — run one chunk by id
tools/chunk-runner/run.sh <chunking-doc> <chunk-id>

# Dispatcher — run the next pending chunk in the Progress Tracker
tools/chunk-runner/dispatch.sh <chunking-doc>

# Slash-command skill (same effect from an outer claude-code session)
/chunk-runner run <chunking-doc> <chunk-id>
/chunk-runner dispatch <chunking-doc>
/chunk-runner test <chunking-doc> <chunk-id>     # CHUNK_RUNNER_TEST=1

# Help
tools/chunk-runner/run.sh --help
tools/chunk-runner/dispatch.sh --help
```

## Partial runs (resume / subset / rerun)

`run.sh` supports entering the pipeline mid-stream when a prior run halted on a fixable-in-place finding:

| Flag | Selects | Pre-flight |
|---|---|---|
| `--resume-from <stage>` | `<stage>` through end of pipeline | branch exists + clean tree + prior artifacts present |
| `--stages <s1,s2,...>` | exactly those stages in PIPELINE order | branch exists + clean tree + prior artifacts present for first stage |
| `--rerun <stage>` | single stage | branch exists + clean tree (artifact check skipped — caller asserts idempotency) |

The three flags are mutually exclusive. Default invocation (no flags) is unchanged.

```bash
# After a halt at analyze, fix spec/plan/tasks on the feature branch (commit the fix
# so the tree is clean), then resume:
git checkout 050-039-task-reconciliation-to-pod-chunk-004
tools/chunk-runner/run.sh --resume-from analyze \
    specs/039-task-reconciliation-to-pod/pre-spec-strategic-chunking.md 004
```

A partial run emits a `resume` JSONL event after `start` recording the flag used and the resolved stage list. `STAGES_COMPLETED` in the retro is scored against the selected subset, so a clean `--resume-from analyze` yields a `positive` signal.

## Environment variables

| Var | Default | Purpose |
|---|---|---|
| `CHUNK_RUNNER_TEST` | `0` | When `1`, bypasses claude, beads, push, branch-readiness, stall watchdog. Fixture tests use this. |
| `CHUNK_RUNNER_STAGE_TIMEOUT_SEC` | `14400` | Wall-clock ceiling per stage (4h). SIGKILL's claude + halts on timeout. |
| `CHUNK_RUNNER_STALL_MINUTES` | `3` | **Stall watchdog threshold.** If claude's CPU time + stdout size both show zero delta for this many minutes, the watchdog force-kills the claude subprocess tree. Catches `ep_poll` stalls that would otherwise run the full wall-clock timeout. |
| `CHUNK_RUNNER_STALL_POLL_SEC` | `30` | Watchdog poll interval. Threshold in samples = `(minutes × 60) / poll_sec`, minimum 2. |
| `CHUNK_RUNNER_PROMPTS_DIR` | `$REPO_ROOT/tools/chunk-runner/prompts` | Override prompts directory. |
| `CHUNK_RUNNER_BEAD_PREFIX` | from `.beads/config.yaml issue-prefix`, else basename of `REPO_ROOT` | Override bead-id prefix used to scrape `bd create` output. |
| `REPO_ROOT` | `git rev-parse --show-toplevel` | Override repo root. |

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Pipeline completed. Branch pushed to `origin`. Retro bead emitted. |
| `1` | Runner error (unexpected — e.g. missing chunking doc, non-existent chunk id). State may be inconsistent; inspect the JSONL. |
| `2` | Clean halt. Review bead written. Banner printed to stderr with `stage`, `halt_reason`, bead id, and JSONL path. |

## Artifacts produced

Per run, in order of appearance:

| Artifact | Location | Lifetime |
|---|---|---|
| JSONL event log | `tools/chunk-runner/runs/<spec-slug>-chunk-<id>-<ts>.jsonl` | Persistent (gitignored). Audit layer. |
| Live-state JSON | `tools/chunk-runner/runs/<spec-slug>-chunk-<id>-<ts>.live.json` | Ephemeral. Updated every `STALL_POLL_SEC`. Removed on exit. |
| Session breadcrumb | `~/.claude/projects/<slugified-repo-path>/memory/active-session.md` | Appended at run start. |
| Feature branch | `<spec-slug>/chunk-<id>` | Created by `create-new-feature.sh` during /speckit.specify. Persists post-run. |
| Phase commits | On the feature branch | Produced by superb_tdd + implement stages as they land tasks. |
| `review:gate-refusal` bead | Beads DB | Written on clean halt. Triage queue for human review. |
| `ops:retro` bead | Beads DB | Written on complete. |
| `ops:mut` bead | Beads DB | Written on branch push via plain `bd create`. |

## Monitoring a run

JSONL events fire at stage boundaries only. Between boundaries the JSONL is quiet — the **live-state file** is where real-time heartbeat lives.

```bash
# Tail the event log (stage transitions + halt reasons)
tail -f tools/chunk-runner/runs/<spec-slug>-chunk-<id>-<ts>.jsonl | jq -c

# Live state — empirical heartbeat, updated every ~30s
watch -n 2 jq . tools/chunk-runner/runs/<spec-slug>-chunk-<id>-<ts>.live.json

# Claude subprocess CPU + state (is it actually doing work?)
ps -o pid,etime,time,pcpu,state -p $(pgrep -f 'claude -p')

# Feature branch activity
git log --oneline <spec-slug>/chunk-<id> ^main

# Any halted-run beads waiting for review
bd list --label review:gate-refusal --status open
```

## Halt behavior

Every halt does the same three things:

1. Writes an open `review:gate-refusal` bead with a detailed, itemized `halt_reason`
2. Prints a fat banner to stderr naming the stage + reason + bead id + log path
3. Announces on the office speaker: *"Chunk runner halted on \<stage\>. Review bead \<id\> is open."*

So you do **not** need to be watching the terminal to know a run halted. You triage asynchronously via `bd list --label review:gate-refusal --status open` at your convenience.

### Where halts can fire

| Stage | Halt conditions |
|---|---|
| **specify** | not on main / working tree dirty / feature branch already exists / speckit.specify script missing |
| **clarify** | (no halts — surfaces unresolvable questions to `## Known Issues` section) |
| **plan** | a decision has multiple viable options with no discriminating signal; a decision requires info not present in any available artifact |
| **tasks** | task count >100 (over-scoped); any FR has no corresponding task |
| **analyze** | CRITICAL findings only; HIGH/MED/LOW go to `## Known Issues` |
| **superb_review** | **the blocking gate** — TDD-readiness NOT READY; 4+ coverage gaps or any behavioral gap; any Known Issues entry classified as blocking |
| **superb_tdd** | gate failure (baseline dirty, code-before-test); TDD stuck (3+ fix attempts same task) |
| **implement** | regression loop (2+ attempts same task); prior-chunk regression; outbound-gate evidence can't assemble |
| **superb_verify** | credential-loaded test failure; bare-shell boundary violated; unmapped FR/SC; infra regression |
| **(runner)** | pre-flight fail; per-stage wall-clock timeout (`rc=124`); stall watchdog SIGKILL (`rc=137` with reason file); post-specify branch-substring mismatch |

See [DECISIONS.md](DECISIONS.md) D17/D18/D19 for the shift from upstream halts to `superb_review` as the concentrated gate.

## Recovering from a halt

1. `bd show <review-bead-id>` — read the full halt_reason
2. Inspect the feature branch if it was created: `git log <spec-slug>/chunk-<id> ^main`
3. Decide:
   - **Resume:** fix the underlying cause on the feature branch (commit or leave staged-then-committed so the tree is clean), then `run.sh --resume-from <stage> <doc> <id>`. This is the primary recovery path — see "Partial runs" above.
   - **Re-run a single stage:** `run.sh --rerun <stage> <doc> <id>` when you want to re-execute exactly one stage (e.g. `analyze` after tweaking just one FR).
   - **Delete branch + restart clean:** `git branch -D <branch>` then invoke runner with no flags.
   - **Close the review bead** when the situation is resolved (don't leave stale halts in your queue).
4. If the halt exposed a bug in the chunking doc or a chunk-runner prompt, fix the root cause — don't just retry.

## Test harness

Integration harness at [test/test_runner.sh](test/test_runner.sh) — 26 fixture assertions in `CHUNK_RUNNER_TEST=1` mode against a throwaway chunking doc synthesized in `/tmp`. Unit tests for flag parsing + source-guard at [test/test_arg_parsing.sh](test/test_arg_parsing.sh) (28 assertions) and [test/test_source_guard.sh](test/test_source_guard.sh). No real beads, no claude, no push. Use before any runner change.

```bash
tools/chunk-runner/test/test_runner.sh
tools/chunk-runner/test/test_arg_parsing.sh
tools/chunk-runner/test/test_source_guard.sh
```

## Optional: privacy pre-push hook

For projects that publish to a public mirror alongside a private origin, `hooks/pre-push.example` is a project-agnostic git pre-push hook that scans outgoing commits for internal-leakage patterns (internal hostnames, server-side absolute paths, internal usernames, etc.) and refuses pushes that match.

The hook is a per-clone safety net — `.git/hooks/pre-push` is not tracked by git, so each clone configures its own pattern list.

**Installation:**

```bash
cp tools/chunk-runner/hooks/pre-push.example .git/hooks/pre-push
chmod +x .git/hooks/pre-push
# then edit the patterns=() array in .git/hooks/pre-push to match your
# project's specific leakage-pattern set
```

**Behavior summary** (full detail in the example file's header comment):

- Scans only added lines (`+content`) — removed lines are ignored, so removing a leak doesn't fire the hook.
- For new branches, scans only commits not yet on `origin/main` (merge-base scope), avoiding the full-history false-positive trap on first-push.
- Refuses loudly with a banner naming the pattern + up to 5 sample matches; exits non-zero.
- Bypass with `git push --no-verify` when a match is manually verified safe.

The hook is independent of the chunk-runner pipeline — it applies to every push regardless of whether chunk-runner produced the commits.

---

## Related docs

- [DECISIONS.md](DECISIONS.md) — 20 design decisions with alternatives + revert paths
- [prompts/README.md](prompts/README.md) — per-stage prompt variable surface + return-block contract
- [specs/039-task-reconciliation-to-pod/pre-spec-strategic-chunking.md](../../specs/039-task-reconciliation-to-pod/pre-spec-strategic-chunking.md) — the first real consumer's chunking doc
- [docs/pre-spec-build/process.md](../../docs/pre-spec-build/process.md) — the pre-spec build methodology that produces the chunking doc
