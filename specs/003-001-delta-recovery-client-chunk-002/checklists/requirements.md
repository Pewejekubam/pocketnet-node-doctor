# Specification Quality Checklist: Client Foundation + Diagnose

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-04-30
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) leak into the WHAT/WHY surface — Speckit Stop Resolutions (Go, `net/http`, JSON, SHA-256, etc.) are pre-resolved scope decisions inherited from the chunking doc and called out as such, not WHAT/WHY claims
- [x] Focused on user value and business needs (operator restoring a dead node; refusing to damage a healthy one; trusting only authentic canonicals)
- [x] Written for the operator-stakeholder audience (no developer-only jargon outside the Speckit Stop Resolutions block where it is explicitly inherited from the chunking doc)
- [x] All mandatory sections completed (User Scenarios & Testing, Requirements, Success Criteria)

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain in the spec body
- [x] Requirements are testable and unambiguous (each FR is reproduced verbatim from the pre-spec; each acceptance scenario follows Given/When/Then)
- [x] Success criteria are measurable (5-minute time bounds, distinct exit codes per predicate, SHA-256 round-trip equality, distinct refusal exit code on `format_version` mismatch)
- [x] Success criteria are technology-agnostic at the SC surface (the technologies named — SHA-256, JSON canonical-form rule — are inherited from pre-spec Implementation Context and are part of the cross-chunk contract, not net-new prescription introduced here)
- [x] All acceptance scenarios are defined (US-001: 6, US-002: 8, US-003: 4)
- [x] Edge cases are identified (EC-001, EC-002, EC-004, EC-008, EC-011 — each mapped to its owning user story)
- [x] Scope is clearly bounded (the spec names every FR/SC/EC that is in scope, and the Assumptions section names every pre-spec FR/EC explicitly out of scope and which downstream chunk owns it)
- [x] Dependencies and assumptions identified (Chunk 001 schema-freeze, Chunk 001 trust-root publication, pre-spec canonical-form rule, reference rig for SC-001/SC-002)

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria — every FR maps to at least one Given/When/Then in the user story it backs
- [x] User scenarios cover primary flows (the three P1 user stories cover the three orthogonal capabilities the chunk delivers: read-only diagnose, refusal predicates, trust-root authentication)
- [x] Feature meets measurable outcomes defined in Success Criteria (each SC is observable on a fixture rig the spec names)
- [x] No implementation details leak into specification beyond the Speckit Stop Resolutions inherited from the chunking doc (which are explicitly recorded as pre-resolved decisions, not net-new spec content)

## Chunking-doc enumeration coverage

This chunk's authoritative scope is §Chunk 002 of the chunking doc. Every FR / SC / EC that section lists for this chunk MUST appear in this spec. This block enforces no silent omissions.

### Functional Requirements owned (per chunking doc §Chunk 002)

- [x] **FR-001** — Per-page hashes of `pocketdb/main.sqlite3` matching the canonical manifest's page-grid (spec.md Functional Requirements > Diagnose surface)
- [x] **FR-002** — Whole-file hashes of non-SQLite artifacts under `pocketdb/` (spec.md Functional Requirements > Diagnose surface)
- [x] **FR-003** — Machine-readable plan listing divergences with canonical hashes and canonical identity (spec.md Functional Requirements > Diagnose surface)
- [x] **FR-004** — Human-readable summary alongside the plan (spec.md Functional Requirements > Diagnose surface)
- [x] **FR-005** — Diagnose performs zero writes; observably read-only (spec.md Functional Requirements > Diagnose surface)
- [x] **FR-010** — Refuse if `pocketnet-core` is using `pocketdb/` (spec.md Functional Requirements > Refusal predicates)
- [x] **FR-011** — Refuse apply if local pocketdb is strictly newer than canonical (spec.md Functional Requirements > Refusal predicates)
- [x] **FR-012** — Refuse if local `pocketnet-core` binary version differs from manifest's recorded version (spec.md Functional Requirements > Refusal predicates)
- [x] **FR-013** — Refuse apply if volume lacks free space; report shortfall in bytes (spec.md Functional Requirements > Refusal predicates)
- [x] **FR-017** — Verify manifest SHA-256 against trust-root before consuming entries; reject and refuse on mismatch (spec.md Functional Requirements > Trust-root authentication)
- [x] **FR-018** — Manifest format does not foreclose chain-anchored / healthy-peer trust evidence; `format_version` mismatch triggers refusal; `trust_anchors` parsed-but-ignored in v1 (spec.md Functional Requirements > Trust-root authentication)

### Edge cases owned (per chunking doc §Chunk 002)

- [x] **EC-001** — Local pocketdb missing entirely; diagnose treats every canonical file as not-present-locally (spec.md Edge Cases)
- [x] **EC-002** — Local pocketdb partially present; diagnose handles missing files as full-file divergences (spec.md Edge Cases)
- [x] **EC-004** — Non-`pocketnet-core` OS lock on `main.sqlite3` is treated as the running-node refusal case (spec.md Edge Cases; reinforced in spec.md Functional Requirements > FR-010 and US-002 acceptance scenario 2)
- [x] **EC-008** — Manifest hash verification fails; refuse without consuming chunk-store bytes (spec.md Edge Cases; reinforced in US-003 acceptance scenario 2)
- [x] **EC-011** — Volume permission / read-only refusal as a fifth pre-flight predicate (spec.md Edge Cases; spec.md Functional Requirements > Refusal predicates; US-002 acceptance scenario 6)

### Testable success criteria owned (per chunking doc §Chunk 002)

- [x] **SC-001 (timing half)** — Diagnose within 5 minutes on the reference rig for fixture 30 days behind canonical (spec.md Success Criteria > Measurable Outcomes; fetch-size half is explicitly out of scope here)
- [x] **SC-002** — Zero-entry plan and clean exit within 5 minutes on identical-to-canonical node (spec.md Success Criteria > Measurable Outcomes)
- [x] **SC-006** — Each of five refusal predicates blocks with a distinct exit code per the Speckit Stop Resolutions allocation; no bytes modified (spec.md Success Criteria > Measurable Outcomes)
- [x] **CSC002-001** — Plan self-hash round-trip equality (spec.md Success Criteria > Measurable Outcomes)
- [x] **CSC002-002** — Manifest-format-version refusal with distinct exit code naming the version mismatch (spec.md Success Criteria > Measurable Outcomes)

### Speckit Stop Resolutions inherited (per chunking doc §Chunk 002)

- [x] Plan-stage / language and runtime (Go, single static binary, no runtime deps) — recorded
- [x] Plan-stage / CLI surface (subcommands `diagnose` / `apply`; `apply --full` namespace reserved) — recorded
- [x] Plan-stage / HTTP client library (`net/http`) — recorded
- [x] Plan-stage / SQLite library bindings (single binding chosen at plan-stage; inherits to Chunk 003) — recorded; specific binding choice is a Plan-layer deferral
- [x] Plan-stage / logging surface (plain-text stderr; `--verbose` flag) — recorded
- [x] Plan-stage / progress reporting on long diagnose runs (stderr at file-class boundaries; human-readable) — recorded
- [x] Plan-stage / configuration storage (no user-config file in v1; CLI flags only; trust-root compiled in) — recorded
- [x] Plan-stage / FR-018 forward-compat surface (`format_version` and reserved `trust_anchors` block) — recorded
- [x] Clarify-stage / plan filename and location (`plan.json`; overrideable via `--plan-out`) — recorded
- [x] Tasks-stage / pre-flight predicate ordering (running-node → version-mismatch → volume-capacity → permission/read-only → ahead-of-canonical) — recorded
- [x] Tasks-stage / exit-code allocation (full table 0..7 + reserved 10..19; categorization rule) — recorded

## Notes

- All chunking-doc-enumerated FRs, SCs, and ECs for this chunk are present in the spec.
- The five Plan-layer deferrals recorded in spec.md > Plan-layer deferrals are decisions explicitly NOT pre-resolved by the chunking doc; they are surfaced for `/speckit.plan` to resolve. They do not represent gaps in the spec.
- Items marked incomplete (none in this checklist) would require spec updates before `/speckit.clarify` or `/speckit.plan`.
