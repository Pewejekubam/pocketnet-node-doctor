---
version: 0.2.0
status: draft
created: 2026-02-23
last_modified: 2026-04-24
authors: [pewejekubam, claude]
related: process.md
changelog:
  - version: 0.2.0
    date: 2026-04-24
    summary: PSA-11 SpecKit Stop Coverage + SpecKit Stop Inventory catalog — operationalizes the fire-and-forget commitment in process.md v0.3.0
    changes:
      - "PSA-11 added: every native speckit stop must be pre-answerable from the pre-spec (or chunking doc's per-chunk Speckit Stop Resolutions)"
      - "PSA-06 strengthened: scope declarations must be visible at the speckit stage that will encounter them, not just declared in the abstract (Chunk 3b lesson)"
      - "SpecKit Stop Inventory appendix: concrete catalog of the decision points each /speckit.* stage raises, with resolution-ladder mapping"
      - "CSA-11 added: chunking-level variant of PSA-11 — every chunk answers its inventoried stops via pre-spec inheritance or explicit Speckit Stop Resolutions"
  - version: 0.1.0
    date: 2026-02-23
    summary: Initial audit criteria — pre-spec and chunking audit principles extracted from PAM practice
    changes:
      - "10 pre-spec audit criteria derived from speckit.specify input compatibility"
      - "10 chunking audit criteria derived from Phase-01 adversarial audit practice"
      - "Severity framework: CRITICAL, HIGH, MEDIUM, LOW"
      - "Audit document structure template"
---

# Pre-Spec Build Audit Criteria

## Purpose

This document defines the audit criteria used at the two audit gates in the Pre-Spec Build Process (see [`process.md`](process.md)). The criteria are designed to maximize the quality of input to the `speckit.specify` → `speckit.implement` pipeline.

The audit criteria serve two audiences:
1. **Claude agents** spawned to perform adversarial audits — they use these criteria as evaluation standards.
2. **Human reviewers** assessing audit findings — they use the severity framework to prioritize which findings to address.

---

## Severity Framework

All audit findings are assigned a severity:

| Severity | Definition | Action Required |
|----------|-----------|-----------------|
| **CRITICAL** | Blocks `speckit.specify` from producing correct output. Missing traceability, contradictory requirements, or prescription that will generate wrong code. | Must fix before proceeding. |
| **HIGH** | Degrades `speckit.specify` output quality. Vague requirements that produce undertested code, inherited capabilities treated as requirements, scope gaps. | Should fix before proceeding. |
| **MEDIUM** | Quality improvement. Terminology drift, missing edge cases, suboptimal structure. | Fix if time permits. |
| **LOW** | Stylistic or organizational. Formatting, section ordering, minor redundancy. | Optional. |

---

## Part 1: Pre-Spec Audit Criteria

These criteria evaluate whether a pre-spec will produce good output when fed to `speckit.specify`. They are derived from the speckit pipeline's input expectations and from patterns observed in successful vs. problematic implementations.

### PSA-01: Outcome Focus

**What to check:** FRs describe WHAT the system achieves, not HOW it achieves it.

**Anti-patterns:**
- FR names a specific package, library, or framework
- FR prescribes file paths or directory structure
- FR specifies an API endpoint format or database schema
- FR says "using X" or "via Y" where X/Y are implementation choices
- FR negatively constrains ("no helper scripts") — telling speckit what NOT to build

**Why it matters:** `speckit.specify` treats FR content as requirements to verify and implement. Implementation details in FRs cause speckit to generate tasks for things that should be design decisions in `speckit.plan`, producing bloated plans and unnecessary work.

**Severity:** CRITICAL if multiple FRs are prescriptive. HIGH for isolated instances.

### PSA-02: US/FR/SC Traceability

**What to check:** Every US has at least one SC. Every FR backs at least one US. Every SC verifies at least one FR. No orphans in any category.

**Anti-patterns:**
- US describes a scenario with no success criterion to prove it works
- FR exists but no US describes when a user would need that capability
- SC tests something that no FR declares as a system capability
- US has an FR backing it but that FR has no verifiable SC

**Why it matters:** Orphaned entities create gaps. A US without an SC means no acceptance test. An FR without a US means speckit generates code for a capability nobody needs. An SC without an FR means speckit has no requirement to drive the implementation.

**Severity:** CRITICAL for US without SC (untestable scenarios). HIGH for other orphans.

### PSA-03: Testability

**What to check:** Every FR and SC can be verified without knowing the implementation.

**Anti-patterns:**
- Vague adjectives: "robust", "intuitive", "fast", "scalable", "secure" without measurable criteria
- Subjective conditions: "user-friendly interface", "clean architecture"
- Unmeasurable outcomes: "system handles errors gracefully" (what does gracefully mean?)

**Why it matters:** `speckit.specify` generates spec requirements from FRs. Vague FRs produce vague specs, which produce vague test criteria, which produce untestable code. The implement stage cannot verify what it cannot measure.

**Severity:** HIGH for FRs. CRITICAL for SCs (they ARE the acceptance tests).

### PSA-04: Prescription Leaks

**What to check:** Implementation details that have migrated from Implementation Context into FRs, USs, or SCs.

**Anti-patterns:**
- Package names in FRs (e.g., "@notionhq/notion-mcp-server")
- IP addresses or ports in FRs (e.g., "198.51.100.22:9239")
- File paths in FRs (e.g., "manifest-only tool directory")
- Architecture decisions embedded in FRs (e.g., "webhook-based handler")
- Capability inventories masquerading as requirements (listing what an adopted tool provides as if they were things to build)

**Why it matters:** Prescription in FRs causes `speckit.specify` to treat design decisions as requirements. This cascades: `speckit.plan` designs around the prescription instead of evaluating alternatives, `speckit.tasks` generates tasks to implement what's already decided, and `speckit.implement` does unnecessary work.

**Severity:** HIGH. Prescription leaks are the most common pre-spec quality issue.

### PSA-05: Inherited Capabilities vs. Requirements

**What to check:** When the pre-spec adopts an existing tool, library, or service, the distinction between capabilities that come for free and capabilities that must be built.

**Anti-patterns:**
- Listing an adopted MCP server's built-in capabilities as FRs
- Treating "search works" as a requirement when it's inherent to the tool selection
- Generating verification tasks for functionality that exists by default

**Why it matters:** `speckit.specify` treats every FR as something to spec, plan, and implement. If an FR describes an inherited capability, speckit generates unnecessary work. The correct treatment: inherited capabilities need smoke-test verification (in Implementation Context), not full spec-plan-implement cycles (in FRs).

**Severity:** MEDIUM to HIGH depending on volume. A few inherited capabilities in FRs is medium. An entire FR section that's really a capability inventory is high.

### PSA-06: Scope Clarity

**What to check:** The pre-spec explicitly bounds what's in scope, what's out of scope, and what's deferred — AND the scope declarations are stated at a granularity the downstream speckit stages will actually consume.

**Anti-patterns:**
- Open-ended feature descriptions without explicit boundaries
- "And more" or "etc." in feature lists
- Deferred items not documented (they resurface later as surprises)
- Scope defined by implication rather than declaration
- Freeze-lines declared in prose at the pre-spec level but silent on the specific plan-stage or tasks-stage decision they should govern (the 3b failure mode — the freeze-line existed but did not name the verification instrument decision `speckit.plan` would face)

**Why it matters:** Unbounded scope produces unbounded specs. `speckit.specify` will attempt to generate requirements for everything implied. Explicit deferral statements prevent scope creep and set clear expectations. When a freeze-line exists but doesn't map to a specific downstream decision, `speckit.plan` still sees the decision as open and resolves it in context — often in a direction that violates the freeze-line's intent. Scope declarations must be actionable at the stage that will act on them.

**Severity:** HIGH if scope is meaningfully ambiguous. HIGH if a declared freeze-line has no corresponding pre-spec or chunking-doc entry covering the specific speckit stop it must govern. MEDIUM for minor boundary issues.

### PSA-07: Edge Case Distribution

**What to check:** Edge cases are identified and assigned to the functional areas (and later, chunks) they affect.

**Anti-patterns:**
- Edge cases listed in a single section with no connection to specific FRs or USs
- Edge cases that span multiple FRs without explicit ownership
- Missing edge cases for error paths, boundary conditions, or failure modes

**Why it matters:** During chunking (Stage 4), edge cases are distributed to owning chunks. If they aren't connected to specific FRs, they get lost. If `speckit.specify` doesn't see an edge case in the chunk's mini-pre-spec, it won't generate code that handles it.

**Severity:** MEDIUM. Edge case gaps are quality issues, not blockers.

### PSA-08: Declarative Tone Compliance

**What to check:** The document body contains no temporal references to prior versions.

**Anti-patterns:**
- "Previously, the system used X, but now uses Y"
- "In v0.3.0 we changed the approach from A to B"
- "The old architecture was replaced with..."
- Phrases like "we decided to", "after discussion", "upon review"

**Why it matters:** `speckit.specify` reads the pre-spec as a statement of current requirements. Temporal references create confusion about what the current state actually is. Version history belongs in the changelog.

**Severity:** LOW for isolated instances. MEDIUM if pervasive.

### PSA-09: NEEDS CLARIFICATION Hygiene

**What to check:** Unresolved decision points are bounded and managed.

**Anti-patterns:**
- More than 3 unresolved [NEEDS CLARIFICATION] markers
- Markers for questions that have reasonable defaults
- Markers in SCs (acceptance tests must be definite)
- Markers that should be deferred to `speckit.plan` rather than resolved in the pre-spec

**Why it matters:** `speckit.specify` can handle a small number of clarification markers — `speckit.clarify` exists for this purpose. But excessive markers indicate the pre-spec isn't ready for the pipeline. SCs with markers are especially problematic — you can't test against an undefined criterion.

**Severity:** CRITICAL for markers in SCs. HIGH for more than 3 total. MEDIUM for 1-3.

### PSA-10: Implementation Context Separation

**What to check:** Reference material from predecessor projects, proven configurations, and prescribed implementation details are housed in a clearly marked Implementation Context section, not in FRs or USs.

**Anti-patterns:**
- Predecessor project configurations embedded in FRs
- "Adopt this proven pattern" language in requirement sections
- Auth patterns, token references, or infrastructure details in FRs
- Configuration snippets (JSON, YAML) in FR sections

**Why it matters:** Implementation Context is valuable — it gives `speckit.plan` concrete starting material. But `speckit.specify` treats everything in FRs as requirements to formalize. Implementation Context in the wrong section produces specs that conflate "what we chose" with "what we need."

**Severity:** HIGH. This is the prescription leak variant specific to predecessor projects.

### PSA-11: SpecKit Stop Coverage

**What to check:** Every decision point the speckit pipeline will predictably raise for this pre-spec is pre-answerable from the pre-spec itself (or, at chunking time, from the chunking doc's per-chunk `### Speckit Stop Resolutions`).

The inventory of decision points is concrete — see the **SpecKit Stop Inventory** appendix at the end of this document. For each inventoried stop type, the auditor asks: "When the runner's stage prompt walks its autonomous resolution ladder (pre-spec → chunking doc → precedent → defensive default), will the top rung hold, or will the prompt fall through to a defensive default or Known-Issues entry?"

A fall-through is a thin-intent defect. At runtime, it produces either a halt (best case), a defensive default that changes the chunk's scope without human ratification (drift), or an inflated plan (the 3b failure mode).

**Anti-patterns:**
- Clarify-stage stop: a referenced FR has an ambiguous term ("compliance", "verification", "validation") with no glossary entry or pre-spec explanation pinning its meaning — clarify will surface a question and defensive-default to a narrower reading that may or may not match intent.
- Plan-stage stop: a chunk introduces a new verification / instrumentation / testing need with no pre-declared answer — plan will resolve in context, potentially inflating scope (Chunk 3b).
- Plan-stage stop: a chunk's FR implies a technology choice (persistence, concurrency, integration pattern) the pre-spec neither names nor constrains — plan will pick one, possibly mismatched to project conventions.
- Tasks-stage stop: an FR or SC has no obvious task decomposition and the pre-spec offers no granularity guidance — tasks may over- or under-decompose.
- Superb.review stop: pre-spec has multiple `[NEEDS CLARIFICATION]` markers that downstream clarify will forward as Known Issues — the pipeline will halt at superb.review when it should have halted at pre-spec audit.

**Why it matters:** `chunk-runner` executes fire-and-forget; no inter-phase HITL gate exists. Every stop that isn't pre-answered from authored intent is a point at which the pipeline either halts (visible, recoverable) or drifts (invisible at runtime, expensive to revert). The pre-spec audit is the last opportunity to catch thin intent before drift materializes.

**Severity:** CRITICAL for unanswered plan-stage stops that could reshape scope (instrumentation, testing strategy, integration pattern) — this is the Chunk 3b class. HIGH for unanswered clarify-stage stops. MEDIUM for unanswered tasks-stage stops (these usually halt visibly rather than drift silently).

---

## Part 2: Chunking Audit Criteria

These criteria evaluate whether a strategic chunking plan will produce successful implementation when each chunk is fed to `speckit.specify`. They are derived from adversarial audit practice refined during PAM Phase-01.

### CSA-01: Trojan Horse Detection

**What to check:** Chunks that bundle distinct concerns with different failure modes.

**Signals:**
- A chunk contains both a tool (API interaction) and its consumer (workflow/handler)
- A chunk introduces both new infrastructure (persistent process, new auth pattern) and business logic
- A chunk has more than 3 distinct deliverable types (manifest, scripts, handler, workflow, skill)
- Debugging one component requires the other to work correctly

**The test:** If component A fails, can component B be debugged independently? If not, they should be separate chunks.

**Why it matters:** Monolithic chunks produce monolithic speckit passes. When something breaks, you debug the entire chunk instead of isolating the failure. Phase-01's Chunk 4 split (evernote tool vs. evernote workflows) proved this pattern.

**Severity:** HIGH if the bundled concerns have materially different failure modes. MEDIUM if they're closely related.

### CSA-02: Dependency Accuracy

**What to check:** Declared dependencies are real. No hidden dependencies exist. Reordering would break something.

**Signals:**
- Chunk B claims independence from Chunk A, but B's deliverables reference A's outputs
- A chunk "reuses" artifacts from a prior chunk but doesn't declare the dependency
- Parallel tracks that actually share state or configuration

**The test:** Could Chunk B be built by a team that has never seen Chunk A's output? If not, there's a dependency.

**Why it matters:** False independence claims lead to parallel work that fails at integration. False dependencies prevent parallelization that could save time.

**Severity:** CRITICAL for hidden dependencies. HIGH for false independence claims.

### CSA-03: Edge Case Distribution

**What to check:** Every pre-spec edge case is assigned to exactly one chunk.

**Signals:**
- Pre-spec edge cases not mentioned in any chunk
- Edge cases assigned to a chunk that doesn't own the relevant FR
- Edge cases split across chunks without clear ownership

**The test:** For each pre-spec edge case, identify the one chunk where `speckit.specify` will see it. If no chunk owns it, it's lost.

**Why it matters:** `speckit.specify` only sees the mini-pre-spec for each chunk. If an edge case isn't in the mini-pre-spec, it won't be in the spec, won't be in the plan, won't be in the tasks, and won't be in the implementation.

**Severity:** HIGH for edge cases affecting error handling or security. MEDIUM for others.

### CSA-04: Behavioral Criteria Distribution

**What to check:** Cross-cutting behavioral rules (journaling, CANI, error handling patterns) are validated at the earliest possible chunk, not batched to a final validation chunk.

**Signals:**
- Behavioral criteria (e.g., "log milestones to journal") listed only in the final chunk
- First workflow chunk doesn't include behavioral validation
- Cross-cutting concerns treated as "we'll test it later"

**The test:** Which is the first chunk that exercises the behavioral rule? That chunk must include a testable criterion for it.

**Why it matters:** Deferred validation means the first time a behavioral rule is tested, five chunks of code may need fixing. Validating early catches problems when the blast radius is small.

**Severity:** HIGH if behavioral rules affect all subsequent chunks. MEDIUM otherwise.

### CSA-05: Infrastructure Gate Completeness

**What to check:** Each infrastructure gate has concrete, verifiable checks — not aspirational statements.

**Anti-patterns:**
- "Verify infrastructure works" (not a check — works how?)
- "Ensure API is accessible" (accessible from where? returning what?)
- Gates without specific commands or observable outcomes
- Missing gates between chunks that introduce new infrastructure

**Good patterns:**
- "Redis PING returns PONG" — concrete, verifiable, pass/fail
- "Send message API returns 200 and message appears in conversation" — observable outcome
- "MCP tool inventory lists 'notion' with 5 tools" — specific, countable

**Severity:** HIGH for missing gates. MEDIUM for vague gates.

### CSA-06: Prior Artifact Boundaries

**What to check:** Each chunk clearly declares what exists (don't recreate), what's new (this chunk's deliverables), and what's updated (modifications to existing files).

**Anti-patterns:**
- Chunk doesn't list existing artifacts — speckit may regenerate them
- "Updated artifacts" section is vague ("CLAUDE.md updates")
- New artifacts described conceptually rather than as file paths
- Handler or infrastructure described as a concept without a provisional location

**Why it matters:** `speckit.specify` needs to know its deliverables. If it doesn't know what already exists, it may generate conflicting files. If it doesn't know what to create, the scope is ambiguous.

**Severity:** HIGH for missing boundaries. MEDIUM for vague boundaries.

### CSA-07: Critical Path Accuracy

**What to check:** The dependency graph is correct. Parallel tracks are truly independent. Serial dependencies are real.

**Signals:**
- Critical path diagram contradicts chunk dependency declarations
- "Parallel tracks" that share configuration files or state
- Convergence points that don't actually need all inputs
- Linear chains where some chunks could be parallelized

**The test:** Trace each arrow in the critical path diagram. Does the target chunk actually require the source chunk's output?

**Severity:** HIGH for incorrect parallel/serial claims. MEDIUM for suboptimal ordering.

### CSA-08: Per-Chunk Testability

**What to check:** Each chunk has its own testable success criteria. No chunk defers all validation to a later chunk.

**Anti-patterns:**
- "Validated in Chunk N" appearing for criteria that could be tested earlier
- A chunk with scope but no success criteria
- Success criteria that require subsequent chunks to be complete

**The test:** After completing just this chunk and nothing else, can you run its success criteria and get a pass/fail result?

**Why it matters:** Untestable chunks accumulate validation debt. The first time you discover a problem is when everything comes together — and by then the blast radius is maximal.

**Severity:** CRITICAL for chunks with no testable criteria. HIGH for chunks with deferred-only criteria.

### CSA-09: Pre-Spec Coverage

**What to check:** Every US, FR, SC, and edge case from the pre-spec maps to at least one chunk.

**The test:** Build a coverage matrix:

| Pre-Spec Entity | Chunk | Status |
|-----------------|-------|--------|
| US-001 | Chunk 2 | Covered |
| FR-003 | ??? | GAP |
| SC-005 | Chunk 4b | Covered |

Any GAP entry means something falls through the cracks.

**Severity:** CRITICAL for uncovered USs or SCs. HIGH for uncovered FRs. MEDIUM for uncovered edge cases.

### CSA-10: Scope Discipline

**What to check:** Chunks don't introduce requirements beyond the pre-spec.

**Signals:**
- A chunk's scope includes deliverables not traceable to any pre-spec FR
- Edge cases added in the chunking that aren't in the pre-spec
- "Nice to have" additions that weren't in the original scope

**Why it matters:** If the chunking reveals a genuine gap, that gap should be flagged as a pre-spec amendment — fixed in the pre-spec and then reflected in the chunking. Silently filling gaps in the chunking creates divergence between the pre-spec (source of truth) and the implementation plan.

**Severity:** HIGH for scope additions that change the implementation. MEDIUM for minor additions.

### CSA-11: Per-Chunk SpecKit Stop Coverage

**What to check:** Each chunk answers its inventoried speckit stops — either by inheritance from the pre-spec (the stop is resolved at the pre-spec layer, and the chunk doesn't need to repeat it) or by an explicit `### Speckit Stop Resolutions` entry inside the chunk section.

This is PSA-11 applied at chunk granularity. At Stage 5, the audit walks each chunk against the SpecKit Stop Inventory and asks: "If the runner starts this chunk tomorrow, will every stop resolve from the top rung of the autonomous ladder, or will a fall-through occur?"

**Signals:**
- A chunk introduces verification / testing / instrumentation work whose choice is not pre-spec-governed AND has no `### Speckit Stop Resolutions` entry pinning the choice (the 3b pattern).
- A chunk references a concept (e.g., "per-consumer compliance") without stating whether that concept is in-scope for the chunk or deferred — clarify will ask; with no chunk-level answer, it will defensive-default.
- A chunk's `Plan-Stage Decisions Across All Chunks` bullet is empty AND the chunk introduces plan-stage decisions the pre-spec didn't resolve.

**The test:** For each chunk, list the inventoried stops. For each stop, cite the pre-spec passage OR the `### Speckit Stop Resolutions` entry that pre-answers it. Any stop with neither citation is a CSA-11 finding.

**Severity:** CRITICAL for plan-stage stops that could reshape scope (the 3b class). HIGH for clarify-stage stops. MEDIUM for tasks-stage stops.

---

## Audit Document Structure

Audit documents follow this structure:

```markdown
---
version: 0.1.0
title: "Adversarial Analysis: [Document Name] v[X.Y.Z]"
type: audit
status: draft
related: [audited document filename]
---

# Adversarial Analysis: [Document Name] v[X.Y.Z]

## Finding 1: [Concise Title]

[Description of the problem. Quote relevant sections.]

[Explain why it matters — connect to speckit pipeline impact.]

**Severity:** [CRITICAL | HIGH | MEDIUM | LOW]
**Criteria:** [PSA-XX or CSA-XX]
**Recommendation:** [Specific, actionable fix]

## Finding 2: ...

[Repeat for each finding]

## Summary: What's Strong

[Acknowledge what works well — audits are adversarial but fair]

## Summary: What Needs Fixing

- **[Finding title]** — [one-line summary] (severity)
- ...

## Assessment

[Overall readiness assessment: ready to proceed, needs revision, or needs major rework]
```

Findings are ordered by severity (CRITICAL first), then by document order. Each finding references the specific audit criterion (PSA-XX or CSA-XX) it violates.

---

## Appendix: SpecKit Stop Inventory

The inventory is the concrete catalog PSA-11 and CSA-11 evaluate against. It enumerates the decision points each `/speckit.*` stage raises and names the resolution ladder the runner's stage prompts walk. The inventory is derived from the chunk-runner stage prompts in [`tools/chunk-runner/prompts/`](../../tools/chunk-runner/prompts/) — the authoritative source for what each stage actually prompts for.

The pre-spec audit (PSA-11) and chunking audit (CSA-11) use this inventory as a checklist: for each inventoried stop applicable to the chunk, verify a top-rung ladder answer exists.

### Specify-stage stops

`/speckit.specify` consumes the chunk blob and produces `spec.md`. It is not a question-asking stage; its output stops are ambiguity markers carried forward into `spec.md` as `[NEEDS CLARIFICATION]` entries.

| Stop | Resolution ladder | Pre-spec answer shape |
|---|---|---|
| Ambiguous FR term | Clarify-stage will attempt to resolve | Pre-spec glossary or FR-body pinning of the term |
| Unspecified acceptance scenario for a US | Clarify-stage will ask | Given/When/Then entries in the US |
| SC that isn't measurable | Will cascade to clarify, plan, tasks | Quantified or binary-observable SC wording |

A clean specify stage produces a `spec.md` with zero or very few `[NEEDS CLARIFICATION]` markers. Excessive markers is evidence of thin pre-spec authoring and triggers PSA-09 alongside PSA-11.

### Clarify-stage stops

`/speckit.clarify` asks up to 5 targeted questions. The chunk-runner prompt's autonomous resolution ladder: **pre-spec text → chunking doc text → cross-chunk vocabulary → prior merged chunks → defensive default (with Known-Issues entry if fall-through would change scope).**

| Stop class | Example question | Top-rung answer |
|---|---|---|
| FR term ambiguity | "What does 'compliance' mean for FR-N?" | Pre-spec glossary entry or FR-body definition |
| SC verifiability | "How is SC-M observed?" | Pre-spec SC wording with observable outcome |
| Scope boundary | "Is X in-scope for this chunk?" | Pre-spec scope statement or chunking-doc `### Speckit Stop Resolutions` entry |
| Edge-case omission | "What happens when Y?" | Pre-spec Edge Case entry assigned to the FR |
| Terminology drift | "Is term A the same as term B?" | Pre-spec glossary or consistent single-term use |

Fall-through to defensive default is permitted when the chunk remains scope-stable; fall-through to Known Issues is evidence of thin intent (PSA-11 / CSA-11 finding).

### Plan-stage stops

`/speckit.plan` resolves plan-layer decisions. The chunk-runner prompt's autonomous resolution ladder: **pre-declared default (chunking doc § Plan-Stage Decisions) → precedent from prior merged chunks → pre-spec constraint → narrower/more-testable/more-conservative.**

| Stop class | Example decision | Top-rung answer |
|---|---|---|
| Technology choice | "Which library for parsing X?" | Pre-spec Implementation Context or project-wide convention |
| Architectural pattern | "Synchronous or event-driven?" | Pre-spec Design Principle or Implementation Context |
| Data shape | "Flat file or structured store?" | Pre-spec Key Entities or Implementation Context |
| Testing strategy | "Integration tests, contract tests, or both?" | Pre-spec Design Principle or chunking-doc `### Speckit Stop Resolutions` |
| Integration pattern | "New wrapper or extend existing?" | Pre-spec scope + prior-artifact boundary in chunking doc |
| Error-handling posture | "Fail-fast or degrade-gracefully?" | Pre-spec Design Principle |
| Concurrency model | "Single-writer or coordinated?" | Pre-spec Design Principle or Implementation Context |
| Verification instrument | "What tool confirms the contract?" | **Pre-spec or `### Speckit Stop Resolutions` — the Chunk 3b stop class.** |

Verification-instrument stops are the highest-severity PSA-11 class: a fall-through here reshapes chunk scope silently (bespoke scanner, per-consumer tests, etc.). Any chunk whose FRs imply a verification / instrumentation / audit need must pin the instrument choice at pre-spec or chunking layer.

### Tasks-stage stops

`/speckit.tasks` generates `tasks.md` from `spec.md + plan.md`. Halt conditions: task count >100, or any FR with no corresponding task. The prompt enforces TDD ordering, `[P]` markers, outbound-gate evidence tasks, evidence-matrix task, and phase count.

| Stop class | Resolution |
|---|---|
| Task count >100 | Halt — signals upstream over-scoping; remedy is re-chunk or narrow pre-spec |
| FR uncovered | Halt — signals missing pre-spec traceability; remedy is pre-spec amendment |
| Phase boundary ambiguity | Resolved in-context by prompt heuristics; thin-intent risk is low |
| `[P]` marker ambiguity | Resolved by prompt's file-independence heuristic |

Tasks-stage fall-through usually produces a visible halt, not silent drift. PSA-11 severity MEDIUM for tasks-stage stops.

### Analyze-stage findings

`/speckit.analyze` is a read-only consistency check across `spec.md`, `plan.md`, `tasks.md`. Findings:

| Finding class | Action |
|---|---|
| Coverage gap (FR with no task) | Edit tasks.md; resume |
| Terminology drift (same concept, different names) | Normalize terms; resume |
| Requirement/task misalignment | Adjust task or amend requirement; resume |

Analyze findings that reveal pre-spec intent gaps (not just artifact drift) are late PSA-11 detection — the pre-spec audit should have caught them. Route back to pre-spec amendment.

### Superb.review gate

`/speckit.superb.review` reads `spec.md § Known Issues` and assesses TDD-readiness. It is the last-chance gate before implementation.

| Block condition | Meaning |
|---|---|
| Known Issues present with unresolved-in-chunk severity | Clarify-stage fall-through landed here; PSA-11 / CSA-11 defect |
| TDD-readiness gap (FR without testable task) | Tasks-stage or pre-spec testability gap; route to remedy |
| Scope-change signal in Known Issues | Either amend chunking doc (scope expansion ratified) or halt the chunk |

Any block at superb.review that traces to Known Issues is evidence the resolution ladder fell through. PSA-11 / CSA-11 at audit time prevents this block.

### Implement-stage

No new stops. The prompt executes tasks.md. Per-task implementation choices are bounded by spec + plan + tasks; a well-audited chain produces a well-bounded implementation.

### Superb.verify gate

`/speckit.superb.verify` is the spec-coverage verification gate. It is the absolute backstop. PSA-11 aims to make this gate redundant in practice — a chain that passed PSA-11 + CSA-11 should pass superb.verify without findings. When superb.verify finds drift, the post-mortem asks "which inventoried stop fell through, and why didn't the pre-spec/chunking audit catch it?" — and the answer feeds the next iteration of this inventory.
