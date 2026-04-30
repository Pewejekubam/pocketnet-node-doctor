---
version: 0.3.3
status: draft
created: 2026-02-23
last_modified: 2026-04-30
authors: [pewejekubam, claude]
changelog:
  - version: 0.3.3
    date: 2026-04-30
    summary: Patch — codify three-digit zero-padded chunk ID convention as a Stage 4 Progress Tracker authoring rule
    changes:
      - "Stage 4 § Strategic Chunking: new authoring rule pins chunk IDs as three-digit zero-padded (`001`, `002`, …); chunk-scoped contract IDs (CR-prefix, CSC-prefix) inherit the same prefix. Promoted to a process-wide convention so the chunk-runner's feature-branch convention (`<spec-dir-basename>/chunk-<id>`) produces stable widths across projects with ≥10 chunks."
  - version: 0.3.2
    date: 2026-04-26
    summary: Three additions surfaced by the 058-1 auto-chunk-runner retrospective — Stage 7 Post-Implementation Reconciliation; runner pre-flight as a third propagation-defense; Progress Tracker column-order convention
    changes:
      - "Stage 7 § Chunked Path: new 'Post-Implementation Reconciliation' subsection documents the as-built loop the auto-chunk-runner automates after `superb.verify` passes — spec-status flip commit, chunking-doc rewrite (Progress Tracker status flip + per-chunk addendum), feature-branch push, Epic-bead closure-line append, heartbeat-bead close. Names the steps so they are recoverable manually if the runner stalls mid-epilogue."
      - "Propagation Through chunk-runner § Two defenses in depth: the launch pre-flight is now named as a third defense alongside PSA-11 (pre-spec audit) and superb.verify (spec-coverage backstop). Predicates the pre-flight enforces are listed inline — Progress Tracker shape, branch cleanliness, current-status row identification — to make the contract between chunking-doc and runner explicit."
      - "Stage 4 § Strategic Chunking: new authoring rule pins Progress Tracker column order — Status MUST be the rightmost column, with capitalized values (`Pending` | `In Progress`). Promoted from a doc-local fix in 058 chunking v0.3.1 to a process-wide convention; the auto-chunk-runner pre-flight parses the last cell as the status field."
  - version: 0.3.1
    date: 2026-04-26
    summary: Stage 7 issue-provisioning step — close the gap between Stage 6 approval and chunk-runner launch
    changes:
      - "Stage 7 § Chunked Path now opens with a Pre-launch Issue Provisioning paragraph: one Epic-equivalent issue per pre-spec; one child issue per chunk, created at runner-launch time"
      - "Stage 6 exit criteria amended to make the Stage 7 handoff transition explicit"
      - "Project-agnostic framing preserved — Epic / child terminology is generic; tool-specific commands (e.g., bd create, gh issue create, jira create) live in the respective runner-skill reference docs"
  - version: 0.3.0
    date: 2026-04-24
    summary: Intent-is-pre-ratified reframe — SpecKit Stop Inventory concept, PSA-11 audit criterion, Speckit Stop Resolutions convention for chunking docs
    changes:
      - "New concept: SpecKit Stop Inventory — the enumerable, knowable set of decision points the speckit pipeline raises per chunk"
      - "Stage 2 exit criteria extended: audit verifies pre-spec answers every expected speckit stop without forcing defensive-default or Known-Issues fallback"
      - "Stage 4 chunking convention: per-chunk `### Speckit Stop Resolutions` subsection carrying authorized answers for stops the pre-spec handles at chunk granularity"
      - "Worked-example reference: 051 Chunk 3b (thin-intent-at-audit-time produces runtime drift) vs. 051 Chunk 4 (rich intent ships fire-and-forget)"
      - "Design commitment: fire-and-forget execution via chunk-runner; no HITL mechanism is baked into the runner, so the pre-spec + chunking doc must pre-answer every predictable stop"
      - "Propagation Through chunk-runner section added: names stage prompts as the operational counterpart of PSA-11, documents live-disk-read freshness, surfaces specify-faithfulness as the single propagation bottleneck"
      - "Stage 4 versioning discipline clarified: Progress Tracker / checklist updates during chunk runs are patch-version bumps with changelog entries"
      - "`## Plan-Stage Decisions Across All Chunks` deprecated — superseded by per-chunk `### Speckit Stop Resolutions`; existing chunking docs with it remain compatible (runner's parse is optional)"
      - "Cross-chunk defaults explicitly routed to pre-spec Implementation Context rather than per-chunk resolutions; chunks inherit defaults via pre-spec path present in every stage prompt context"
      - "Clarify-stage autonomous resolution ladder (tools/chunk-runner/prompts/clarify.md) simplified: cross-chunk-vocabulary rung removed, as the convention it referenced was never authored in process.md and Speckit Stop Resolutions now carries chunk-level terminology pins"
  - version: 0.2.0
    date: 2026-04-17
    summary: Add Stage 3.5 Scope Triage — routing decision between full chunking and direct implementation
    changes:
      - "Stage 3.5: Scope Triage with signals for chunk vs. direct-implementation decision"
      - "Stage 7: Split into Chunked Path and Direct Path subsections"
      - "Stage 3 exit criteria updated to reference scope triage"
  - version: 0.1.0
    date: 2026-02-23
    summary: Initial process specification — pre-spec build methodology extracted from PAM Phase-01/02 practice
    changes:
      - "Seven-stage workflow: author → audit → refine → chunk → audit → refine → implement"
      - "Document standards: semver frontmatter, declarative tone, changelog-only version tracking"
      - "US/FR/SC triad documented as the core quality driver"
      - "Artifact inventory and relationship map"
      - "Companion audit criteria in audit-criteria.md"
---

# Pre-Spec Build Process

## Purpose

This document defines the iterative process for producing high-quality pre-specifications and strategic chunking plans. These documents serve as the primary input to the `speckit.specify` → `speckit.implement` pipeline.

The process is project-agnostic. It applies to new projects, new phases of existing projects, and chunk-level implementation planning.

## Core Insight

The quality of `speckit.specify` output is directly proportional to the quality of its input. A well-crafted pre-spec with clear US/FR/SC traceability, outcome-focused requirements, and properly bounded scope produces implementable, testable code on the first pass. Conversely, a pre-spec with prescription leaks, orphaned requirements, or vague success criteria cascades into bloated plans, unnecessary tasks, and untestable implementations.

The pre-spec build process exists to maximize input quality through structured authoring, adversarial auditing, and human-directed refinement.

## Fire-and-Forget Execution: Intent Is Pre-Ratified

The speckit pipeline (`specify` → `clarify` → `plan` → `tasks` → `analyze` → `superb.review` → `superb.tdd` → `implement` → `superb.verify`) is designed with native decision points — stops where the pipeline expects a human to reason about ambiguity, choose a technology, arbitrate a trade-off. `chunk-runner` executes this pipeline fire-and-forget. It does not bake HITL ratification into the runner; no transition-gate primitive halts the pipeline for inter-phase human consultation.

For fire-and-forget execution to work, the pre-spec build process must pre-answer every native speckit stop. The pre-spec + chunking doc ARE the ratification. Every decision point the pipeline will hit must be resolvable from authored intent before the runner is launched.

This is already reflected in the chunk-runner stage prompts. `clarify.md` encodes an autonomous resolution ladder (pre-spec text → chunking doc text → cross-chunk vocabulary → prior merged chunks → defensive default). `plan.md` encodes the same pattern for plan-layer decisions (pre-declared default → precedent → pre-spec constraint → conservative default). These ladders exist because the runner cannot ask the human at runtime. The top rungs — pre-spec text, chunking doc text — are what the pre-spec build process produces.

The pre-spec build process's job: fill those top rungs so richly that the lower-rung fallbacks (defensive default, Known Issues, halt) are rarely triggered. A pre-spec that forces frequent fallback is thin; its defects surface not as runtime halts but as drift that lands on a feature branch and requires revert.

## The SpecKit Stop Inventory

The speckit pipeline's decision points are not mysterious. They are enumerable per chunk. At pre-spec audit time (Stage 2) and chunking audit time (Stage 5), the auditor consults the inventory — the known catalog of what each `/speckit.*` stage prompts for — and verifies that the pre-spec + chunking doc contain enough intent to resolve every inventoried stop without triggering a fallback.

The full inventory lives in [`audit-criteria.md`](audit-criteria.md) alongside the audit criterion that operationalizes it (PSA-11: SpecKit Stop Coverage). In brief, the inventory covers:

- **Clarify-stage stops** — the up-to-five clarification questions about FR ambiguity, SC unverifiability, terminology, scope boundary, edge-case omission.
- **Plan-stage stops** — decisions about technology choice, architectural pattern, data shape, testing strategy, integration pattern, error-handling posture, concurrency model.
- **Tasks-stage stops** — task decomposition, phase boundaries, outbound-gate evidence (narrow surface; halts mostly signal upstream thin intent).
- **Analyze-stage findings** — coverage gaps and terminology drift that should have been caught at pre-spec audit.
- **Superb.review blocks** — the last-chance gate that reads Known Issues and assesses TDD-readiness; anything reaching it is evidence the resolution ladder fell through.

When PSA-11 finds an inventoried stop that the pre-spec + chunking doc cannot pre-answer, the finding is CRITICAL — fix the intent at authoring time, not at runtime.

## Worked Example: 051 Chunk 3b vs. Chunk 4

The 051 vault writer consistency contract produced two adjacent chunk runs that make the fire-and-forget commitment concrete.

- **Chunk 3b (retired, inflation drift).** The chunking doc declared a freeze-line: "writer's contract surface is shippable; per-consumer migration is post-ship." That freeze-line was correct. But the pre-spec / chunking-doc text did not pre-answer the plan-stage stop "what verification instrument confirms consumer compliance?" `/speckit.plan` fell through its resolution ladder and chose a bespoke scanner + per-consumer tests + fixture authoring — a 71-task inflation. The runner had no gate to halt on; 15 commits landed before revert. The defect was at pre-spec audit time: an inventoried plan-stage stop was left unanswered. PSA-11 would have flagged it.
- **Chunk 4 (shipped, zero drift).** Same kind of chunk; the pre-spec + chunking doc contained enough intent (freeze-line explicit, verification-instrument choice pre-declared, scope language tight) that every speckit stop resolved against authored intent. The pipeline shipped fire-and-forget with human touch only at the final merge review. This is the target shape.

The lesson: drift is an upstream defect, not a runtime one. The remedy is richer intent at authoring and auditing, not instrumentation at runtime.

## Propagation Through chunk-runner

The pre-spec build process produces authored intent. `chunk-runner` is the mechanism that carries that intent through the speckit pipeline. Understanding the propagation path is how the fire-and-forget commitment becomes operational.

### The reasoning hook is per-stage, not per-runner

`chunk-runner` is a dispatcher. It spawns a fresh `claude -p` subprocess per pipeline stage, handing each subprocess a stage-specific prompt from [`tools/chunk-runner/prompts/`](../../tools/chunk-runner/prompts/). The runner itself does no reasoning; the prompt IS the reasoning hook. Each prompt:

- Names the relevant context paths (`${PRE_SPEC_PATH}`, `${CHUNKING_DOC_PATH}`, `${CHUNK_SECTION}`).
- Encodes an autonomous resolution ladder (pre-spec → chunking doc → precedent → defensive default) scoped to the decisions that stage raises.
- Defines a return contract the runner parses for the next-stage input.

PSA-11's job at pre-spec audit time is to ensure the top rungs of every ladder hold. The stage prompts are its operational counterpart — the machinery that consumes what PSA-11 verified is sufficient.

### Intent stays fresh via live disk reads

The runner passes **paths** via environment variables, not content. Each stage subprocess reads the source files from disk at stage execution time. There is no cached intent, no in-memory transform, no derived intermediate. If the chunking doc is amended mid-run (halt-and-resume after a human correction), the next stage reads the update.

This is a strong property: intent is never stale because it is never copied. A chunking doc committed on the feature branch between stages is authoritative for every subsequent stage read.

### Propagation map across the nine pipeline stages

Stages split into two classes:

- **Directly intent-wired** (`specify`, `clarify`, `plan`, `analyze`): the prompt explicitly names `${PRE_SPEC_PATH}` and/or `${CHUNKING_DOC_PATH}`. The subprocess reads source. Autonomous resolution ladders resolve against fresh authored intent.
- **Compiled-artifact-inheriting** (`tasks`, `superb.review`, `superb.tdd`, `implement`, `superb.verify`): the prompt relies on the downstream artifacts — `spec.md`, `plan.md`, `tasks.md` — that prior stages produced. Intent rides forward through those compiled artifacts.

`tasks` is a partial case: it reads only the chunking doc's outbound-gate section, plus spec.md and plan.md. `superb.verify` is also partial: it reads the chunking doc's outbound-gate success criteria but not the pre-spec directly.

### The single point of propagation failure: specify-faithfulness

Because late stages inherit intent through compiled artifacts, `specify` is the bottleneck. Its job is to carry the chunk blob — including `### Speckit Stop Resolutions` and all FR/SC/US/EC content — faithfully into `spec.md`. Once there, the intent rides forward. If `specify` truncates, paraphrases loosely, or drops content, nothing downstream notices until `superb.verify` at the end.

Three defenses in depth:

1. **PSA-11 at pre-spec audit** — the tightest loop. Prevents thin intent from entering the pipeline at all. A chunk that passes PSA-11 + CSA-11 gives `specify` a chunk blob dense enough that faithful carry-forward is mostly mechanical translation.
2. **Runner launch pre-flight** — the structural gate. Before the runner spawns, the launcher (e.g. auto-chunk-runner) verifies the chunking-doc surface the runner is about to consume: Progress Tracker is well-formed, the named chunk's row exists with a recognizable status, the feature branch is plausible, the working tree is clean, no stale state file exists. Predicate failures refuse launch with a diagnostic and leave no state behind. This catches authoring drift between Stage 6 and runner spawn — the place a chunking-doc edit could otherwise have a bad consequence.
3. **`superb.verify` at the end** — the backstop. Its spec-coverage matrix catches drift that slipped through the propagation chain. This gate remains; the intent infrastructure narrows the window in which drift can live, it does not replace the final check.

Between these three ends, the directly intent-wired stages (`specify`, `clarify`, `plan`) re-read from source each time, so intent is re-injected at every decision-dense transition. The compiled-artifact-inheriting stages (`tasks`, `superb.review`, `superb.tdd`, `implement`) are deliberate — they are meant to be deterministic consumers of the compiled plan, not sites of further intent reasoning.

The takeaway for pre-spec authoring: the pre-spec + chunking doc don't need to be "read" at every stage; they need to be **rich enough at specify-time that compilation is lossless**. PSA-11 verifies that richness before the runner is launched; the launch pre-flight verifies the surface itself is well-formed.

---

## Document Standards

All documents produced by this process are first-class artifacts.

### Frontmatter

Every document carries YAML frontmatter:

```yaml
---
version: 0.1.0          # semver — major.minor.patch
status: draft            # draft | approved | superseded
created: YYYY-MM-DD
last_modified: YYYY-MM-DD
authors: [human, claude]
related: pre-spec.md     # parent or sibling document (if applicable)
changelog:
  - version: 0.1.0
    date: YYYY-MM-DD
    summary: One-line summary of this version
    changes:
      - "Specific change 1"
      - "Specific change 2"
---
```

### Versioning Rules

- **Patch** (0.1.0 → 0.1.1): Typo fixes, formatting corrections, clarification of existing content without changing meaning.
- **Minor** (0.1.0 → 0.2.0): Content additions, audit finding incorporation, requirement refinements, edge case additions.
- **Major** (0.2.0 → 1.0.0): Approval milestone — document has passed audit and human review, ready to drive implementation.

### Tone Rules

1. **Declarative** — describe what IS, not what WAS or what WILL BE.
2. **No temporal references** to prior versions in the document body. "The system uses algorithm EPSILON" — never "the system used to use THETA but now uses EPSILON." Version tracking belongs exclusively in the changelog.
3. **Outcomes over prescriptions** — say what the system achieves, not how it achieves it. Implementation details belong in clearly marked Implementation Context sections.

### Markdown Compliance

- Fully compliant GitHub-flavored markdown.
- Heading hierarchy: one `#` title, sections are `##`, subsections are `###`.
- Tables, code blocks, and lists use standard GFM syntax.
- No HTML tags unless markdown cannot express the structure.

---

## The US/FR/SC Triad

The relationship between User Stories, Functional Requirements, and Success Criteria is the key to pre-spec quality. These three entity types form a traceability web that drives everything downstream — from `speckit.specify` to final acceptance testing.

### User Stories (US)

External, observable descriptions of what success looks like from the user's perspective. Each user story is a self-contained slice of functionality that can be developed, tested, and demonstrated independently.

- Written as narratives: "David asks X, PAM does Y, result is Z"
- Each US is independently testable — implementing just one US delivers observable value
- Priority-ordered (P1, P2, P3) by business value
- Describe the **experience**, not the mechanism
- Include **acceptance scenarios** in Given/When/Then format — these become the structured test cases that `speckit.specify` carries into the spec

**Quality signals:**
- A reader with no technical background can understand the story
- The story has a clear trigger, action, and observable outcome
- The story is bounded — it describes one coherent interaction, not a feature laundry list
- Each acceptance scenario has a concrete Given (state), When (action), and Then (outcome)

### Functional Requirements (FR)

Outcome-focused declarations of what the system must achieve.

- Each FR backs one or more US — it's the capability that makes a user story possible
- Describes WHAT the system achieves, not HOW
- No framework names, no file paths, no specific technologies
- Every FR must be testable — if you can't verify it, it's not a requirement
- Grouped by functional area or chunk

**Quality signals:**
- An FR can be verified without knowing the implementation
- An FR doesn't prescribe structure (no "manifest-only tool directory" or "uses package X")
- An FR that names a specific technology is a prescription leak — the technology belongs in Implementation Context

### Success Criteria (SC)

Measurable, verifiable outcomes that prove the system works.

- Map directly to US — each US has at least one SC
- Technology-agnostic — describe what can be observed, not how it's implemented
- Serve as acceptance tests for implementation
- Concrete enough that pass/fail is unambiguous

**Quality signals:**
- "SC-001: `/pa 'search Notion for LASSD status'` returns results from correct workspace" — observable, verifiable, unambiguous
- "SC-002: System is fast" — fails (not measurable)
- "SC-003: API responds in < 200ms" — fails in a pre-spec (implementation-specific; acceptable in a spec or plan)

### Traceability Rule

Every SC must trace to at least one US. Every US must be backed by at least one FR. Every FR must be verifiable by at least one SC.

```
US ←→ FR ←→ SC
```

Orphaned entities in any category signal a gap:
- **US without SC** — the story has no acceptance test
- **FR without US** — the requirement doesn't serve a user story (is it needed?)
- **SC without FR** — the success criterion has no backing requirement (what capability enables it?)
- **US without FR** — the story has no capability backing it (how does it work?)

### Supporting Entities

Beyond the core triad, pre-specs may include:

- **Edge Cases** — boundary conditions and error scenarios, each assigned to the FR/US they affect
- **Design Principles** — architectural constraints that apply across all FRs (e.g., "channel-agnostic delivery"). Design Principles serve as Constitution seed material — when `speckit.specify` or `speckit.plan` creates a project Constitution, these principles inform it. If a Constitution already exists (e.g., Phase 2+ of an existing project), Design Principles should not contradict it. During Stage 7, Design Principles travel with the chunk into `speckit.specify` as constraints, and forward into `speckit.plan` where they inform architectural decisions and Constitution alignment checks.
- **Implementation Context** — prescribed configurations, reference material, predecessor project artifacts. Explicitly marked as construction material for `speckit.plan`, not requirements for `speckit.specify`. Implementation Context travels with the chunk into Stage 7 so that `speckit.plan` has concrete starting material for tech stack and architecture decisions.
- **Key Entities** — domain objects referenced by FRs (e.g., Realm, Workspace, Conversation). Include Key Entities when the feature involves data that multiple FRs reference — defining entities early gives `speckit.specify` clearer input and produces a cleaner `data-model.md` during `speckit.plan`. Each entity should name its key attributes and relationships without prescribing implementation (no column types, no schema).

---

## Process Stages

### Stage 1: Pre-Spec Authoring

**Participants:** Human + Claude (Plan Mode)
**Input:** Project vision, user needs, domain knowledge
**Output:** `pre-spec.md` v0.1.0

Activities:
1. Human and Claude enter Plan Mode.
2. Brainstorm user stories — what does success look like from the user's perspective?
3. Derive functional requirements from user stories — what capabilities must exist?
4. Define success criteria with acceptance scenarios (Given/When/Then) — how do we prove each story works?
5. Identify edge cases, design principles, and implementation context.
6. Validate the US/FR/SC triad: every entity traces to at least one entity in each other category.
7. Write `pre-spec.md` following document standards.

**Exit criteria:** Pre-spec has at least one US, one FR, and one SC with clear traceability. Document follows frontmatter and tone standards.

### Stage 2: Pre-Spec Audit

**Participants:** Claude (task agent)
**Input:** `pre-spec.md`
**Output:** `pre-spec-audit.md` v0.1.0

Activities:
1. Claude spawns a task agent to audit the pre-spec.
2. Agent evaluates against the Pre-Spec Audit Criteria (see `audit-criteria.md`).
3. Agent produces a structured findings document with severity ratings and recommendations.

The audit is adversarial — its job is to find problems, not to validate. The audit criteria are derived from what makes a pre-spec digestible by `speckit.specify` AND from what makes the pre-spec sufficient to pre-answer every native speckit stop the pipeline will raise downstream (see companion document; PSA-11 SpecKit Stop Coverage is the criterion that operationalizes the fire-and-forget commitment).

**Exit criteria:** Audit document produced with findings, severity ratings, and actionable recommendations. Every PSA-11 unanswerable-stop finding is either resolved in Stage 3 refinement (intent added to the pre-spec) or explicitly deferred with rationale (and will need to be answered in the chunking doc at Stage 4).

### Stage 3: Pre-Spec Refinement

**Participants:** Human (reviewer) + Claude (editor)
**Input:** `pre-spec.md` + `pre-spec-audit.md`
**Output:** `pre-spec.md` v0.2.0+

Activities:
1. Human reviews audit findings.
2. Human directs which findings to apply, which to reject, and which to modify.
3. Claude updates `pre-spec.md` incorporating approved changes.
4. Pre-spec version bumped with changelog entries documenting each change.
5. Optionally iterate stages 2-3 for additional audit rounds.

**Exit criteria:** Human is satisfied the pre-spec is solid. All critical audit findings addressed. Pre-spec is ready for scope triage.

### Stage 3.5: Scope Triage

**Participants:** Claude (recommends) + Human (decides)
**Input:** Refined `pre-spec.md`
**Output:** Routing decision — **chunk** or **direct implementation**

After pre-spec refinement, Claude evaluates the pre-spec and recommends one of two paths:

- **Full Chunking** (Stages 4-7) — when the pre-spec has multiple independent deliverables, infrastructure gates between phases, or cross-cutting concerns that benefit from explicit dependency ordering.
- **Direct Implementation** (skip to Stage 7) — when the pre-spec is a single coherent unit that can be fed to `speckit.specify` as-is. Claude adds a brief critical path to the pre-spec's Implementation Context section (ordered steps, key dependencies, any setup prerequisites) and the pre-spec itself becomes the input to Stage 7.

**Signals favoring full chunking:**
- Multiple independent FR groups that could be developed and tested separately
- Infrastructure gates (a service must be running before dependent work begins)
- Parallel work tracks with a convergence point
- Scope large enough that a single `speckit.specify` pass would produce an unwieldy spec

**Signals favoring direct implementation:**
- All FRs form a single dependency chain or tightly coupled unit
- No infrastructure gates — everything builds on the existing environment
- The pre-spec reads like "one chunk" already
- Scope fits comfortably in a single `speckit.specify` → `speckit.implement` pass

Claude presents the recommendation with reasoning. Human confirms or overrides.

**Exit criteria:** Human has chosen a path. If direct implementation, the pre-spec's Implementation Context section contains the embedded critical path.

### Stage 4: Strategic Chunking

**Participants:** Human + Claude
**Input:** Refined `pre-spec.md`
**Output:** `pre-spec-strategic-chunking.md` v0.1.0

Activities:
1. Analyze the pre-spec to identify the critical path to full implementation.
2. Decompose into dependency-ordered implementation chunks.
3. For each chunk, define: scope, prior artifact boundaries, edge cases, behavioral criteria, testable success criteria, **speckit stop resolutions**, and what it unblocks.
4. Identify infrastructure gates between chunks.
5. Visualize the critical path (parallel tracks, serial dependencies, convergence points).
6. Distribute all pre-spec edge cases, behavioral criteria, and success criteria to owning chunks — nothing deferred to a final validation chunk unless unavoidable.
7. Add document-level tracking sections:
   - **Progress Tracker** — table of all chunks with status (pending/in progress/merged) for at-a-glance orientation.
   - **One-Time Setup Checklist** — pre-implementation prerequisites (pre-spec amendments, environment verification) as checkboxes.
   - **Infrastructure Gate Checklists** — concrete, verifiable checks as checkboxes between chunks (e.g., "Redis PING returns PONG", "MCP server responds").
   - **Per-Chunk Addenda** — chunk-specific validation items as checkboxes, covering quality gates that apply within or after each chunk's implementation.

The chunking thesis: each chunk must be a self-contained, testable, debuggable unit fed independently to `speckit.specify`. Monolithic specs produce monolithic code.

The chunking document is also a living progress tracker. During multi-chunk implementations — especially across concurrent projects — the Progress Tracker and checklists provide session recovery: open the chunking document to know where you are, what's done, and what's next.

Every Progress Tracker or checklist update is a patch-version bump with a changelog entry. Living-tracker edits do not skip the versioning discipline; they exercise it at patch granularity.

**Progress Tracker authoring convention.** The Progress Tracker is a contract between the chunking doc and the runner launch pre-flight (see "Propagation Through chunk-runner"). The pre-flight parses the table to find the named chunk's row and confirm its status. The contract:

- **Column order:** `Chunk | Title | FRs | SCs | Status` — Status is the rightmost column. Pre-flight parsers treat the last cell of each row as the status field; any other ordering causes false launch refusal (the parser will read the SC list as a status).
- **Status values:** capitalized `Pending` or `In Progress` for chunks awaiting a run; the runner writes `Implementation Complete — Awaiting Merge` on its post-implementation reconciliation pass.
- **One row per chunk**, plus the header and separator rows. No merged cells, no nested tables.
- **Chunk ID format:** three-digit zero-padded (`001`, `002`, …, `099`, `100`+ as needed). The chunk-runner uses the chunk ID literally to construct the feature branch name (`<spec-dir-basename>/chunk-<id>`); single-digit IDs would produce ambiguous branch ordering and inconsistent column widths if a project crosses ten chunks. Chunk-scoped contract IDs (e.g., `CR001-NNN` for Chunk 001's integration contracts, `CSC001-NNN` for Chunk 001's chunk-specific success criteria) inherit the same three-digit prefix.

**Per-chunk `### Speckit Stop Resolutions` subsection.** For each chunk, an explicit subsection enumerates the speckit stops (from the inventory in [`audit-criteria.md`](audit-criteria.md)) whose resolution depends on chunk-specific intent, and carries the authorized answer for each. Stops resolvable from the pre-spec alone need not be repeated; stops that need chunk-level framing are answered here. This is the single home for chunk-level stop resolutions across every pipeline stage (clarify, plan, tasks); the chunk-runner's stage prompts consult it via their autonomous resolution ladders.

The subsection is additive — it lives inside the `## Chunk <id>` blob, which the runner already passes verbatim to `/speckit.specify`, which carries the resolutions forward into spec.md and downstream artifacts. No runner format change. No new parseable section.

Cross-chunk defaults (e.g., language choice, testing philosophy that applies to every chunk) live in the pre-spec's Implementation Context, not in per-chunk resolutions. Every chunk inherits them via the pre-spec path already in every stage prompt's context.

Example shape:

```markdown
### Speckit Stop Resolutions

- **Plan-stage / verification-instrument choice.** Use existing conventions: atomic commits + `rg` one-liner inspection. Bespoke scanners / AST analyzers are out of scope for this chunk (see freeze-line in Scope).
- **Clarify-stage / per-consumer coverage.** Not required; the writer-side validator is the policy boundary. Consumers that don't comply fail at the writer, not at a per-consumer test.
- **Plan-stage / testing strategy.** Contract-test the writer's schema + frontmatter enforcement. No per-consumer integration tests in this chunk.
```

**Deprecated: `## Plan-Stage Decisions Across All Chunks`.** Prior revisions of this process used a cross-all section with per-chunk bullets for plan-stage decisions. That section is superseded by per-chunk `### Speckit Stop Resolutions`. New chunking docs do not author it. Existing chunking docs that still carry it remain compatible — the runner's parse of that section is optional and tolerates absence.

**Exit criteria:** Every US, FR, SC, and edge case from the pre-spec maps to at least one chunk. Critical path is visualized. Infrastructure gates are defined with concrete, verifiable checks. Tracking sections (Progress Tracker, setup checklist, gate checklists, per-chunk addenda) are populated. Every chunk has a `### Speckit Stop Resolutions` subsection answering the chunk-level stops called out by PSA-11 at the Stage 5 audit.

### Stage 5: Chunking Audit

**Participants:** Claude (task agent)
**Input:** `pre-spec-strategic-chunking.md` + `pre-spec.md`
**Output:** `pre-spec-strategic-chunking-audit.md` v0.1.0

Activities:
1. Claude spawns a task agent to adversarially audit the chunking against the pre-spec.
2. Agent evaluates against the Chunking Audit Criteria (see `audit-criteria.md`).
3. Agent challenges chunk boundaries, dependency claims, edge case assignments, and infrastructure gates.
4. Agent verifies PSA-11 SpecKit Stop Coverage at chunk granularity: for each chunk, every inventoried stop either has a pre-spec-level answer the runner can reach or an explicit `### Speckit Stop Resolutions` entry.
5. Agent produces findings document.

**Exit criteria:** Audit document produced with structural findings and recommendations. Any chunk with unanswered inventoried stops is flagged — the fix is to enrich `### Speckit Stop Resolutions` (or, if the gap is pre-spec-wide, to loop back and amend the pre-spec).

### Stage 6: Chunking Refinement

**Participants:** Human (reviewer) + Claude (editor)
**Input:** `pre-spec-strategic-chunking.md` + audit findings
**Output:** `pre-spec-strategic-chunking.md` v0.2.0+ (or v1.0.0 if approved)

Activities:
1. Human reviews chunking audit findings.
2. Human directs changes or approves recommendations.
3. Claude updates chunking document.
4. Version bumped with changelog entries.
5. If audit reveals pre-spec gaps, those are written back to `pre-spec.md` as well (version bump).

**Exit criteria:** Human approves the chunking plan. All critical findings addressed. Stage 7 may now provision tracking issues and launch chunks.

### Stage 7: Implementation

**Participants:** Human + Claude (per chunk, or once for direct implementation)
**Input:** Approved `pre-spec.md` + approved `pre-spec-strategic-chunking.md` (chunked path), OR approved `pre-spec.md` alone (direct path)
**Output:** Working implementation

#### Chunked Path (via Stages 4-6)

**Pre-launch — Issue provisioning.** Before invoking chunk-runner for the first chunk, create the project's Epic-equivalent issue tracking the full pre-spec deliverable. Each chunk gets a child issue under the Epic, created when that chunk's runner launches. The runner consumes the chunk's issue ID as its tracking target; the Epic receives a closure-line append on each chunk merge.

Activities (per chunk):
1. Invoke `speckit.specify` with the chunking document and chunk identifier: `/speckit.specify docs/pre-spec-strategic-chunking.md Chunk NNN`. The specify stage reads the chunk section, follows US/FR/SC references back to the pre-spec, and derives the spec. No separate extraction step is needed — the chunking document scoped by chunk identifier IS the mini-pre-spec.
2. Continue through the speckit pipeline: `speckit.clarify` → `speckit.plan` → `speckit.tasks` → `speckit.analyze` → `speckit.implement`. The `speckit.analyze` step is a read-only cross-artifact consistency check — it detects coverage gaps, terminology drift, and requirement/task misalignment before implementation begins. Critical findings from analyze must be resolved before proceeding to implement.
3. Validate chunk success criteria.
4. Pass infrastructure gate (if applicable) before proceeding to dependent chunks.

The chunking document carries per-chunk: scope, prior artifact boundaries, edge cases, behavioral criteria, testable success criteria, and what it unblocks. Combined with the pre-spec (source of truth for full US/FR/SC detail), this gives `speckit.specify` self-contained input per chunk — not the full pre-spec with an "only build this part" caveat.

**Post-Implementation Reconciliation.** Once `superb.verify` passes, the chunk has a small but real bookkeeping epilogue before it is ready for the human merge review. The auto-chunk-runner automates this loop end-to-end; if you are running the pipeline manually (or the runner stalls mid-epilogue), the steps are:

1. **Spec-status flip commit.** Commit the `superb.verify`-driven status flip on `specs/<chunk-spec-dir>/spec.md`. Canonical message: `docs(<spec-slug>): spec status → Verified after superb_verify`.
2. **Chunking-doc rewrite.** Update the chunking-doc Progress Tracker row for this chunk to `Implementation Complete — Awaiting Merge`. Append a per-chunk addendum capturing the run signature: attempts used, stall count, per-stage durations, FR/SC/test counts, and any gate identifications. Bump the chunking-doc patch version.
3. **As-built reconciliation commit.** Commit the chunking-doc edits. Canonical message: `docs(<spec-slug>/chunk-<id>): as-built reconciliation from auto-chunk-runner run <run-id>`.
4. **Push the feature branch.** Push to origin so the human reviewer can compare. The runner retries push once on transient remote failure.
5. **Epic-bead closure-line append.** Append an FR-017-shaped note to the project's Epic-equivalent issue: chunk completed, run id, attempts, addendum link, merge status pending.
6. **Heartbeat-bead final line.** Write the closing `COMPLETE at <ts>` line to the per-run heartbeat bead (created at runner launch).
7. **Celebration Talk + voice cast.** Optional notification surface. Best-effort; failure does not affect the reconciliation result.

These steps are individually idempotent — re-running any one of them on a partially-completed branch is a no-op. If a transient failure interrupts the loop (e.g. an `index.lock` race), the runner's checkpoint mechanism resumes from the failed step on the next monitor tick. Manual completion follows the same step list in order.

The reconciliation output: a feature branch on origin with two extra commits past the `superb.verify` HEAD (spec-status flip + as-built reconciliation), a chunking doc that reflects what was actually built, and a closure trail through the Epic and heartbeat beads. Merge into the integration target is a separate human decision and is NOT part of this loop — the auto-chunk-runner explicitly never merges.

#### Direct Path (via Stage 3.5)

Activities:
1. Invoke `speckit.specify` with the pre-spec directly: `/speckit.specify docs/pre-spec.md`. The pre-spec IS the spec input — its Implementation Context section carries the embedded critical path.
2. Continue through the speckit pipeline: `speckit.clarify` → `speckit.plan` → `speckit.tasks` → `speckit.analyze` → `speckit.implement`.
3. Validate success criteria.

---

## Artifact Inventory

| Document | Purpose | Produced By | When |
|----------|---------|-------------|------|
| `pre-spec.md` | Feature/phase specification | Human + Claude (Stage 1) | First, then refined |
| `pre-spec-audit.md` | Quality analysis of pre-spec | Claude Agent (Stage 2) | After pre-spec v0.1.0 |
| `pre-spec-strategic-chunking.md` | Implementation chunking plan | Human + Claude (Stage 4) | After pre-spec is solid |
| `pre-spec-strategic-chunking-audit.md` | Adversarial analysis of chunking | Claude Agent (Stage 5) | After chunking v0.1.0 |

All four documents are first-class versioned artifacts. Each carries semver frontmatter with changelog.

## Artifact Relationships

```
pre-spec.md (source of truth)
   |
   +---> pre-spec-audit.md (examines pre-spec)
   |       |
   |       +---> pre-spec.md (v+1, audit findings applied)
   |
   +---> pre-spec-strategic-chunking.md (derived from pre-spec)
           |
           +---> pre-spec-strategic-chunking-audit.md (examines chunking)
                   |
                   +---> pre-spec-strategic-chunking.md (v+1, findings applied)
                   |
                   +---> pre-spec.md (v+1, if audit reveals pre-spec gaps)
```

The pre-spec is always the source of truth. The chunking is derived from the pre-spec and must remain consistent with it. If the chunking audit reveals pre-spec gaps, those gaps are fixed in the pre-spec first — the fix flows forward into the chunking, not the other way around.

---

## Applying This Process

### New Project

1. Create the project directory structure.
2. Start at Stage 1 — brainstorm the full-system pre-spec.
3. Run all seven stages.
4. Implement chunk by chunk via Stage 7.

### New Phase of an Existing Project

1. The pre-spec scopes the new phase, referencing the prior phase as completed context.
2. The standalone boundary principle applies: the new phase extends, not modifies.
3. Start at Stage 1 with phase-specific vision.
4. Run all seven stages.

### Re-Chunking an Existing Pre-Spec

If a pre-spec is already solid but needs new chunking (e.g., requirements changed, or the first chunking was rejected):

1. Skip Stages 1-3 (pre-spec already refined).
2. Start at Stage 4 with the refined pre-spec.
3. Run Stages 4-7.

---

## Companion Document

The audit criteria referenced in Stages 2 and 5 are defined in [`audit-criteria.md`](audit-criteria.md). That document provides the specific signals, anti-patterns, and quality checks used by the audit agents.
