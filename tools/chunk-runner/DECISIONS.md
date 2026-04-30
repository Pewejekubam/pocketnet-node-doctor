# chunk-runner Decisions

Running log of non-obvious calls taken during overnight build. Each entry: date, workstream, decision, rationale, alternatives considered, how to revert if wrong.

---

## D1 — 2026-04-20 · WS1 · Sequential over parallel dispatch

**Decision.** Concurrency cap drops from 2 → 1. One chunk runs at a time. Dispatch picks `bd ready --label <L>` head.

**Rationale.** 038 proved speckit fails inside `git worktree add` paths (Chunk 3 Session Breadcrumb line 589-600: "ordering is the maintainer's call since speckit does not work in worktrees"). The whole point of the v0.1 contract's cap-of-2 was worktree parallelism; without worktrees, parallel runs on a single working tree corrupt each other's branches.

**Alternatives considered.**
- Keep cap-of-2 and document "advisory only" — rejected; harness enforcement must be real or the doc lies.
- Move concurrency to the process level via flock — rejected as premature; sequential is sufficient for the known workload (one chunk takes 1-4 hours; waiting is fine).

**Revert path.** When/if speckit becomes worktree-safe (upstream fix or project-specific patch), bump contract to `0.3.0` and revise dispatch to enforce per-worktree locking.

---

## D2 — 2026-04-20 · WS1 · "branch_ready" replaces "worktree_created" event

**Decision.** JSONL event name in contract §41-49 becomes `branch_ready` (not `worktree_created`, not `branch_created`). The runner does not create the branch; `create-new-feature.sh` (speckit) does, during `/speckit.specify`. The runner only ensures it's on main + clean before starting.

**Rationale.** "branch_ready" accurately describes what the runner verifies; "branch_created" would be false since the runner doesn't do the creating; "worktree_created" is the stale v0.1 concept.

**Alternatives considered.**
- `worktree_skipped` — misleading, as there's no worktree concept at all anymore.

**Revert path.** Trivial rename in contract + runner.

---

## D3 — 2026-04-20 · WS2 · Bash-style `${VAR}` substitution, no templating engine

**Decision.** Prompt templates use literal `${VAR}` placeholders; `run.sh` substitutes via `envsubst` (or bash parameter expansion against an exported env).

**Rationale.** PAM precedent is POSIX shell + jq + python3. No Jinja2, no Handlebars — would drag in a runtime dependency. `envsubst` is in GNU gettext, present on Linux by default.

**Alternatives considered.**
- `sed` with escaping — fragile for multiline values.
- Python f-string wrapper — possible but unnecessary.

**Revert path.** Swap to a real template engine if placeholders grow past trivial replacement. No migration needed beyond the runner.

---

## D4 — 2026-04-20 · WS3 · `claude -p --dangerously-skip-permissions` matches Reach bridge pattern

**Decision.** Each speckit stage spawns `claude -p --dangerously-skip-permissions "<prompt>"`. Output parsed from stdout.

**Rationale.** CLAUDE.md §Skip-Permissions Tradeoff documents this pattern for headless contexts (Reach bridge). Compensating controls already exist: PreToolUse hook (`pam-precheck.js`) enforces autonomy profiles at a layer below CLI permissions. Same profile applies to manual + dispatched sessions.

**Alternatives considered.**
- Interactive `claude` sessions inside screen — reintroduces stdin dependency; regresses to human-orchestrated pattern we're replacing.
- MCP invocation — overkill for single-prompt spawns; claude-p is already the right shape.

**Revert path.** If Claude CLI gains a `--yes-to-preapproved` flag, swap for the narrower permission.

---

## D5 — 2026-04-20 · WS3 · review:gate-refusal bead via `bd create`, not journal.sh

**Decision.** On clean-halt, the runner writes a `review:gate-refusal` bead via `bd create --type=task` with label. It does NOT route through `tools/beads/journal.sh`.

**Rationale.** `journal.sh` is the producer path for `ops:*` tier entries (PAM CLAUDE.md §Operational Journaling). `review:gate-refusal` is decision-class (the maintainer's queue), not operational-mutation-class. Using journal.sh would pollute the ops:mut surface with things that aren't mutations.

**Alternatives considered.**
- Create one `ops:mut` bead AND one `review:gate-refusal` bead — rejected as double-entry noise.

**Revert path.** If `review:*` beads ever get their own producer script, route through it.

---

## D6 — 2026-04-20 · WS3 · Halt exit codes: 0 = complete, 2 = clean halt, 1 = error

**Decision.** Runner exit codes:
- `0` — pipeline completed, branch pushed, retro emitted
- `2` — clean halt (gate failure, analyze CRITICAL, budget exceeded); review bead written; chunk bead un-claimed
- `1` — unexpected error (exception in runner itself); chunk bead may be in inconsistent state — manual inspection required

**Rationale.** Distinct exit codes let dispatch.sh and CI differentiate "this is a review surface" from "this is a runner bug." POSIX convention: 0 success, 1 general error, 2 misuse — we repurpose 2 as "halted cleanly."

**Alternatives considered.**
- Single non-zero exit — loses the clean/dirty signal.

**Revert path.** Trivial change in runner; dispatcher would need to stop distinguishing.

---

## D7 — 2026-04-20 · WS3 · Manifest YAML parsed via `yq` (python-yq, jq-wrapper)

**Decision.** The runner uses `/usr/bin/yq` (python-yq by kislyuk, a jq wrapper that reads YAML) for both YAML → JSON conversion AND field extraction. Syntax: `yq -r '.chunk_bead' <manifest>`.

**Rationale.** Probed the host and discovered `yq` is already installed at `/usr/bin/yq` (version 0.0.0 — python-yq flavor, not Go-yq). PyYAML is NOT installed in the default python3. `node -e` with `js-yaml` works but `js-yaml` is a devDep not guaranteed on PATH. `yq` is the cleanest and matches existing PAM tooling conventions.

**Alternatives considered.**
- `python3 -c "import yaml"` — PyYAML not installed; would require `pip install` (prohibited without approval).
- `node -e 'require("js-yaml")…'` — works but fragile for multi-line/complex YAML; brittle escaping.

**Revert path.** If yq disappears from the host, fall back to installing PyYAML or writing a Node helper in `tools/chunk-runner/lib/yaml.js`.

---

## D8 — 2026-04-20 · WS3 · Use existing `memory/active-session.md` convention (no new breadcrumb file)

**Decision.** Runner writes chunk ID + screen name to `/home/sysadmin/.claude/projects/-data-git-root-pam/memory/active-session.md` per existing MEMORY.md Session Breadcrumb convention.

**Rationale.** Reach bridge reads this file for session recovery. Reusing the slot keeps one source of truth. Content format: prepend a `## Active Chunk` heading block; preserve everything else.

**Alternatives considered.**
- New file at `tools/chunk-runner/active-run.md` — forks the breadcrumb convention; bad.

**Revert path.** Easy — just stop writing.

---

## D9 — 2026-04-20 · WS6 · Dry-run mode gated by `CHUNK_RUNNER_TEST=1` env

**Decision.** When `CHUNK_RUNNER_TEST=1` is set, the runner:
- Replaces `claude -p` invocations with `echo` of the rendered prompt
- Skips `bd update --claim` and all bead mutations
- Skips `git push` (branch_pushed event still emitted with `test_mode:true`)
- Skips the branch-readiness check (so fixture tests can run off main)
- Still writes the JSONL log (so events can be asserted against)
- Exits with the same codes it would in production

**Rationale.** Pure-mechanics validation without touching real beads or spawning real Claude sessions. Environment variable gate is the lightest-weight toggle with no CLI surface to maintain.

**Alternatives considered.**
- `--dry-run` flag — pollutes the production arg surface.
- Separate `run-test.sh` wrapper — duplicates the core.

**Revert path.** Delete the conditional blocks.

---

## D10 — 2026-04-20 · WS5 · Skill lives at `.claude/commands/chunk-runner.md`, not `.agents/skills/`

**Decision.** The bridged skill file lands at `.claude/commands/chunk-runner.md` (slash-command) and points to `tools/chunk-runner/` (project-local tool).

**Rationale.** `.agents/skills/` is for obra/superpowers-style skill bundles (`SKILL.md` format). PAM-local tools follow the `tools/<name>/tool.md` + `.claude/commands/<name>.md` pattern already used by `speckit.superb.tdd`. This keeps PAM-authored logic distinguishable from upstream skill imports.

**Alternatives considered.**
- Both locations — duplication, no benefit.

**Revert path.** N/A; no competing skill to consolidate with.

---

## D11 — 2026-04-20 · WS3 · Runner foreground, caller decides background

**Decision.** `run.sh` executes in the foreground. If the maintainer wants it to detach, he runs it under `screen` or `nohup`. The runner does NOT self-daemonize.

**Rationale.** Autonomy-profile enforcement (pam-precheck.js) and session-breadcrumb hygiene depend on a known parent session. Self-daemonization hides that parent; screen/nohup keeps it explicit + debuggable.

**Alternatives considered.**
- Runner fork-and-exec — complicates log redirect + signal handling for minimal gain.

**Revert path.** Add `--detach` flag later if needed.

---

## D12 — 2026-04-20 · post-handoff · Gitea, not GitHub — `git push`, not `gh pr create`

**Decision.** The runner's "Ship" step does `git push -u origin <branch>` + emits `branch_pushed` event. It does NOT call `gh pr create`. If automated PR creation is ever needed, the path is Gitea REST (`POST /api/v1/repos/{owner}/{repo}/pulls`) — not gh.

**Rationale.** Caught mid-session when the maintainer said "We don't use gh. I use Gitea." Initial assumption was wrong because I defaulted to the most common "open PR" CLI without checking the remote. Remote URL is self-hosted Gitea; the 038 convention across four merged chunks was `git merge --no-ff` under human review, not API PR. `tools/website/scripts/deploy.sh` and `rollback.sh` are precedent — plain `git push`, no PR machinery.

**Alternatives considered.**
- Gitea REST API call — viable but no token-plumbing exists in `tools/` yet and the maintainer's preference for the 038 cadence is local merge after review. Can add later with a manifest flag like `auto_open_pr: true` if wanted.
- Leave `gh pr create` with "not installed" error messaging — unacceptable; silent runtime failure at a gated step would claim + then strand the chunk bead.

**Revert path.** Replace `push_branch` with a Gitea API call if future automation demands it; event name `branch_pushed` can broaden to `branch_pushed_with_pr` or stay as-is with data-field enrichment.

See `memory/feedback_gitea_not_github.md` — feedback memory recorded so I don't repeat this mistake.

---

## D13 — 2026-04-20 · v0.2 refactor · Chunking doc is the sole declarative input (no manifests, no input beads)

**Decision.** Runner consumes `pre-spec-strategic-chunking.md` + `<chunk-id>` directly. Per-chunk `chunk-NNN.manifest.yaml` files are gone. Chunk tracking beads are gone as an input surface. Beads remain as OUTPUT surfaces only (retro, journal, review).

Invocation surface changed from:
```
run.sh <bead-id | manifest-path>
dispatch.sh <label>            # used bd ready --label <L>
```
to:
```
run.sh <chunking-doc-path> <chunk-id>
dispatch.sh <chunking-doc-path>   # reads § Progress Tracker
```

**Rationale.** v0.1 had three layers: chunking doc → hand-authored manifest → hand-authored tracking bead. the maintainer called out: the manifest and input-bead layers are derivatives of the chunking doc, carrying no information of their own. `docs/pre-spec-build/process.md` declares the chunking doc self-sufficient: *"the chunking document scoped by chunk identifier IS the mini-pre-spec."* Three inputs were two too many. Every manifest field was reformatting (SC lists, plan decisions, pre-flight gates, feature description, etc.). Every input-bead role (ID lookup, status gate, ready-queue pick) was recomputable from the chunking doc's Progress Tracker + git branch state.

**Alternatives considered.**
- Keep manifests but auto-generate them from the chunking doc — rejected; the generator becomes a new brittle surface and we're still carrying duplicated state.
- Keep beads as input selectors only (just the queue) — rejected; mixing "beads sometimes selector, sometimes output" is a worse architecture than "beads always output, chunking doc always input."
- Keep the contract.md file — rejected in the same pass. Nothing it documented was load-bearing that couldn't live in run.sh's header, the skill doc, prompts/README.md, or this DECISIONS file.

**What got deleted.**
- `specs/039-task-reconciliation-to-pod/harness/` (all 5 manifests + the old contract.md + runs/ gitignore, 1150 lines total)
- `${CHUNK_BEAD}` + `${PLAN_DECISIONS_JSON}` + `${FEATURE_DESCRIPTION}` template variables
- `bd update --claim` / `bd ready` / `bd show` from run.sh + dispatch.sh
- `## When done` bead-update instructions from 9 prompt templates

**What got added.**
- Chunking-doc parsers in run.sh: `extract_chunk_section`, `extract_plan_decisions` (awk-based, brittle but workable)
- Progress Tracker table parser in dispatch.sh (awk on `## Progress Tracker` section, picks first `pending` row)
- `${CHUNK_SECTION}` template variable — the full markdown blob from `## Chunk <id>` to next `## ` heading, passed into specify.md so Claude interprets the scope directly
- `${PLAN_DECISIONS_MD}` — markdown bullet from `## Plan-Stage Decisions Across All Chunks`

**What stayed.**
- Bash runner, `envsubst`-based templates, JSONL event audit log, clean-halt sequence, 9-stage canonical pipeline (specify → clarify → plan → tasks → analyze → superb_review → superb_tdd → implement → superb_verify)
- Output beads: `ops:retro` (close on emit), `ops:mut` via `tools/beads/journal.sh`, `review:gate-refusal` (open for the maintainer's queue)
- `CHUNK_RUNNER_TEST=1` dry-run mode
- Test harness — rewrote fixture to a throwaway chunking doc; 18/18 assertions green
- Bridged skill at `.claude/commands/chunk-runner.md`

**Handoff point.** An audited `pre-spec-strategic-chunking.md` (Stage 6 output of `docs/pre-spec-build/process.md`) is the handoff. After that, chunk-runner takes over. Nothing hand-authored between the process and the runner.

**Revert path.** If chunking-doc parsing proves too brittle in real runs, the path back is: write a `tools/chunk-runner/parse-chunking-doc.js` Node helper (js-yaml is a devDep already) with richer markdown parsing than awk. The runner's public interface — `run.sh <doc> <chunk-id>` — stays stable even if the parser implementation changes.

See `pam-6pl74` for the refactor tracking bead.

---

## D14 — 2026-04-20 · architect-feedback round 1 · Return block is a JSON object, extract the LAST block

**Decision.** Claude emits a single JSON object between the existing `=== CHUNK-RUNNER RETURN ===` and `=== END ===` tags. Runner extracts the block and parses with `jq`. No markdown fences around the JSON (architect suggested fences; pushed back because fences add another failure surface — see below). The runner captures the LAST such tagged block in the claude output, not the first.

**Rationale.** The v0.2.0 `parse_return_block` used `awk -F': '` + `sed` quote escaping on key:value lines. Any stage output with a colon inside a value, a multi-line field, or slightly-off format would produce garbled output that `jq` rejected downstream — brittle. JSON + `jq` is the robust idiom for structured output. The architect called this out explicitly as the highest-risk item before first live run.

The "last block" discipline is necessary because the PROMPT templates contain an example return block in their instruction text (showing Claude what to emit). A first-match extractor would grab the example as if it were the actual return. The awk range `/=== CHUNK-RUNNER RETURN ===/ { cap=1; buf=""; next } /=== END ===/ && cap { last=buf; cap=0; next } cap { buf=buf $0"\n" } END { printf "%s", last }` captures the final block only.

**Alternatives considered.**
- Markdown-fenced JSON block (architect's suggestion). Rejected: fence char counts (```` vs `~~~` vs 4-vs-5 backticks) can drift between Claude's output and the extractor. One less shape to validate is one less failure mode.
- Keep key:value and harden the awk parser. Rejected: every hardening step is another escape-dance. jq is the right tool.
- Use Claude's tool-use / structured-output API. Rejected: `claude -p` is stdin/stdout; tool-use would require a different invocation surface. Worth considering later if prompt-driven JSON proves unstable.

**Verification.** Test harness (`tools/chunk-runner/test/test_runner.sh`) synthesizes a JSON return block in TEST mode; 18/18 assertions green including full 9-stage pipeline traversal. First live run will verify against Claude's actual output shape.

---

## D15 — 2026-04-20 · architect-feedback round 1 · Post-specify branch invariant

**Decision.** After the `specify` stage emits `status: "pass"`, the runner verifies `git branch --show-current` contains the string `chunk-${CHUNK_ID}`. If not, halt before any subsequent stage operates on the wrong git state.

**Rationale.** `/speckit.specify` creates the feature branch inside Claude's subprocess (via `.specify/scripts/bash/create-new-feature.sh`). If Claude's subprocess finishes with an unexpected branch checked out (wrong name, main, detached HEAD), subsequent stages silently operate on the wrong tree. The architect flagged this as a real risk.

**Implementation.** Check is scoped to `stage == "specify"` only (other stages run on the branch specify created, no re-verification needed per-stage). Uses substring match (`*"chunk-${CHUNK_ID}"*`) rather than exact match against `<spec-slug>/chunk-<id>` because `create-new-feature.sh` may normalize branch names (different prefixes, slug transformations). Substring match tolerates reasonable naming drift while still catching "wrong branch entirely."

**Alternatives considered.**
- Exact-match against the convention-derived branch name. Rejected: too brittle — any naming drift in `create-new-feature.sh` would halt even when the actual result is correct.
- Check after every stage. Rejected: premature, adds noise, and once on the feature branch there's no mechanism that would switch away unless Claude explicitly does so (in which case we already have bigger problems).

---

## D16 — 2026-04-20 · architect-feedback round 1 · Per-stage wall-clock timeout

**Decision.** Each `claude -p` invocation is wrapped with `timeout --preserve-status ${CHUNK_RUNNER_STAGE_TIMEOUT_SEC:-14400}` (default 4h). On timeout, stage halts with halt_reason naming the budget. Env-overridable for tests or short-budget chunks.

**Rationale.** v0.1.0 had `budget.wall_clock_seconds: 14400` in every manifest. D13 removed the manifest layer but forgot to re-home the budget at the runner level. Without it, a runaway `implement` stage could burn tokens + wall-clock for hours before anyone notices. `timeout(1)` + exit-code 124 is the POSIX-native way to bound a subprocess.

**Implementation.** `--preserve-status` so we see claude's actual exit code when it exits on its own; `timeout` reports 124 only when it actually kills the process. The run_stage rc-handler maps 124 → "stage exceeded wall-clock budget (Ns)" halt_reason.

**Alternatives considered.**
- Background `claude -p` and kill from a watchdog thread. Rejected: `timeout` is the built-in for this.
- Per-stage budgets (specify vs. implement have different typical runtimes). Deferred — uniform 4h is defensible for v0.2; differentiate if real data shows stages consistently over/under.

**See:** architect feedback thread 2026-04-20; all three (D14-D16) from the same review.

---

## D17 — 2026-04-20 · bug fix · Drop the plan.md pause-at-N-decisions halt mechanic

**Decision.** Remove the "if more than 3 plan-layer decisions are not pre-declared, halt" rule from `prompts/plan.md`. Also remove the plan_decisions_pre_declared / plan_decisions_autonomous / plan_decisions_halted return-block fields (retained just a single decisions_resolved counter). `/speckit.plan` is now free to resolve plan-layer decisions as the process designs it to.

**Rationale.** The pause-at-N mechanic was inherited from 038's human-orchestrator cadence, where the maintainer personally ruled on each plan-layer decision before `/speckit.plan` ran. I encoded it as a required discipline for autonomy. Misalignment: `docs/pre-spec-build/process.md` does NOT require pre-declaration of plan-layer decisions in the chunking doc. `/speckit.plan`'s job is to resolve them in context, informed by spec.md + research.md + data-model.md. Treating that as an autonomy risk and halting was a false guardrail.

Caught during the first live chunk-runner run against 039 Chunk 001. Halt fired at plan stage with 8 deferrals (0 pre-declared because 039's chunking doc has no `## Plan-Stage Decisions` section — an intentional design choice, not an omission). The 8 deferrals were exactly the kind of decisions `/speckit.plan` is designed to resolve. See review bead pam-7bxdt for the full halt output; that bead captures accurate forensic data, but the halt itself was spurious.

**What stays.**
- The optional `${PLAN_DECISIONS_MD}` variable — if a chunking doc DOES declare plan-stage decisions, they're passed into the prompt as authoritative defaults. Useful when a project chooses to pre-rule.
- The decision-resolution order (pre-declared → precedent → pre-spec constraint → narrower option). That ladder applies whether there are 1 or 20 decisions.

**What changes.**
- `plan.md` no longer has a decision-count halt. Halts are reserved for genuine blockers: irresolvable ambiguity with material trade-offs and no discriminating signal, or missing information that can't be inferred from available artifacts.
- Return contract simplified: `decisions_resolved` as a single counter, no longer split into pre-declared/autonomous/halted buckets.

**Alternatives considered.**
- Raise the threshold from 3 to some higher number. Rejected: any arbitrary threshold would misfire on the next chunk. The mechanic was wrong in principle, not in tuning.
- Make the threshold configurable per chunk via a chunking-doc field. Rejected: adds a configuration surface without solving the underlying misalignment.
- Keep the mechanic but require opt-in. Rejected: complicates the runner for no gain. The pre-spec-build process is already the guardrail; additional runtime gatekeeping duplicates it.

**Revert path.** None planned. If a future failure mode surfaces that needs runtime gatekeeping, design a targeted halt condition specific to that failure — don't re-introduce a generic volume threshold.

**Related bug (flagged, not fixed here).** The halt emitted `stage_halted` twice — once from `run_stage` on non-pass return, once from `clean_halt` at its entry. Cosmetic log noise. Fix in a follow-up commit.

---

## D18 — 2026-04-20 · review-gate relocation · analyze surfaces, superb.review decides

**Decision.** `/speckit.analyze` halts ONLY on CRITICAL findings. HIGH, MEDIUM, LOW are surfaced (via in-session mechanical fix, `## Known Issues` section append, or `next_stage_inputs` deferral) and passed forward. `/speckit.superb.review` becomes the blocking gate for TDD-readiness: it reads the Known Issues entries + deferred findings, classifies each as blocking / acknowledge / resolvable-in-session, and halts with a specific itemized reason if any is genuinely blocking.

**Rationale.** the maintainer's feedback after the first two live runs: *"90% of the time I take the analyze recommendation anyway. If we add superb to the review, I would just let that make the decision. As long as each decision is well documented in the beads for the runner session I can at least ask for a triage report later."* The underlying principle: raise the HITL bar to the strongest reasoner in the pipeline. `/speckit.analyze` does fast pattern-based sweeps; `/speckit.superb.review` does deeper context-aware assessment against the full spec + plan + tasks with known-issues visibility. If superb can make the call, let it.

The prior analyze.md rule (halt on HIGH that's "plan-level rework") was fixture 038 behavior — it matched the maintainer's manual cadence where he ruled on every HIGH himself. Autonomous runs don't have that human checkpoint; the correct substitute is `/speckit.superb.review`, not a hair-trigger halt at analyze.

**What stays.**
- CRITICAL at analyze still halts. A CRITICAL means the artifact set is structurally unusable (untestable requirement, plan contradicts chunking-doc constraint); no reasoner should push past it without human intervention.
- Mechanical fixes in-session at analyze (typos, terminology drift) unchanged.
- superb.review's existing coverage-gap threshold (4+ gaps or any behavioral gap → halt) unchanged.

**What changes.**
- analyze's "HIGH requires plan-level rework → halt" rule deleted.
- analyze now writes non-mechanical HIGH findings to a `## Known Issues` section in the affected artifact (plan.md, tasks.md, or spec.md). The entry format: date-stamped, severity-tagged, with "Decision needed by" pointer.
- superb.review explicitly reads and classifies `## Known Issues` entries. Every entry gets a resolution: resolve-and-remove, acknowledge-and-proceed, or halt. Never silently ignored.
- superb.review's halt_reason is required to itemize each blocking finding verbatim — powers the maintainer's "ask for a triage report later" workflow from `review:gate-refusal` beads.

**What this buys.**
- Fewer spurious halts at analyze (the 90% the maintainer takes anyway).
- Concentrated halt surface at superb.review, where halt context is richer and more actionable.
- Documented-via-bead audit trail: every halt gets a `review:gate-refusal` bead with itemized halt_reason; every proceed gets the `## Known Issues` residue in the artifact for later triage.

**Alternatives considered.**
- Keep analyze-halt but raise threshold (e.g., only halt on 3+ HIGH). Rejected: arbitrary, same misfire mode as D17's pause-at-N.
- Make analyze advisory-only (no halts at all). Rejected: CRITICAL genuinely means structurally broken; halting there is correct.
- Add a post-analyze manual-review checkpoint that surfaces findings to the maintainer for approval before continuing. Rejected: reintroduces the HITL loop the maintainer is explicitly trying to escape.

**Revert path.** If superb.review proves too permissive in practice — e.g., it proceeds past a HIGH that should have halted, and implementation then breaks in downstream review — add stricter halt rules to superb.review's coverage-gap threshold, not back to analyze. Analyze is the wrong layer for that decision.

See the halt that triggered this decision: review bead `pam-pcpbx` (closed).

---

## D19 — 2026-04-20 · clarify also defers to superb.review — surface, don't halt

**Decision.** Extend D18's principle to `/speckit.clarify`. Clarify no longer halts on "scope-level clarification requires human review" or ">8 non-trivial questions." Unresolvable questions go into a `## Known Issues` section in spec.md with the same format analyze uses. `/speckit.superb.review` consumes both analyze's and clarify's Known Issues entries.

**Rationale.** Same logic as D18. Clarify is a question-asking stage, not a decision-making stage. Its autonomous resolution ladder (pre-spec → chunking doc → cross-chunk vocabulary → merged-chunk precedent → defensive default) is best-effort; when it can't resolve, the right handler is the downstream reasoner with richer context, not a halt that requires human intervention in the middle of the pipeline. the maintainer's framing: *"this also applies to the clarify task as well."*

**What stays.**
- The 5-priority autonomous-resolution ladder at clarify.
- The "defer plan-layer decisions to /speckit.plan" discipline (these are explicit deferrals, not unresolvable questions).

**What changes.**
- Two halt rules removed: scope-level clarification halt + >8-questions halt.
- Unresolvable questions now append to `## Known Issues` (format shared with analyze for easy superb.review consumption).
- The `>5 unresolvable questions` signal is surfaced in `next_stage_inputs` as an observation for superb.review + any future review bead — but is not itself a halt trigger.
- Return contract adds `known_issues_added` counter.

**Why not zero halts at clarify?** Clarify theoretically could surface a CRITICAL-equivalent (e.g., pre-spec contradicts chunking doc in a way that makes the whole chunk impossible). Today that's detectable at superb.review too, so no halt rule added at clarify. If empirical runs prove that's too late, we can add one — but by default, the no-halt principle holds.

**Revert path.** Same as D18 — if superb.review proves too permissive, tighten its halt rules, not re-introduce halts upstream.
