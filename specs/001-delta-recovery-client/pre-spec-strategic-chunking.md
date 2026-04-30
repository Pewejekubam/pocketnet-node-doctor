---
version: 1.1.0
status: approved
created: 2026-04-30
last_modified: 2026-04-30
authors: [pewejekubam, claude]
related: pre-spec.md
changelog:
  - version: 1.1.0
    date: 2026-04-30
    summary: Minor — inherit pre-spec v1.1.0 pins (Go language, v1 development trust-root constant); One-Time Setup Checklist trust-root item now checked
    changes:
      - "Purpose: pre-spec source-of-truth reference bumped from v0.3.3 to v1.1.0 (current state)"
      - "Chunk 002 Speckit Stop Resolutions: language-and-runtime stop now inherits the pre-spec pin (Go) instead of leaving Go/Rust/Zig to plan-stage; SQLite library binding stop tightened to 'a Go SQLite binding chosen at plan-stage from the Go ecosystem'"
      - "Chunk 003 Speckit Stop Resolutions: inherited HTTP client + SQLite binding bullet now explicitly cites the pre-spec language pin (Go) so chunks 002 and 003 build against the same toolchain"
      - "One-Time Setup Checklist: trust-root constant pin item is now checked — value pinned in pre-spec Implementation Context (a939828d… per chunk-001 fixture); re-pin scheduled for chunk 005 release per existing checklist note"
  - version: 1.0.2
    date: 2026-04-30
    summary: Patch — Chunk 001 merged to main; Progress Tracker row flipped to terminal state per process.md v0.3.4 post-merge convention
    changes:
      - "Progress Tracker: Chunk 001 status `Implementation Complete — Awaiting Merge` → `Merged` (terminal state)"
  - version: 1.0.1
    date: 2026-04-30
    summary: Patch — Chunk 001 implementation complete; Progress Tracker row + per-chunk addendum recording the auto-chunk-runner run signature
    changes:
      - "Progress Tracker: Chunk 001 status → Implementation Complete — Awaiting Merge"
      - "Per-Chunk Addenda: appended Chunk 001 run signature (run id, stage durations, halt + recovery, FR/SC counts, gate identifications, deferrals)"
  - version: 1.0.0
    date: 2026-04-30
    summary: Approval milestone — Stage 6 formally exited; ready to drive chunk-runner dispatch
    changes:
      - "Status flip: draft → approved per process.md major-bump-on-approval rule"
      - "Chunking has passed Stage 5 audit, Stage 6 refinement, Stage 5 delta-audit, plus the three-digit ID renumber tune-up"
  - version: 0.2.2
    date: 2026-04-30
    summary: Patch — chunk IDs renumbered to three-digit zero-padded form per process.md v0.3.3 convention
    changes:
      - "Progress Tracker rows: chunk IDs `1`..`5` → `001`..`005` for stable column widths and unambiguous chunk-runner branch names (`<spec-dir-basename>/chunk-<id>`)"
      - "Chunk headers and cross-references throughout body updated accordingly"
      - "Chunk-scoped contract IDs renumbered: `CR1-NNN` → `CR001-NNN`, `CSC1-NNN` → `CSC001-NNN`, etc."
      - "Gate references: `Gate N → M` → `Gate 00N → 00M`; `Gate 1-Schema → 2` → `Gate 001-Schema → 002`"
      - "Pre-spec source-of-truth reference: bumped from v0.3.2 to v0.3.3 (current state of pre-spec.md)"
  - version: 0.2.1
    date: 2026-04-30
    summary: Patch — apply Stage 5 delta-audit findings against chunking v0.2.0 net-new content (5 findings; pre-spec write-back findings handled in pre-spec v0.3.3)
    changes:
      - "XDC-F01-D closed: exit-code 13 collision resolved — manifest-format-version-unrecognized refusal moved from apply-time block (10..19) to pre-flight block as code 7; categorization rule extended to '2..7 = pre-flight refusals.' Chunk 003's apply-time codes leave 13 reserved (renumbered downstream codes preserved at 14, 15 to minimize operator-wrapper churn if any external doc previously cited them)"
      - "CSA-11-F01-D closed: Chunk 005 signing-scheme SSR rewritten to acknowledge Authenticode (X.509) and GPG (OpenPGP) as distinct cryptographic systems administratively maintained by the same publisher; new Chunk 005 SSR pins signing-key custody (CI provider's encrypted secret store, retrieved at sign-time only, never persisted on a runner)"
      - "CSA-05-F01-D closed: Gate 001-Schema → 002 predicate 1 pinned to a JSON Schema (Draft 2020-12) document at a stable URL"
      - "CSA-11-F02-D closed: Chunk 004 SC-008 mapping reworded — iptables `REJECT --reject-with tcp-reset` is the connection-kill primitive; `tc` is optional rate-shaping for a constrained-link simulation, not part of the SC-008 verification path"
      - "CSA-09-F01-D closed: 'reproducibly built' dropped from Chunk 005 behavioral criteria (operator-verifiability is preserved by signature verification alone; reproducible builds remain a non-v1 nice-to-have)"
  - version: 0.2.0
    date: 2026-04-30
    summary: Stage 6 refinement — apply all Stage 5 chunking-audit findings (pre-spec-strategic-chunking-audit.md v0.1.0)
    changes:
      - "CSA-01-F01 (HIGH) closed: Chunk 004 split — Chunk 004 covers drill (US-005) + network resilience (US-006); Chunk 005 covers release polish; Gate 004 → 005 added so release artifacts cannot ship until network resilience is exercised"
      - "CSA-02-F01 (HIGH) closed: parallelism claim reframed — Chunk 001's manifest schema is a sub-deliverable that gates Chunk 002's start; full chunk store gates Gate 002 → 003 fetch-size verification"
      - "CSA-02-F02 (MEDIUM) closed: trust-root constant pinning recorded as a One-Time Setup Checklist item; Chunks 002 and 003 build against the same pinned value"
      - "CSA-03-F01 (MEDIUM) closed: EC-005 superseded-canonical detection mechanism added to Chunk 003 Speckit Stop Resolutions — apply re-fetches manifest and compares hash against plan's canonical_identity"
      - "CSA-03-F02 (LOW) closed: EC-002 partial-pocketdb contract pinned in Chunk 003 Speckit Stop Resolutions — missing-file divergences are encoded as full-file entries with a special expected-source marker"
      - "CSA-05-F01 (HIGH) closed: Gate 001 → 002 Content-Encoding predicate now pins HTTP 406 with a body naming supported encodings on no-match; binary verification predicate"
      - "CSA-05-F02 / CSA-08-F01 (HIGH) closed: SC-001's fetch-size half moved to Gate 003 → 004 (post-Chunk-3 integration where a real canonical exists); Gate 002 → 003 covers timing only against the reference rig and a synthetic divergent fixture"
      - "CSA-05-F03 (MEDIUM) closed: Gate 002 → 003 enumerates five pre-flight refusal predicates (running, ahead, version, capacity, permission); Gate 003 → 004 EC-011 entry downgraded to smoke-test continuation"
      - "CSA-08-F02 (MEDIUM) closed: CSC004-002 reworded as binary check (troubleshooting guide enumerates every doctor exit code with at least one diagnostic and one operator action per code)"
      - "CSA-09-F01 (MEDIUM) closed: FR-018 testable surface added to Chunk 002 — manifest schema includes format_version field and reserves trust_anchors block (empty in v1) for future trust-anchor mechanisms"
      - "CSA-09-F02 (LOW) closed: Progress Tracker Chunk 001 FR column now reads `CR001-001..008` (parseable) instead of free-text"
      - "CSA-10-F01 (LOW) closed: pre-spec amended to add Design Principle 9 (operator-verifiable release artifacts); Chunk 005 (release polish) now derives from the amended pre-spec"
      - "CSA-11-F01 (HIGH) closed: Chunk 002 Speckit Stop Resolution added — HTTP client library is the language-default standard library client; same library inherits to Chunk 003"
      - "CSA-11-F02 (HIGH) closed: pre-spec Implementation Context pins the canonical-form serialization rule (used by manifest trust-root and plan self-hash); SQLite library bindings pinned in Chunk 002 Speckit Stop Resolutions; Chunk 003 inherits"
      - "CSA-11-F03 (MEDIUM) closed: Chunk 002 Speckit Stop Resolution allocates exit codes 0..6 (success + five refusal predicates) and reserves 10..19 for apply-time failures (Chunk 003 inherits)"
      - "CSA-11-F04 (MEDIUM) closed: Chunk 002 Speckit Stop Resolution pins logging surface — plain-text stderr at info level, --verbose for debug, no structured logging in v1"
      - "CSA-11-F05 (MEDIUM) closed: Chunk 004 Speckit Stop Resolution maps SC-008's '256 MB drops' to a concrete tc + iptables rule (kill TCP connection once per 256 MB transferred to doctor's HTTP client)"
      - "CSA-11-F06 (LOW) closed: Chunk 005 Speckit Stop Resolution pins Windows code-signing path (Authenticode via project's existing publisher cert)"
      - "CSA-11-F07 (MEDIUM) closed: canonical-form serialization rule moved to pre-spec Implementation Context (write-back); both Chunk 001 manifest and Chunk 002 plan-format inherit a single source"
      - "Chunk count: 5. Numbering: 1, 2, 3, 4, 5 (sequential, no a/b/c suffixes per author preference)"
  - version: 0.1.0
    date: 2026-04-30
    summary: Initial strategic chunking — derives four implementation chunks from pre-spec.md v0.3.1, distributes US/FR/SC/EC ownership, declares infrastructure gates, and records per-chunk Speckit Stop Resolutions
    changes:
      - "Four chunks: server-side manifest + chunk store; client foundation + diagnose; client apply; drill + network + release polish"
      - "Server-side chunk (Chunk 001) declares integration contracts the pre-spec Implementation Context implies but does not enumerate as doctor FRs; its implementation lives in the sibling `pocketnet_create_checkpoint` repo via epic child delt.3"
      - "All 6 USs, 20 FRs, 8 SCs, 11 ECs from pre-spec v0.3.1 distributed across chunks; nothing deferred to a final-validation chunk"
      - "Per-chunk Speckit Stop Resolutions cover the chunk-level framings the pre-spec deliberately deferred (drill canonical source, CLI surface preservation for future --full mode, compression-encoding negotiation)"
      - "Empirical experiments (delt.1 cross-DB reuse, delt.2 chunk-store materialization, delt.5 worst-case Feb→Apr reuse) recorded as One-Time Setup Checklist items, not chunks"
      - "Infrastructure Gate Checklists between every chunk pair with concrete, verifiable predicates"
      - "Progress Tracker convention applied: Chunk | Title | FRs | SCs | Status, Status rightmost and capitalized"
---

# Pre-Spec Strategic Chunking: Delta Recovery Client for Pocketnet Operators

## Purpose

This document decomposes the implementation of `pocketnet-node-doctor` (specified by [`pre-spec.md`](pre-spec.md) v1.1.0) into five dependency-ordered implementation chunks. Each chunk is a self-contained, testable, debuggable unit fed independently to the speckit pipeline (`speckit.specify` → `speckit.implement`). The chunking thesis is that bounded chunks produce bounded, mergeable implementations.

The pre-spec is the source of truth. This document is derived from it and must remain consistent with it.

---

## Critical Path

```
Setup (empirical baselines, prereq experiments, trust-root pinning)
   │
   ▼
Chunk 001 — Server-Side: Manifest Schema (sub-deliverable) ──┐
   │                                                       │ Schema-freeze
   ▼                                                       │ unblocks Chunk 002
Chunk 001 (continued) — Manifest + Chunk Store Generation    │
   │                                                       │
   ├───────────────────────────────────────────────────────┤
   ▼                                                       ▼
Chunk 002 — Client Foundation + Diagnose ◄───── (real chunk store)
   │
   ▼
Chunk 003 — Client Apply
   │
   ▼
Chunk 004 — End-to-End Drill + Network Resilience
   │
   ▼
Chunk 005 — Release Polish
```

**Serial dependencies.** Chunk 002 requires Chunk 001's manifest schema frozen (a sub-deliverable, well in advance of the full chunk store). Chunk 003 requires Chunks 001 (full chunk store) and 002 (plan format). Chunk 004 requires Chunk 003 and a published canonical from Chunk 001 at a block height suitable for the drill. Chunk 005 requires Chunk 004 (don't ship release artifacts until network resilience is actually exercised).

**Parallelism.** Chunk 001's manifest-schema-freeze sub-deliverable gates Chunk 002's start. After schema freeze, Chunks 001 (chunk store completion) and 002 (diagnose implementation) may proceed concurrently. The chunk store must exist before Gate 002 → 003 verifies SC-001's fetch-size predicate.

**Convergence point.** End of Chunk 003 — at this point a recovering operator can complete a real diagnose-and-apply cycle against a real canonical. Chunks 004 and 005 harden that capability into a community-ready signed release.

---

## Progress Tracker

| Chunk | Title | FRs | SCs | Status |
|-------|-------|-----|-----|--------|
| 001 | Server-Side: Manifest Schema + Chunk Store Generation | CR001-001..008 | SC-007 (drill prerequisite) | Merged |
| 002 | Client Foundation + Diagnose | FR-001, FR-002, FR-003, FR-004, FR-005, FR-010, FR-011, FR-012, FR-013, FR-017, FR-018 | SC-001 (timing half), SC-002, SC-006 | Pending |
| 003 | Client Apply | FR-006, FR-007, FR-008, FR-009, FR-014, FR-015, FR-016, FR-019, FR-020 | SC-001 (fetch-size half), SC-003, SC-004, SC-005 | Pending |
| 004 | End-to-End Drill + Network Resilience | (no new FRs; integration of all prior) | SC-007, SC-008 | Pending |
| 005 | Release Polish | (no new FRs; engineering work for Design Principle 9) | (no new SCs; CSC005-* below) | Pending |

---

## One-Time Setup Checklist

Pre-implementation prerequisites. None of these are implementation chunks; they are environment, data, or measurement work that must complete before or alongside the chunks.

- [ ] **Pre-spec is at `status: approved`** in frontmatter (Stage 6 exit; chunking is currently `draft`).
- [ ] **Empirical baseline reuse measurement on `main.sqlite3` March → April** is captured (delt.1 follow-up; the original 85.83% measurement validates the pre-spec's bandwidth claim — this checkbox is the audit-trail confirmation that the experiment artifact lives at `experiments/01-page-alignment-baseline/`).
- [ ] **Cross-DB reuse pattern measured on `web.sqlite3`** to confirm the page-level reuse pattern is not unique to `main.sqlite3` (delt.1).
- [ ] **March → April chunk store materialization** to validate compressed delta size against the projected ~13–15 GB target (delt.2).
- [ ] **Worst-case bracket reuse rate measured (Feb → April)** to confirm the design holds across longer-than-30-day intervals; expected reuse rate floor ≥ 50% (delt.5).
- [ ] **Project test rig matches SC-001 reference rig** (8 vCPU x86_64 host, NVMe-class disk, 16 GB RAM) or alternative reference is documented and SC-001 is amended.
- [x] **Trust-root constant value is published and pinned in build configuration** for Chunks 002 and 003 development. Pinned in pre-spec v1.1.0 Implementation Context: `a939828d349bc5259d2c79fe9251d4e3497d2d1518c944dfc91ae9594f029249` (chunk-001 fixture canonical at block height 3,806,626). Re-pin to a `delt.3`-published live canonical at chunk 005 release. Chunks 002 and 003 must build against the same pinned value to avoid integration-time drift.
- [ ] **Project-internal test node** stopped, snapshotted (virtual-machine snapshot), and confirmed dead-state reproducible before Chunk 004 drill commences.

---

## Infrastructure Gate Checklists

Each gate is a concrete, verifiable predicate that must hold before the next chunk can begin.

### Gate 000 → 001: Empirical baselines validated

After One-Time Setup completes, before Chunk 001 begins.

- [ ] **All measurement experiments closed** (delt.1, delt.2, delt.5) with results matching pre-spec projections (≥ 50% reuse worst-case; ~13–15 GB compressed delta).
- [x] **Trust-root constant pinned** for Chunks 002 and 003 development (`a939828d…` per pre-spec Implementation Context).

### Gate 001-Schema → 002: Manifest schema frozen

A Chunk 001 sub-gate. After Chunk 001's manifest schema is authored and published as a contract, before Chunk 002 begins. Chunk 001 may continue developing the chunk store after this sub-gate; Chunk 002 begins in parallel.

- [ ] **Manifest schema document published** at a stable URL as a JSON Schema (Draft 2020-12, or the current draft at time of authoring). The schema enumerates every required field, including `format_version`, `canonical_identity`, per-file entries with page-grid offsets for `main.sqlite3`, and the reserved `trust_anchors` block.
- [ ] **Canonical-form serialization rule cited** by the schema document (sorted keys, no insignificant whitespace, UTF-8) so Chunk 002's plan-format library and Chunk 001's manifest generator hash identically.

### Gate 001 → 002: Chunk Store Available (full)

After Chunk 001's chunk store completes, before Gate 002 → 003 fetch-size verification (Chunk 002 dev work may proceed against a mock chunk store after Gate 001-Schema → 002; the full chunk store is needed for Chunk 003 entry).

- [ ] **Manifest URL serves a manifest for a pinned canonical block height** — `curl -s <manifest-url> | sha256sum` returns a known hash that matches the project-pinned trust-root constant.
- [ ] **Manifest fields parse cleanly** per the frozen schema.
- [ ] **Chunk URLs serve verified chunks** — for at least three sampled chunks (one `main.sqlite3` page, one `blocks/` file, one `chainstate/` file), `curl -s <chunk-url> | sha256sum` matches the manifest's recorded hash for that chunk.
- [ ] **Content-Encoding negotiation works to a single pinned contract** — chunk requests with `Accept-Encoding: zstd` return zstd-encoded payloads; with `Accept-Encoding: gzip` return gzip-encoded payloads. Absence of either supported encoding in `Accept-Encoding` returns **HTTP 406 Not Acceptable** with a body naming supported encodings (`zstd`, `gzip`). Verifiable: `curl -H 'Accept-Encoding: identity' <chunk-url>` returns HTTP 406 and a body containing both encoding names.

### Gate 002 → 003: Plan Format Round-Trips

After Chunk 002 merges, before Chunk 003 begins.

- [ ] **Diagnose against a synthetic divergent fixture produces a plan within the timing budget** — running diagnose against a fixture pocketdb on the reference rig completes within 5 minutes (timing half of SC-001). Fixture-based test, no real canonical required.
- [ ] **Diagnose on a fixture identical to canonical produces a zero-entry plan** (per SC-002).
- [ ] **Plan self-hash verifies** — recomputing SHA-256 over the plan's canonical-form payload (sorted keys, no insignificant whitespace, with `self_hash` field removed) equals the plan's declared `self_hash`.
- [ ] **Plan canonical identity is bound** — diagnoses against two different fixture-canonicals produce plans with different `canonical_identity` blocks.
- [ ] **All five environmental pre-flight refusal predicates fire correctly** — running diagnose with (a) `pocketnet-core` running, (b) ahead-of-canonical local node, (c) pocketnet-core-version mismatch, (d) insufficient volume capacity, (e) read-only / permission-denied volume each refuses with a distinct exit code from the 2..6 block (per SC-006 + EC-011).
- [ ] **Manifest-format-version refusal fires** — diagnose against a manifest carrying an unrecognized future `format_version` refuses with exit code 7, no chunk-store fetches attempted (per CSC002-002).

### Gate 003 → 004: Apply Round-Trips Against Real Canonical

After Chunk 003 merges, before Chunk 004 begins.

- [ ] **Apply against a real plan results in canonical-matching pocketdb** — every file's hash matches the canonical manifest after apply; `PRAGMA integrity_check` returns "ok" (per SC-003).
- [ ] **SC-001 fetch-size predicate verified** — on a node 30 days behind canonical, the diagnose-emitted plan's total fetch size is ≤ 25% of the full snapshot size (the fetch-size half of SC-001 that requires a real canonical).
- [ ] **Mid-apply interruption resumes cleanly** — killing the apply process during fetch and re-running with the same plan completes without re-fetching previously-fetched chunks (per SC-004).
- [ ] **Verification failure rolls back** — simulating a chunk-store byte error results in observable rollback to pre-apply state (per SC-005).
- [ ] **EC-011 smoke check** — apply on a read-only mount surfaces the permission refusal at pre-flight (continuation regression check; primary verification is at Gate 002 → 003).

### Gate 004 → 005: Network Resilience Validated

After Chunk 004 merges, before Chunk 005 begins.

- [ ] **End-to-end drill passes on the project-internal test node** — damaged node recovered to canonical-matching state; `pocketnet-core`'s `getbestblockhash` RPC returns a block at or descended from the canonical's pinned block height (per SC-007).
- [ ] **Network-drop scenario completes via re-invocation** — apply on a 4 GB total-fetch with simulated 256 MB-spaced network drops completes the recovery without operator intervention beyond running the doctor again (per SC-008).
- [ ] **Drill runbook reproduces** — a second drill execution from snapshot follows the runbook step-by-step and produces the same outcome.

---

## Chunk 001: Server-Side Manifest Schema + Chunk Store Generation

### Scope

Extend the existing `pocketnet_create_checkpoint` workflow to produce alongside the full-snapshot artifact:

1. A frozen **manifest schema document** (sub-deliverable; gates Chunk 002's start).
2. A **manifest** for each published canonical, conforming to the schema.
3. A **chunk store** — HTTPS-addressable byte source from which differing chunks are fetched.
4. A published **trust-root SHA-256** of each canonical's manifest.

The implementation lives in the `pocketnet_create_checkpoint` repo (epic child delt.3). This chunking document treats Chunk 001 as a contract.

### Prior artifact boundaries

- Pre-spec v0.3.2 — source of truth.
- Existing `pocketnet_create_checkpoint` workflow.

### Functional contract (chunk-specific FRs)

These are not pre-spec FRs (pre-spec is doctor-side). They are integration contracts derived from doctor expectations.

- **CR001-001** Chunk-store HTTPS endpoint serves a JSON manifest at a stable URL for each published canonical block height. Manifest carries `format_version`, `canonical_identity` (`block_height`, `pocketnet_core_version`, `created_at`), per-file entries, and a reserved `trust_anchors` block (empty in v1).
- **CR001-002** Per-file entries for `main.sqlite3` enumerate page-level hashes at the 4 KB SQLite page boundary, addressable by `(path, offset)`.
- **CR001-003** Per-file entries for non-SQLite artifacts carry whole-file SHA-256 hashes.
- **CR001-004** Chunk URLs are addressable as discrete HTTPS GETs.
- **CR001-005** Server honors `Accept-Encoding: zstd` and `Accept-Encoding: gzip`; payloads are pre-compressed and cached server-side. Absence of either supported encoding returns HTTP 406 with a body naming supported encodings.
- **CR001-006** SHA-256 of the canonical-form manifest payload (per pre-spec Implementation Context's canonical-form rule) is published alongside the manifest as the trust-root constant.
- **CR001-007** Manifest declares the `change_counter` SQLite header value for `main.sqlite3` so doctor's pre-flight ahead-of-canonical check (FR-011) has a reference.
- **CR001-008** Server publishes manifests no older than 30 days.

### Edge cases owned

None directly from pre-spec EC list. Server-side EC behavior is addressed in delt.3.

### Behavioral criteria

- A doctor binary built against the trust-root for canonical at block height H can authenticate that exact manifest and only that manifest.
- Two doctor binaries built against the same trust-root see the same canonical when both fetch the manifest URL.
- The chunk store survives concurrent fetches at typical operator scale.

### Testable success criteria

- **CSC001-001** All Gate 001-Schema → 002 predicates pass.
- **CSC001-002** All Gate 001 → 002 predicates pass for a canonical published by the server-side workflow.
- **CSC001-003** Drill prerequisite: at least one canonical is published whose block height is suitable for Chunk 004's drill.

### Speckit Stop Resolutions

- **Plan-stage / language and runtime for the manifest generator.** Use the existing `pocketnet_create_checkpoint` workflow's language and runtime. Do not introduce a new language; extend the existing tooling.
- **Plan-stage / chunk-store hosting topology.** Same hosting channel as today's full-snapshot distribution.
- **Plan-stage / compression choice on the server side.** Pre-compress chunks with both Zstandard and gzip; serve per `Accept-Encoding`; absence of either supported encoding returns HTTP 406 (CR001-005).
- **Plan-stage / canonical-form serialization ownership.** Pre-spec Implementation Context (v0.3.2) is the authoritative source for the canonical-form rule (sorted keys, no insignificant whitespace, UTF-8). Both the manifest-trust-root hash (this chunk) and the plan-self-hash (Chunk 002) inherit. No chunk owns the rule independently.
- **Tasks-stage / manifest schema publication.** The manifest schema is published as a JSON-schema-format document (or equivalent) in the project's docs or at a stable URL before the chunk store is built. Schema-freeze is Gate 001-Schema → 002.
- **Plan-stage / drill canonical source (PSA-11-F06).** A canonical published by this chunk is the drill canonical for Chunk 004. The drill rig's doctor binary is built against this canonical's trust-root.

### What this chunk unblocks

- Chunk 002 may begin after manifest schema freeze (Gate 001-Schema → 002).
- Chunk 003 may begin after the full chunk store is available (Gate 001 → 002).
- Chunk 004 drill scenario requires this chunk's published canonical.

---

## Chunk 002: Client Foundation + Diagnose

### Scope

The doctor's read-only pathway plus foundational scaffolding both phases share:

- Project skeleton (binary entry point, CLI argument parsing, exit-code allocation, logging surface).
- Plan-format library (JSON serialization, canonical-form hashing per pre-spec Implementation Context, self-hash verification, format-version handling).
- Manifest verifier (fetches manifest, computes SHA-256, compares to compiled-in trust-root, parses verified manifest including the `format_version` and `trust_anchors` block per FR-018).
- Hash utilities.
- Diagnose phase (US-001).
- Five pre-flight refusal predicates (US-003): FR-010..013 plus EC-011.
- Trust-root authentication (FR-017, FR-018).

### Prior artifact boundaries

- Pre-spec v0.3.2.
- Chunk 001's frozen manifest schema (Gate 001-Schema → 002).
- Chunk 001's published trust-root constant (compiled in at build time per One-Time Setup).
- Pre-spec Implementation Context's canonical-form serialization rule (used by the plan-format library).

### Functional requirements owned

- **FR-001** through **FR-005** (diagnose surface).
- **FR-010** through **FR-013** (refusal predicates) plus **EC-011** as a fifth predicate.
- **FR-017** and **FR-018** (trust-root authentication and forward-compatibility).

### Edge cases owned

- **EC-001** (diagnose-side handling of completely-missing pocketdb).
- **EC-002** (diagnose-side handling of partially-present pocketdb; apply-side contract owned by Chunk 003).
- **EC-004** (non-`pocketnet-core` OS lock — treat as running-node refusal).
- **EC-008** (manifest hash verification fails).
- **EC-011** (volume permission / read-only refusal).

### Behavioral criteria

- Diagnose performs zero writes to `pocketdb/`; observably read-only.
- Pre-flight predicates run before any pocketdb byte is read; refusal short-circuits with no I/O against pocketdb.
- Plan emission is deterministic given identical inputs.
- Trust-root mismatch refuses without any chunk-store byte fetch.
- Manifest schema parse honors the `format_version` field; an unknown future version refuses cleanly with a diagnostic naming the version mismatch (FR-018 forward-compat surface).
- The reserved `trust_anchors` block is parsed but ignored in v1; an unrecognized non-empty block does not refuse (architectural openness for chain-anchored verification or healthy-peer cross-check per pre-spec Out-of-Scope).

### Testable success criteria

- **SC-001 (timing half)** On a fixture pocketdb 30 days behind a canonical fixture, diagnose completes within 5 minutes on the reference rig. The fetch-size half of SC-001 is verified at Gate 003 → 004 against a real canonical.
- **SC-002** On a node identical to canonical, diagnose emits a zero-entry plan and exits cleanly within 5 minutes.
- **SC-006** Each refusal predicate (five total) blocks with a distinct exit code per the allocation in this chunk's Speckit Stop Resolutions; no bytes modified.
- **CSC002-001** Plan self-hash round-trip: emitted plan's `self_hash` field equals SHA-256 over its canonical-form payload (with `self_hash` removed), using the pre-spec Implementation Context canonical-form rule.
- **CSC002-002** Manifest-format-version refusal: a manifest with an unrecognized future `format_version` causes diagnose to refuse with a distinct exit code naming the version mismatch.

### Speckit Stop Resolutions

- **Plan-stage / language and runtime.** Inherits the pre-spec Implementation Context pin: **Go**, single static binary across Linux, macOS, and Windows, no runtime dependencies.
- **Plan-stage / CLI surface (`--full` mode preservation).** Subcommands (`diagnose`, `apply`); reserves namespace for a future `apply --full` subsumption mode per pre-spec Stage 4 hand-off note. No subcommand-collapsed-into-flags structure.
- **Plan-stage / HTTP client library.** Go's standard-library `net/http` client (per pre-spec Implementation Context language pin). No bespoke HTTP framework. Connection re-use is enabled at the worker-pool level when Chunk 003 implements parallel chunk fetches; same library inherits to Chunk 003.
- **Plan-stage / SQLite library bindings.** A single Go SQLite binding chosen at plan-stage from the Go ecosystem (e.g., `mattn/go-sqlite3` or `modernc.org/sqlite` — choice is plan-stage). The binding is used by Chunk 002 for the `change_counter` ahead-of-canonical check (where possible via direct file-header parsing without invoking the engine) and by Chunk 003 for the post-apply `integrity_check`. Same binding inherits to Chunk 003 to avoid linking two SQLite engines into one binary.
- **Plan-stage / logging surface.** Plain-text to stderr at info level by default; `--verbose` flag enables debug. No structured logging in v1; no log-file output. Diagnose progress reporting (next bullet) reuses the same stderr surface.
- **Plan-stage / progress reporting on long diagnose runs.** Diagnose emits progress to stderr at file-class boundaries (`main.sqlite3` page hashing milestones, `blocks/` file-by-file, etc.) so operators see liveness on long runs. Format is human-readable; not a structured machine protocol.
- **Plan-stage / configuration storage.** No user-config file in v1. Behavior controlled by CLI flags only. Trust-root compiled in.
- **Plan-stage / FR-018 forward-compat surface.** The manifest schema declares a `format_version` field (current value 1) and a reserved `trust_anchors` block (empty in v1). Future canonicals can populate `trust_anchors` with chain-anchored verification fields, healthy-peer cross-check fields, or other trust evidence without breaking v1 parsers. v1 parsers ignore unknown contents of `trust_anchors` but parse and validate the field's presence. This is the testable surface for FR-018 (CSC002-002 covers the version-mismatch path).
- **Clarify-stage / plan filename and location.** `plan.json` written alongside the operator's pocketdb-parent directory by default, overrideable with `--plan-out <path>`.
- **Tasks-stage / pre-flight predicate ordering.** Predicates execute in order: running-node check → version-mismatch check → volume-capacity check → permission/read-only check → ahead-of-canonical check.
- **Tasks-stage / exit-code allocation.** `0` success. `1` generic error. `2..7` pre-flight refusals — code per condition, fired in either diagnose or apply (whichever encounters the condition first): running-node 2, ahead-of-canonical 3, pocketnet-core-version mismatch 4, capacity 5, permission/read-only 6, manifest-format-version unrecognized 7. `10..19` reserved for **mid-run** apply-time failures (conditions that surface after pre-flight passes; Chunk 003 inherits and allocates: 10 rollback completed, 11 rollback failed, 12 network retry budget exhausted, 13 reserved for future apply-time errors, 14 EC-005 superseded-canonical refusal, 15 plan tamper detected). The categorization rule: 2..7 pre-flight (refuse before mutating anything), 10..19 mid-run (refuse after pre-flight, may have staging artifacts to clean up). Codes documented in `--help` output and the Chunk 005 troubleshooting guide.

### What this chunk unblocks

- Chunk 003 (apply) can begin once the plan format is stable.
- Operators can run `pocketnet-node-doctor diagnose` and see what their recovery would entail without mutation risk.

---

## Chunk 003: Client Apply

### Scope

The doctor's mutating pathway:

- Apply phase (US-002).
- Verification (US-004): pre-rename per-chunk SHA-256 against manifest; post-apply whole-file SHA-256 + SQLite native consistency check.
- Network resilience primitives (FR-019, FR-020).

### Prior artifact boundaries

- Pre-spec v0.3.2.
- Chunk 001's chunk store (Gate 001 → 002 passed).
- Chunk 002's plan-format library, plan, manifest verifier, hash utilities, pre-flight refusal predicates, HTTP client library choice, SQLite library binding, exit-code allocation (codes 10..19 reserved for this chunk).
- Same trust-root constant pinned in build configuration (One-Time Setup) — Chunk 003 builds against the same value Chunk 002 was tested against.

### Functional requirements owned

- **FR-006** through **FR-009** (apply mutating).
- **FR-014** through **FR-016** (verification + rollback).
- **FR-019** and **FR-020** (network resilience).

### Edge cases owned

- **EC-001** (apply-side handling of completely-missing pocketdb — full-fetch sub-plan; complementary to Chunk 002's diagnose-side coverage).
- **EC-002** (apply-side handling of partially-present pocketdb; consumes the contract Chunk 002 declares).
- **EC-003** Canonical chunk store unreachable at apply time.
- **EC-005** Plan generated against a superseded canonical.
- **EC-006** Two consecutive apply runs against the same plan on a recovered node.
- **EC-007** Disk I/O fault during apply.
- **EC-009** Plan file tampered (self-hash mismatch).
- **EC-010** Apply succeeds but `pocketnet-core` fails to start.

### Behavioral criteria

- At any observable instant during apply, every byte of `pocketdb/` either matches canonical bitwise or matches the pre-apply state.
- Promotion of an unverified chunk into the live tree is impossible by construction.
- Rollback restores pre-apply state from per-file shadow copies via reverse rename.
- Disk-cost ceiling: pre-apply plan-listed-files-size × 2 plus the staging area for fetched chunks.
- Apply is idempotent on a recovered node.

### Testable success criteria

- **SC-001 (fetch-size half)** On a node 30 days behind canonical, the diagnose-emitted plan's total fetch size is ≤ 25% of the full snapshot size. Verified at Gate 003 → 004 against the real Chunk 001 canonical.
- **SC-003** Apply against a valid plan results in a `pocketdb/` whose every file's hash matches the canonical manifest, and `PRAGMA integrity_check` returns "ok".
- **SC-004** Mid-apply interruption (process killed during fetch) followed by re-invocation completes successfully without re-fetching previously-fetched chunks.
- **SC-005** Post-apply verification failure (chunk store served wrong byte) results in observable rollback.

### Speckit Stop Resolutions

- **Plan-stage / staging directory location.** A subdirectory `pocketnet-node-doctor-staging/` adjacent to `pocketdb/` (same parent), deleted on success, retained on failure for forensics. Same volume holds staging and live tree.
- **Plan-stage / shadow-copy strategy.** Per-file shadow taken at staging time before the file is touched. Shadow lives in the staging directory under a deterministic subpath. On failure: shadows are renamed back into place. On success: shadows are deleted.
- **Plan-stage / completion-marker format.** One zero-byte file per fetched-and-verified chunk, named after the chunk's canonical identifier in a `markers/` subdirectory of staging.
- **Plan-stage / retry budget shape.** Per-chunk retry budget: 5 attempts with exponential backoff (250 ms → 500 ms → 1 s → 2 s → 4 s) with ±25% jitter. Per-chunk budget exhaustion → run-level failure.
- **Plan-stage / parallelism implementation.** Worker pool of size 4 (configurable via `--parallel <N>`) consuming a queue of chunks-to-fetch. Verification + atomic-rename promotion happens on the main thread.
- **Plan-stage / `pocketnet-core` start verification scope.** Apply does not invoke `pocketnet-core`. Apply success is `pocketdb/` matches canonical bitwise + integrity_check passes (per pre-spec EC-010).
- **Tasks-stage / staged-chunk verification mechanism.** SHA-256 of the staged chunk's bytes equals the manifest's recorded hash, computed before the rename system call. Failure → discard, retry per budget.
- **Plan-stage / Content-Encoding negotiation.** Apply's HTTP client sends `Accept-Encoding: zstd, gzip`. Server returns the preferred encoding per Chunk 001's HTTP-406-on-no-match contract; client decompresses transparently before hashing. Hash is over the uncompressed payload.
- **Plan-stage / EC-005 superseded-canonical detection.** Apply re-fetches the manifest at start (using Chunk 002's verifier) and compares the served manifest hash against the plan's `canonical_identity.manifest_hash`. Mismatch → warn-and-offer-re-diagnose path; match → proceed with apply. The warn diagnostic names the served canonical's block height vs. the plan's pinned block height.
- **Plan-stage / EC-002 partial-pocketdb plan contract.** Missing-file divergences in the plan are encoded as full-file entries with an explicit `expected_source: "fetch_full"` marker (or equivalent). Apply consumes them identically to whole-file divergences — the same fetch + stage + verify + rename path. Differs only in the absence of a pre-apply shadow (no original to shadow).
- **Plan-stage / inherited language, HTTP client, and SQLite library.** Chunk 003 inherits the Go language pin from pre-spec Implementation Context (same toolchain Chunk 002 builds against). HTTP client is `net/http`; SQLite binding is the same one Chunk 002 chose. No second language, HTTP framework, or SQLite engine is introduced at this layer.
- **Tasks-stage / apply-time exit codes.** Chunk 003 allocates codes from the 10..19 range reserved by Chunk 002 for **mid-run** failures: 10 rollback completed (verification failed, pre-apply state restored), 11 rollback failed (verification failed AND restoration failed — operator intervention needed), 12 network retry budget exhausted, 13 reserved for future apply-time errors, 14 EC-005 superseded-canonical refusal (mid-run; pre-flight detects this only on diagnose where the plan does not yet exist), 15 plan tamper detected (EC-009). Manifest-format-version-unrecognized refusal uses code 7 (pre-flight block) regardless of phase per Chunk 002's categorization rule. Documented in Chunk 005 troubleshooting guide.

### What this chunk unblocks

- Operators can complete a real recovery against a real canonical.
- Chunk 004's drill scenario.

---

## Chunk 004: End-to-End Drill + Network Resilience

### Scope

Functional verification of the working doctor under adversarial conditions:

1. **End-to-end recovery drill (US-005).** Deliberately damaged node, recovered to a known-good state, validated by `pocketnet-core`'s `getbestblockhash` RPC.
2. **Intermittent-network hardening exercise (US-006).** Apply over connections that drop, exercising the resilience primitives from Chunk 003 under simulated failures.

These two are bundled because they share a code path (apply against the chunk store), a test rig pattern (the project-internal test node under VM-snapshot discipline), and a failure model (adverse runtime conditions on working software). They are FR-validating, not engineering work.

### Prior artifact boundaries

- Working doctor from Chunks 002 and 003 (Gate 003 → 004 passed).
- Real published canonical from Chunk 001 at a block height suitable for the drill.
- Project-internal test node available (per One-Time Setup Checklist).

### Functional requirements owned

No new FRs. This chunk validates FR-019 and FR-020 from Chunk 003 under realistic conditions.

### Edge cases owned

None new. All ECs are owned by Chunks 002 or 003.

### Behavioral criteria

- A deliberately damaged node recovers to a state where `pocketnet-core` starts and reports a block at or descended from the canonical's pinned block height.
- Apply on a 4 GB total-fetch with simulated 256 MB-spaced TCP-connection-kills completes via re-invocation without operator intervention beyond running the doctor again.
- Drill is reproducible from snapshot — the same damage injection produces the same diagnose plan and the same apply outcome.

### Testable success criteria

- **SC-007** End-to-end recovery drill restores the node so `pocketnet-core`'s `getbestblockhash` RPC returns a block at or descended from the canonical's pinned block height.
- **SC-008** Apply over an intermittent network connection (simulated drops every 256 MB on a 4 GB total fetch) completes the recovery without operator intervention beyond re-invocation.

### Speckit Stop Resolutions

- **Plan-stage / drill node provisioning.** Project-internal test node under virtual-machine-snapshot discipline. Pre-drill snapshot captured; post-drill snapshot is restored if the drill is re-run. Drill instrumentation (damage-injection script, observation of `getbestblockhash`) committed to `experiments/02-recovery-drill/` for reproducibility.
- **Plan-stage / SC-008 256 MB drop semantics.** "Drops every 256 MB" is realized as: an `iptables` rule with `REJECT --reject-with tcp-reset` triggered once per 256 MB of cumulative bytes transferred to the doctor's HTTP client. The connection-kill primitive is iptables alone — the rule applies on the simulator host between the doctor's HTTP client and the chunk store, sending a TCP RST that the client observes as a connection reset. The doctor's per-chunk retry-and-resume path (Chunk 003 FR-019, FR-020) is the unit under test. No in-binary instrumentation; the test exercises the real network code path.
- **Plan-stage / network-drop simulation tooling.** `iptables` on the drill host is the connection-kill primitive (per the SC-008 mapping above). `tc` (Linux Traffic Control) is **optional** for orthogonal rate-shaping (e.g., capping bandwidth at 10 Mbps to mimic a constrained operator link); `tc` is not part of the SC-008 verification path and is not required to pass Gate 004 → 005.
- **Tasks-stage / drill canonical provenance.** The drill canonical is produced by Chunk 001's server-side workflow at a pinned block height. Re-running the drill against a different block height requires updating the drill instrumentation; this is intentional friction to preserve drill reproducibility.

### What this chunk unblocks

- Chunk 005 (release polish) — release artifacts cannot ship until network resilience is exercised (Gate 004 → 005).

---

## Chunk 005: Release Polish

### Scope

Engineering work that makes Chunk 004's verified doctor a publicly distributable v1 artifact. Anchored in pre-spec Design Principle 9 ("operator-verifiable release artifacts").

- Multi-platform binary builds (Linux, macOS, Windows; single static binary per platform per Chunk 002 Speckit Stop Resolution).
- Release artifact signing.
- Verification key publication on the canonical publisher's distribution channel.
- Public download channel mirroring on the same channel as today's full-snapshot distribution; GitHub Releases for community discoverability.
- Troubleshooting guide covering every doctor exit code (codes 0..6 from Chunk 002; 10..19 from Chunk 003) with a diagnostic message and an operator action per code.
- README updated to "v1 released" with download links.

### Prior artifact boundaries

- Verified doctor from Chunk 004 (Gate 004 → 005 passed).
- Pre-spec Design Principle 9 (added in pre-spec v0.3.2).
- Trust-root constant for the v1 release canonical (re-pinned per One-Time Setup if different from Chunks 002/003 development pin).

### Functional requirements owned

No new doctor FRs. This chunk operationalizes pre-spec Design Principle 9 through release engineering.

### Edge cases owned

None.

### Behavioral criteria

- Released binaries are built from a tagged source revision.
- Released binaries are signed by the project's publisher key (Authenticode for Windows; GPG for Linux/macOS sha256sums).
- The verification key is published on the canonical publisher's distribution channel and is documented in the troubleshooting guide.
- Operators downloading v1 can verify the binary's signature against the published key using only standard platform tools (`gpg --verify` on Linux/macOS; `signtool verify` or PowerShell `Get-AuthenticodeSignature` on Windows).

### Testable success criteria

- **CSC005-001** Released binaries match a documented checksum and are signed by the published key. An out-of-band verifier (someone who is not the release author) confirms the signature using only the published key and standard tools.
- **CSC005-002** Troubleshooting guide enumerates every doctor exit code (one per refusal predicate plus apply-failure codes from Chunks 002 and 003) with at least one diagnostic message and one operator action per code.
- **CSC005-003** README points operators at the download channel and the verification-key publication location.

### Speckit Stop Resolutions

- **Plan-stage / release artifact hosting.** Hosted on the project-pinned publisher's HTTPS endpoint, same channel as full-snapshot distribution. GitHub Releases mirrors the artifacts.
- **Plan-stage / signing scheme.** Two distinct cryptographic systems administratively maintained by the same publisher: (a) **Authenticode (X.509)** for Windows binaries — required by the Windows trust model; uses an X.509 code-signing certificate. (b) **GPG (OpenPGP)** for Linux/macOS — signs a sha256sums file alongside the released binaries; uses an OpenPGP keypair. The two systems are independent; Authenticode and GPG cannot share a "key family" because the cryptographic primitives, certificate chains, and verification tools differ. Both verification keys (the X.509 cert chain and the GPG public key) are published on the canonical publisher's distribution channel and recorded in the project README with fingerprints.
- **Plan-stage / Windows code-signing path.** Authenticode signature using the project's X.509 publisher code-signing certificate (CA-issued or self-signed-with-published-cert; choice is plan-stage). Tooling: Windows SDK `signtool.exe` invoked from CI on a Windows runner.
- **Plan-stage / signing-key custody.** Both private keys (the X.509 code-signing private key and the GPG signing private key) are held in the CI provider's encrypted secret store. The build pipeline retrieves them at sign-time only and never persists them on a runner's disk after the signing step. Developer laptops never hold either private key in steady state. Hardware-token-based custody (e.g., a YubiKey under the project maintainer's physical control) is an upgrade path for a future release; v1 uses the CI secret store as the standard small-project practice.
- **Plan-stage / Windows installer.** Out of v1: installer / MSI / store distribution. v1 ships a signed `.exe` for Windows that runs from `cmd` or PowerShell. Installer is a delt.7 follow-up.
- **Plan-stage / build pipeline / CI.** Multi-platform build matrix (Linux x86_64, macOS arm64 + x86_64, Windows x86_64) on a CI runner that produces signed artifacts from a tagged source revision. Specific CI provider is a plan-stage decision; the constraint is "tagged → signed binaries → published artifacts" with no manual key handling on a developer laptop in steady state.
- **Plan-stage / on-doctor self-update.** Out of v1. Operators download new versions from the publisher's channel manually.
- **Plan-stage / version-pinning for the v1 release trust-root.** The v1 release canonical's trust-root constant is pinned at this chunk's start. The pinned value is documented in the release notes.

### What this chunk unblocks

- Public v1 release. Community begins running the doctor.
- Roadmap discussion: doctor `apply --full` mode subsuming the full-checkpoint download path; chain-anchored manifest verification; healthy-peer cross-check; on-doctor self-update.

---

## Per-Chunk Addenda

Per-chunk validation items beyond the integration-gate checklists.

### Chunk 001 addenda

- [ ] **Manifest schema documented** in `pocketnet_create_checkpoint` repo so future canonical formats can preserve compatibility intentionally.
- [ ] **Trust-root constant publication channel documented** so doctor builds can pin the right value at build time.
- [ ] **Smoke test:** at least one published canonical's manifest fetched and trust-root-verified by an out-of-band consumer (curl + sha256sum) before any doctor build consumes it.

#### Chunk 001 run signature (auto-chunk-runner + manual verify)

- **Run ID:** `f5df963f-6971-4d77-b75e-76eac70d2fdf`
- **Window:** auto pipeline 2026-04-30T14:35:12Z → halt at 2026-04-30T15:33:00Z; manual `/speckit.superb.verify` completion 2026-04-30T16:18Z
- **Feature branch + dir:** `002-001-delta-recovery-client-chunk-001` / `specs/002-001-delta-recovery-client-chunk-001/` (the `002-` prefix is `/speckit.specify`'s spec-ordinal iteration; not a runner defect)
- **Auto stage durations (s):** specify 381, clarify 266, plan 593, tasks 485, analyze 236, superb_review 163, superb_tdd 172, implement 1097. Auto subtotal: 3393s (~57 min).
- **Halt + recovery:** auto-runner halted at `superb_verify` (74s) on a bridge-resolver dependency — `verification-before-completion` skill present in the Claude plugin cache but absent from `~/.agents/skills/`. Two-part remediation, applied:
  1. Project-agnostic prompt-tune on `tools/chunk-runner/prompts/superb-verify.md` granting it the same plugin-cache fallback latitude `superb-tdd` already had.
  2. Manual `/speckit.superb.verify` invocation with the patched prompt context; passed cleanly.
- **Counts:** 53 / 53 tasks completed, 9 phase commits. 11 / 11 harness predicates green in fresh manual verify run. 8 CR001-* + 3 CSC001-* + 3 BC-* (14 spec requirements) verified.
- **Gate evidence:**
  - Gate 001-Schema → 002 → `evidence/gate-001-schema-to-002.md`
  - Gate 001 → 002 → `evidence/gate-001-to-002.md`
  - `CONTRACT-HANDOFF.md` documents the eleven-step harness invocation for `delt.3`'s deployment-time live re-run.
- **Spec-status flip:** Implemented → Verified (committed on the feature branch).
- **Outstanding (non-blocking):** `delt.3` (server-side implementation in the `pocketnet_create_checkpoint` sibling repo) is the contract consumer; this chunk delivered the contract artifacts + verification harness only. CSC001-003 live-canonical re-run deferred to `delt.3` deployment per `CONTRACT-HANDOFF.md`. BC-003 (operator-scale concurrent fetches) inherited from existing distribution channel; not load-tested in this chunk.

### Chunk 002 addenda

- [ ] **Plan-format library has unit tests** covering canonical-form serialization, self-hash round-trip, format-version field handling, `trust_anchors` reserved-block parsing, and tampering detection.
- [ ] **Manifest-verifier unit tests** include the trust-root mismatch case (correct refusal, no chunk-store fetch attempted) AND the future-format-version case (CSC002-002).
- [ ] **Pre-flight predicate unit tests** cover each of the five conditions in isolation; integration test confirms documented ordering.
- [ ] **Diagnose progress output** is human-readable on a real terminal; a 5-minute run on the reference rig does not produce silent stretches > 30 seconds.
- [ ] **CLI exit codes** documented in `--help` output (full table per Chunk 002 Speckit Stop Resolutions exit-code allocation).

### Chunk 003 addenda

- [ ] **Apply unit tests** cover the rollback path on simulated mid-rename failure, on simulated post-rename verification failure, and on simulated mid-fetch failure.
- [ ] **Resumability test** kills the apply process at three points (first chunk fetched, half chunks fetched, all chunks fetched but pre-rename) and confirms re-run completes without redundant fetches in each case.
- [ ] **Integrity-check failure injection** (synthetic SQLite corruption introduced post-rename) confirms `PRAGMA integrity_check` failure triggers rollback even if all per-chunk hashes verified.
- [ ] **Disk-cost measurement** on a representative apply run records observed peak (`pocketdb` size + staging size + shadow size) for the troubleshooting guide.
- [ ] **EC-005 detection unit test:** apply against a plan whose `canonical_identity.manifest_hash` does not match the served manifest's hash triggers the warn-and-offer path with the documented diagnostic.
- [ ] **EC-002 round-trip test:** diagnose against a partial pocketdb produces a plan with `expected_source: "fetch_full"` markers; apply consumes the plan and produces a complete pocketdb.
- [ ] **Concurrency stress test** at `--parallel 4` (default) and `--parallel 16` confirms no chunk-promotion ordering anomaly under load.

### Chunk 004 addenda

- [ ] **Drill runbook authored** at `experiments/02-recovery-drill/RUNBOOK.md` covering damage injection, doctor invocation, observation, and snapshot restore.
- [ ] **Drill executed** on the project-internal test node under virtual-machine snapshot discipline; pass/fail recorded.
- [ ] **Network-drop test executed** with the documented `tc` + iptables configuration; SC-008 confirmed against the real chunk store.
- [ ] **`tc` configuration committed** alongside the drill instrumentation so the test is reproducible by anyone with the test rig.

### Chunk 005 addenda

- [ ] **Release artifacts published and signature-verified** by an out-of-band party (sanity check that operators can verify too) — CSC005-001.
- [ ] **README updated** to "v1 released" and points operators at the download channel — CSC005-003.
- [ ] **Troubleshooting guide complete** covering every doctor exit code (Chunk 002 codes 0..6, Chunk 003 codes 10..19) with a diagnostic and an operator action per code — CSC005-002.
- [ ] **Verification key publication** on the canonical publisher's distribution channel; key fingerprint also recorded in README.
- [ ] **Open issues filed** for known v1 limitations (Windows installer, on-binary self-update, chain-anchored verification, healthy-peer cross-check) with explicit roadmap commitments.

---

## Companion Document

Stage 5 audited this chunking against [`audit-criteria.md`](../../docs/pre-spec-build/audit-criteria.md). The audit findings (CSA-* criteria including CSA-11 SpecKit Stop Coverage at chunk granularity) are recorded in [`pre-spec-strategic-chunking-audit.md`](pre-spec-strategic-chunking-audit.md) v0.1.0 and applied in this v0.2.0 revision.
