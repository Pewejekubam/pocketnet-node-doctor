---
version: 0.2.0
status: draft
created: 2026-04-30
last_modified: 2026-04-30
authors: [pewejekubam, claude]
related: pre-spec.md
changelog:
  - version: 0.2.0
    date: 2026-04-30
    summary: Stage 6 refinement — apply all Stage 5 chunking-audit findings (pre-spec-strategic-chunking-audit.md v0.1.0)
    changes:
      - "CSA-01-F01 (HIGH) closed: Chunk 4 split — Chunk 4 covers drill (US-005) + network resilience (US-006); Chunk 5 covers release polish; Gate 4 → 5 added so release artifacts cannot ship until network resilience is exercised"
      - "CSA-02-F01 (HIGH) closed: parallelism claim reframed — Chunk 1's manifest schema is a sub-deliverable that gates Chunk 2's start; full chunk store gates Gate 2 → 3 fetch-size verification"
      - "CSA-02-F02 (MEDIUM) closed: trust-root constant pinning recorded as a One-Time Setup Checklist item; Chunks 2 and 3 build against the same pinned value"
      - "CSA-03-F01 (MEDIUM) closed: EC-005 superseded-canonical detection mechanism added to Chunk 3 Speckit Stop Resolutions — apply re-fetches manifest and compares hash against plan's canonical_identity"
      - "CSA-03-F02 (LOW) closed: EC-002 partial-pocketdb contract pinned in Chunk 3 Speckit Stop Resolutions — missing-file divergences are encoded as full-file entries with a special expected-source marker"
      - "CSA-05-F01 (HIGH) closed: Gate 1 → 2 Content-Encoding predicate now pins HTTP 406 with a body naming supported encodings on no-match; binary verification predicate"
      - "CSA-05-F02 / CSA-08-F01 (HIGH) closed: SC-001's fetch-size half moved to Gate 3 → 4 (post-Chunk-3 integration where a real canonical exists); Gate 2 → 3 covers timing only against the reference rig and a synthetic divergent fixture"
      - "CSA-05-F03 (MEDIUM) closed: Gate 2 → 3 enumerates five pre-flight refusal predicates (running, ahead, version, capacity, permission); Gate 3 → 4 EC-011 entry downgraded to smoke-test continuation"
      - "CSA-08-F02 (MEDIUM) closed: CSC4-002 reworded as binary check (troubleshooting guide enumerates every doctor exit code with at least one diagnostic and one operator action per code)"
      - "CSA-09-F01 (MEDIUM) closed: FR-018 testable surface added to Chunk 2 — manifest schema includes format_version field and reserves trust_anchors block (empty in v1) for future trust-anchor mechanisms"
      - "CSA-09-F02 (LOW) closed: Progress Tracker Chunk 1 FR column now reads `CR1-001..008` (parseable) instead of free-text"
      - "CSA-10-F01 (LOW) closed: pre-spec amended to add Design Principle 9 (operator-verifiable release artifacts); Chunk 5 (release polish) now derives from the amended pre-spec"
      - "CSA-11-F01 (HIGH) closed: Chunk 2 Speckit Stop Resolution added — HTTP client library is the language-default standard library client; same library inherits to Chunk 3"
      - "CSA-11-F02 (HIGH) closed: pre-spec Implementation Context pins the canonical-form serialization rule (used by manifest trust-root and plan self-hash); SQLite library bindings pinned in Chunk 2 Speckit Stop Resolutions; Chunk 3 inherits"
      - "CSA-11-F03 (MEDIUM) closed: Chunk 2 Speckit Stop Resolution allocates exit codes 0..6 (success + five refusal predicates) and reserves 10..19 for apply-time failures (Chunk 3 inherits)"
      - "CSA-11-F04 (MEDIUM) closed: Chunk 2 Speckit Stop Resolution pins logging surface — plain-text stderr at info level, --verbose for debug, no structured logging in v1"
      - "CSA-11-F05 (MEDIUM) closed: Chunk 4 Speckit Stop Resolution maps SC-008's '256 MB drops' to a concrete tc + iptables rule (kill TCP connection once per 256 MB transferred to doctor's HTTP client)"
      - "CSA-11-F06 (LOW) closed: Chunk 5 Speckit Stop Resolution pins Windows code-signing path (Authenticode via project's existing publisher cert)"
      - "CSA-11-F07 (MEDIUM) closed: canonical-form serialization rule moved to pre-spec Implementation Context (write-back); both Chunk 1 manifest and Chunk 2 plan-format inherit a single source"
      - "Chunk count: 5. Numbering: 1, 2, 3, 4, 5 (sequential, no a/b/c suffixes per author preference)"
  - version: 0.1.0
    date: 2026-04-30
    summary: Initial strategic chunking — derives four implementation chunks from pre-spec.md v0.3.1, distributes US/FR/SC/EC ownership, declares infrastructure gates, and records per-chunk Speckit Stop Resolutions
    changes:
      - "Four chunks: server-side manifest + chunk store; client foundation + diagnose; client apply; drill + network + release polish"
      - "Server-side chunk (Chunk 1) declares integration contracts the pre-spec Implementation Context implies but does not enumerate as doctor FRs; its implementation lives in the sibling `pocketnet_create_checkpoint` repo via epic child delt.3"
      - "All 6 USs, 20 FRs, 8 SCs, 11 ECs from pre-spec v0.3.1 distributed across chunks; nothing deferred to a final-validation chunk"
      - "Per-chunk Speckit Stop Resolutions cover the chunk-level framings the pre-spec deliberately deferred (drill canonical source, CLI surface preservation for future --full mode, compression-encoding negotiation)"
      - "Empirical experiments (delt.1 cross-DB reuse, delt.2 chunk-store materialization, delt.5 worst-case Feb→Apr reuse) recorded as One-Time Setup Checklist items, not chunks"
      - "Infrastructure Gate Checklists between every chunk pair with concrete, verifiable predicates"
      - "Progress Tracker convention applied: Chunk | Title | FRs | SCs | Status, Status rightmost and capitalized"
---

# Pre-Spec Strategic Chunking: Delta Recovery Client for Pocketnet Operators

## Purpose

This document decomposes the implementation of `pocketnet-node-doctor` (specified by [`pre-spec.md`](pre-spec.md) v0.3.2) into five dependency-ordered implementation chunks. Each chunk is a self-contained, testable, debuggable unit fed independently to the speckit pipeline (`speckit.specify` → `speckit.implement`). The chunking thesis is that bounded chunks produce bounded, mergeable implementations.

The pre-spec is the source of truth. This document is derived from it and must remain consistent with it.

---

## Critical Path

```
Setup (empirical baselines, prereq experiments, trust-root pinning)
   │
   ▼
Chunk 1 — Server-Side: Manifest Schema (sub-deliverable) ──┐
   │                                                       │ Schema-freeze
   ▼                                                       │ unblocks Chunk 2
Chunk 1 (continued) — Manifest + Chunk Store Generation    │
   │                                                       │
   ├───────────────────────────────────────────────────────┤
   ▼                                                       ▼
Chunk 2 — Client Foundation + Diagnose ◄───── (real chunk store)
   │
   ▼
Chunk 3 — Client Apply
   │
   ▼
Chunk 4 — End-to-End Drill + Network Resilience
   │
   ▼
Chunk 5 — Release Polish
```

**Serial dependencies.** Chunk 2 requires Chunk 1's manifest schema frozen (a sub-deliverable, well in advance of the full chunk store). Chunk 3 requires Chunks 1 (full chunk store) and 2 (plan format). Chunk 4 requires Chunk 3 and a published canonical from Chunk 1 at a block height suitable for the drill. Chunk 5 requires Chunk 4 (don't ship release artifacts until network resilience is actually exercised).

**Parallelism.** Chunk 1's manifest-schema-freeze sub-deliverable gates Chunk 2's start. After schema freeze, Chunks 1 (chunk store completion) and 2 (diagnose implementation) may proceed concurrently. The chunk store must exist before Gate 2 → 3 verifies SC-001's fetch-size predicate.

**Convergence point.** End of Chunk 3 — at this point a recovering operator can complete a real diagnose-and-apply cycle against a real canonical. Chunks 4 and 5 harden that capability into a community-ready signed release.

---

## Progress Tracker

| Chunk | Title | FRs | SCs | Status |
|-------|-------|-----|-----|--------|
| 1 | Server-Side: Manifest Schema + Chunk Store Generation | CR1-001..008 | SC-007 (drill prerequisite) | Pending |
| 2 | Client Foundation + Diagnose | FR-001, FR-002, FR-003, FR-004, FR-005, FR-010, FR-011, FR-012, FR-013, FR-017, FR-018 | SC-001 (timing half), SC-002, SC-006 | Pending |
| 3 | Client Apply | FR-006, FR-007, FR-008, FR-009, FR-014, FR-015, FR-016, FR-019, FR-020 | SC-001 (fetch-size half), SC-003, SC-004, SC-005 | Pending |
| 4 | End-to-End Drill + Network Resilience | (no new FRs; integration of all prior) | SC-007, SC-008 | Pending |
| 5 | Release Polish | (no new FRs; engineering work for Design Principle 9) | (no new SCs; CSC5-* below) | Pending |

---

## One-Time Setup Checklist

Pre-implementation prerequisites. None of these are implementation chunks; they are environment, data, or measurement work that must complete before or alongside the chunks.

- [ ] **Pre-spec is at `status: approved`** in frontmatter (Stage 6 exit; chunking is currently `draft`).
- [ ] **Empirical baseline reuse measurement on `main.sqlite3` March → April** is captured (delt.1 follow-up; the original 85.83% measurement validates the pre-spec's bandwidth claim — this checkbox is the audit-trail confirmation that the experiment artifact lives at `experiments/01-page-alignment-baseline/`).
- [ ] **Cross-DB reuse pattern measured on `web.sqlite3`** to confirm the page-level reuse pattern is not unique to `main.sqlite3` (delt.1).
- [ ] **March → April chunk store materialization** to validate compressed delta size against the projected ~13–15 GB target (delt.2).
- [ ] **Worst-case bracket reuse rate measured (Feb → April)** to confirm the design holds across longer-than-30-day intervals; expected reuse rate floor ≥ 50% (delt.5).
- [ ] **Project test rig matches SC-001 reference rig** (8 vCPU x86_64 host, NVMe-class disk, 16 GB RAM) or alternative reference is documented and SC-001 is amended.
- [ ] **Trust-root constant value is published and pinned in build configuration** for Chunks 2 and 3 development. Re-pin only when Chunk 5 chooses the v1 release canonical. Chunks 2 and 3 must build against the same pinned value to avoid integration-time drift.
- [ ] **Project-internal test node** stopped, snapshotted (virtual-machine snapshot), and confirmed dead-state reproducible before Chunk 4 drill commences.

---

## Infrastructure Gate Checklists

Each gate is a concrete, verifiable predicate that must hold before the next chunk can begin.

### Gate 0 → 1: Empirical baselines validated

After One-Time Setup completes, before Chunk 1 begins.

- [ ] **All measurement experiments closed** (delt.1, delt.2, delt.5) with results matching pre-spec projections (≥ 50% reuse worst-case; ~13–15 GB compressed delta).
- [ ] **Trust-root constant pinned** for Chunks 2 and 3 development.

### Gate 1-Schema → 2: Manifest schema frozen

A Chunk 1 sub-gate. After Chunk 1's manifest schema is authored and published as a contract, before Chunk 2 begins. Chunk 1 may continue developing the chunk store after this sub-gate; Chunk 2 begins in parallel.

- [ ] **Manifest schema document published** in the project's repo or a stable URL — JSON schema or equivalent that enumerates every required field, including `format_version`, `canonical_identity`, per-file entries with page-grid offsets for `main.sqlite3`, and the reserved `trust_anchors` block.
- [ ] **Canonical-form serialization rule cited** by the schema document (sorted keys, no insignificant whitespace, UTF-8) so Chunk 2's plan-format library and Chunk 1's manifest generator hash identically.

### Gate 1 → 2: Chunk Store Available (full)

After Chunk 1's chunk store completes, before Gate 2 → 3 fetch-size verification (Chunk 2 dev work may proceed against a mock chunk store after Gate 1-Schema → 2; the full chunk store is needed for Chunk 3 entry).

- [ ] **Manifest URL serves a manifest for a pinned canonical block height** — `curl -s <manifest-url> | sha256sum` returns a known hash that matches the project-pinned trust-root constant.
- [ ] **Manifest fields parse cleanly** per the frozen schema.
- [ ] **Chunk URLs serve verified chunks** — for at least three sampled chunks (one `main.sqlite3` page, one `blocks/` file, one `chainstate/` file), `curl -s <chunk-url> | sha256sum` matches the manifest's recorded hash for that chunk.
- [ ] **Content-Encoding negotiation works to a single pinned contract** — chunk requests with `Accept-Encoding: zstd` return zstd-encoded payloads; with `Accept-Encoding: gzip` return gzip-encoded payloads. Absence of either supported encoding in `Accept-Encoding` returns **HTTP 406 Not Acceptable** with a body naming supported encodings (`zstd`, `gzip`). Verifiable: `curl -H 'Accept-Encoding: identity' <chunk-url>` returns HTTP 406 and a body containing both encoding names.

### Gate 2 → 3: Plan Format Round-Trips

After Chunk 2 merges, before Chunk 3 begins.

- [ ] **Diagnose against a synthetic divergent fixture produces a plan within the timing budget** — running diagnose against a fixture pocketdb on the reference rig completes within 5 minutes (timing half of SC-001). Fixture-based test, no real canonical required.
- [ ] **Diagnose on a fixture identical to canonical produces a zero-entry plan** (per SC-002).
- [ ] **Plan self-hash verifies** — recomputing SHA-256 over the plan's canonical-form payload (sorted keys, no insignificant whitespace, with `self_hash` field removed) equals the plan's declared `self_hash`.
- [ ] **Plan canonical identity is bound** — diagnoses against two different fixture-canonicals produce plans with different `canonical_identity` blocks.
- [ ] **All five pre-flight refusal predicates fire correctly** — running diagnose with (a) `pocketnet-core` running, (b) ahead-of-canonical local node, (c) version mismatch, (d) insufficient volume capacity, (e) read-only / permission-denied volume each refuses with a distinct exit code (per SC-006 + EC-011).

### Gate 3 → 4: Apply Round-Trips Against Real Canonical

After Chunk 3 merges, before Chunk 4 begins.

- [ ] **Apply against a real plan results in canonical-matching pocketdb** — every file's hash matches the canonical manifest after apply; `PRAGMA integrity_check` returns "ok" (per SC-003).
- [ ] **SC-001 fetch-size predicate verified** — on a node 30 days behind canonical, the diagnose-emitted plan's total fetch size is ≤ 25% of the full snapshot size (the fetch-size half of SC-001 that requires a real canonical).
- [ ] **Mid-apply interruption resumes cleanly** — killing the apply process during fetch and re-running with the same plan completes without re-fetching previously-fetched chunks (per SC-004).
- [ ] **Verification failure rolls back** — simulating a chunk-store byte error results in observable rollback to pre-apply state (per SC-005).
- [ ] **EC-011 smoke check** — apply on a read-only mount surfaces the permission refusal at pre-flight (continuation regression check; primary verification is at Gate 2 → 3).

### Gate 4 → 5: Network Resilience Validated

After Chunk 4 merges, before Chunk 5 begins.

- [ ] **End-to-end drill passes on the project-internal test node** — damaged node recovered to canonical-matching state; `pocketnet-core`'s `getbestblockhash` RPC returns a block at or descended from the canonical's pinned block height (per SC-007).
- [ ] **Network-drop scenario completes via re-invocation** — apply on a 4 GB total-fetch with simulated 256 MB-spaced network drops completes the recovery without operator intervention beyond running the doctor again (per SC-008).
- [ ] **Drill runbook reproduces** — a second drill execution from snapshot follows the runbook step-by-step and produces the same outcome.

---

## Chunk 1: Server-Side Manifest Schema + Chunk Store Generation

### Scope

Extend the existing `pocketnet_create_checkpoint` workflow to produce alongside the full-snapshot artifact:

1. A frozen **manifest schema document** (sub-deliverable; gates Chunk 2's start).
2. A **manifest** for each published canonical, conforming to the schema.
3. A **chunk store** — HTTPS-addressable byte source from which differing chunks are fetched.
4. A published **trust-root SHA-256** of each canonical's manifest.

The implementation lives in the `pocketnet_create_checkpoint` repo (epic child delt.3). This chunking document treats Chunk 1 as a contract.

### Prior artifact boundaries

- Pre-spec v0.3.2 — source of truth.
- Existing `pocketnet_create_checkpoint` workflow.

### Functional contract (chunk-specific FRs)

These are not pre-spec FRs (pre-spec is doctor-side). They are integration contracts derived from doctor expectations.

- **CR1-001** Chunk-store HTTPS endpoint serves a JSON manifest at a stable URL for each published canonical block height. Manifest carries `format_version`, `canonical_identity` (`block_height`, `pocketnet_core_version`, `created_at`), per-file entries, and a reserved `trust_anchors` block (empty in v1).
- **CR1-002** Per-file entries for `main.sqlite3` enumerate page-level hashes at the 4 KB SQLite page boundary, addressable by `(path, offset)`.
- **CR1-003** Per-file entries for non-SQLite artifacts carry whole-file SHA-256 hashes.
- **CR1-004** Chunk URLs are addressable as discrete HTTPS GETs.
- **CR1-005** Server honors `Accept-Encoding: zstd` and `Accept-Encoding: gzip`; payloads are pre-compressed and cached server-side. Absence of either supported encoding returns HTTP 406 with a body naming supported encodings.
- **CR1-006** SHA-256 of the canonical-form manifest payload (per pre-spec Implementation Context's canonical-form rule) is published alongside the manifest as the trust-root constant.
- **CR1-007** Manifest declares the `change_counter` SQLite header value for `main.sqlite3` so doctor's pre-flight ahead-of-canonical check (FR-011) has a reference.
- **CR1-008** Server publishes manifests no older than 30 days.

### Edge cases owned

None directly from pre-spec EC list. Server-side EC behavior is addressed in delt.3.

### Behavioral criteria

- A doctor binary built against the trust-root for canonical at block height H can authenticate that exact manifest and only that manifest.
- Two doctor binaries built against the same trust-root see the same canonical when both fetch the manifest URL.
- The chunk store survives concurrent fetches at typical operator scale.

### Testable success criteria

- **CSC1-001** All Gate 1-Schema → 2 predicates pass.
- **CSC1-002** All Gate 1 → 2 predicates pass for a canonical published by the server-side workflow.
- **CSC1-003** Drill prerequisite: at least one canonical is published whose block height is suitable for Chunk 4's drill.

### Speckit Stop Resolutions

- **Plan-stage / language and runtime for the manifest generator.** Use the existing `pocketnet_create_checkpoint` workflow's language and runtime. Do not introduce a new language; extend the existing tooling.
- **Plan-stage / chunk-store hosting topology.** Same hosting channel as today's full-snapshot distribution.
- **Plan-stage / compression choice on the server side.** Pre-compress chunks with both Zstandard and gzip; serve per `Accept-Encoding`; absence of either supported encoding returns HTTP 406 (CR1-005).
- **Plan-stage / canonical-form serialization ownership.** Pre-spec Implementation Context (v0.3.2) is the authoritative source for the canonical-form rule (sorted keys, no insignificant whitespace, UTF-8). Both the manifest-trust-root hash (this chunk) and the plan-self-hash (Chunk 2) inherit. No chunk owns the rule independently.
- **Tasks-stage / manifest schema publication.** The manifest schema is published as a JSON-schema-format document (or equivalent) in the project's docs or at a stable URL before the chunk store is built. Schema-freeze is Gate 1-Schema → 2.
- **Plan-stage / drill canonical source (PSA-11-F06).** A canonical published by this chunk is the drill canonical for Chunk 4. The drill rig's doctor binary is built against this canonical's trust-root.

### What this chunk unblocks

- Chunk 2 may begin after manifest schema freeze (Gate 1-Schema → 2).
- Chunk 3 may begin after the full chunk store is available (Gate 1 → 2).
- Chunk 4 drill scenario requires this chunk's published canonical.

---

## Chunk 2: Client Foundation + Diagnose

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
- Chunk 1's frozen manifest schema (Gate 1-Schema → 2).
- Chunk 1's published trust-root constant (compiled in at build time per One-Time Setup).
- Pre-spec Implementation Context's canonical-form serialization rule (used by the plan-format library).

### Functional requirements owned

- **FR-001** through **FR-005** (diagnose surface).
- **FR-010** through **FR-013** (refusal predicates) plus **EC-011** as a fifth predicate.
- **FR-017** and **FR-018** (trust-root authentication and forward-compatibility).

### Edge cases owned

- **EC-001** (diagnose-side handling of completely-missing pocketdb).
- **EC-002** (diagnose-side handling of partially-present pocketdb; apply-side contract owned by Chunk 3).
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

- **SC-001 (timing half)** On a fixture pocketdb 30 days behind a canonical fixture, diagnose completes within 5 minutes on the reference rig. The fetch-size half of SC-001 is verified at Gate 3 → 4 against a real canonical.
- **SC-002** On a node identical to canonical, diagnose emits a zero-entry plan and exits cleanly within 5 minutes.
- **SC-006** Each refusal predicate (five total) blocks with a distinct exit code per the allocation in this chunk's Speckit Stop Resolutions; no bytes modified.
- **CSC2-001** Plan self-hash round-trip: emitted plan's `self_hash` field equals SHA-256 over its canonical-form payload (with `self_hash` removed), using the pre-spec Implementation Context canonical-form rule.
- **CSC2-002** Manifest-format-version refusal: a manifest with an unrecognized future `format_version` causes diagnose to refuse with a distinct exit code naming the version mismatch.

### Speckit Stop Resolutions

- **Plan-stage / language and runtime.** Single static binary, three platforms (Linux, macOS, Windows), no runtime dependencies. Specific language (Go, Rust, Zig) is a plan-stage decision under that constraint.
- **Plan-stage / CLI surface (`--full` mode preservation).** Subcommands (`diagnose`, `apply`); reserves namespace for a future `apply --full` subsumption mode per pre-spec Stage 4 hand-off note. No subcommand-collapsed-into-flags structure.
- **Plan-stage / HTTP client library.** Language-default standard library client (Go `net/http`, Rust standard `hyper` / `reqwest`, Zig standard library, equivalent for whatever language is chosen). No bespoke HTTP framework. Connection re-use is enabled at the worker-pool level when Chunk 3 implements parallel chunk fetches; same library inherits to Chunk 3.
- **Plan-stage / SQLite library bindings.** A single SQLite library binding for the chosen language (e.g., Go `mattn/go-sqlite3` or `modernc.org/sqlite`, Rust `rusqlite`, equivalent). The library is used by Chunk 2 for the post-apply `integrity_check` (Chunk 3 inherits) and by Chunk 2's `change_counter` ahead-of-canonical check via direct file-header parsing where possible. Same binding inherits to Chunk 3 to avoid linking two SQLite engines.
- **Plan-stage / logging surface.** Plain-text to stderr at info level by default; `--verbose` flag enables debug. No structured logging in v1; no log-file output. Diagnose progress reporting (next bullet) reuses the same stderr surface.
- **Plan-stage / progress reporting on long diagnose runs.** Diagnose emits progress to stderr at file-class boundaries (`main.sqlite3` page hashing milestones, `blocks/` file-by-file, etc.) so operators see liveness on long runs. Format is human-readable; not a structured machine protocol.
- **Plan-stage / configuration storage.** No user-config file in v1. Behavior controlled by CLI flags only. Trust-root compiled in.
- **Plan-stage / FR-018 forward-compat surface.** The manifest schema declares a `format_version` field (current value 1) and a reserved `trust_anchors` block (empty in v1). Future canonicals can populate `trust_anchors` with chain-anchored verification fields, healthy-peer cross-check fields, or other trust evidence without breaking v1 parsers. v1 parsers ignore unknown contents of `trust_anchors` but parse and validate the field's presence. This is the testable surface for FR-018 (CSC2-002 covers the version-mismatch path).
- **Clarify-stage / plan filename and location.** `plan.json` written alongside the operator's pocketdb-parent directory by default, overrideable with `--plan-out <path>`.
- **Tasks-stage / pre-flight predicate ordering.** Predicates execute in order: running-node check → version-mismatch check → volume-capacity check → permission/read-only check → ahead-of-canonical check.
- **Tasks-stage / exit-code allocation.** `0` success. `1` generic error. `2..6` the five refusal predicates (running-node 2, ahead-of-canonical 3, version mismatch 4, capacity 5, permission/read-only 6). `10..19` reserved for apply-time failures (Chunk 3 inherits and allocates: e.g., 10 rollback completed, 11 rollback failed, 12 network exhausted, 13 manifest-format-version unrecognized, others as Chunk 3 needs). Codes documented in `--help` output and the Chunk 5 troubleshooting guide.

### What this chunk unblocks

- Chunk 3 (apply) can begin once the plan format is stable.
- Operators can run `pocketnet-node-doctor diagnose` and see what their recovery would entail without mutation risk.

---

## Chunk 3: Client Apply

### Scope

The doctor's mutating pathway:

- Apply phase (US-002).
- Verification (US-004): pre-rename per-chunk SHA-256 against manifest; post-apply whole-file SHA-256 + SQLite native consistency check.
- Network resilience primitives (FR-019, FR-020).

### Prior artifact boundaries

- Pre-spec v0.3.2.
- Chunk 1's chunk store (Gate 1 → 2 passed).
- Chunk 2's plan-format library, plan, manifest verifier, hash utilities, pre-flight refusal predicates, HTTP client library choice, SQLite library binding, exit-code allocation (codes 10..19 reserved for this chunk).
- Same trust-root constant pinned in build configuration (One-Time Setup) — Chunk 3 builds against the same value Chunk 2 was tested against.

### Functional requirements owned

- **FR-006** through **FR-009** (apply mutating).
- **FR-014** through **FR-016** (verification + rollback).
- **FR-019** and **FR-020** (network resilience).

### Edge cases owned

- **EC-001** (apply-side handling of completely-missing pocketdb — full-fetch sub-plan; complementary to Chunk 2's diagnose-side coverage).
- **EC-002** (apply-side handling of partially-present pocketdb; consumes the contract Chunk 2 declares).
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

- **SC-001 (fetch-size half)** On a node 30 days behind canonical, the diagnose-emitted plan's total fetch size is ≤ 25% of the full snapshot size. Verified at Gate 3 → 4 against the real Chunk 1 canonical.
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
- **Plan-stage / Content-Encoding negotiation.** Apply's HTTP client sends `Accept-Encoding: zstd, gzip`. Server returns the preferred encoding per Chunk 1's HTTP-406-on-no-match contract; client decompresses transparently before hashing. Hash is over the uncompressed payload.
- **Plan-stage / EC-005 superseded-canonical detection.** Apply re-fetches the manifest at start (using Chunk 2's verifier) and compares the served manifest hash against the plan's `canonical_identity.manifest_hash`. Mismatch → warn-and-offer-re-diagnose path; match → proceed with apply. The warn diagnostic names the served canonical's block height vs. the plan's pinned block height.
- **Plan-stage / EC-002 partial-pocketdb plan contract.** Missing-file divergences in the plan are encoded as full-file entries with an explicit `expected_source: "fetch_full"` marker (or equivalent). Apply consumes them identically to whole-file divergences — the same fetch + stage + verify + rename path. Differs only in the absence of a pre-apply shadow (no original to shadow).
- **Plan-stage / inherited HTTP client and SQLite library.** Chunk 3 uses the same HTTP client library and SQLite binding chosen by Chunk 2. No second library is introduced at this layer.
- **Tasks-stage / apply-time exit codes.** Chunk 3 allocates codes from the 10..19 range reserved by Chunk 2: 10 rollback completed (verification failed, pre-apply state restored), 11 rollback failed (verification failed AND restoration failed — operator intervention needed), 12 network retry budget exhausted, 13 manifest-format-version unrecognized at apply time, 14 EC-005 superseded-canonical refusal, 15 plan tamper detected (EC-009). Documented in Chunk 5 troubleshooting guide.

### What this chunk unblocks

- Operators can complete a real recovery against a real canonical.
- Chunk 4's drill scenario.

---

## Chunk 4: End-to-End Drill + Network Resilience

### Scope

Functional verification of the working doctor under adversarial conditions:

1. **End-to-end recovery drill (US-005).** Deliberately damaged node, recovered to a known-good state, validated by `pocketnet-core`'s `getbestblockhash` RPC.
2. **Intermittent-network hardening exercise (US-006).** Apply over connections that drop, exercising the resilience primitives from Chunk 3 under simulated failures.

These two are bundled because they share a code path (apply against the chunk store), a test rig pattern (the project-internal test node under VM-snapshot discipline), and a failure model (adverse runtime conditions on working software). They are FR-validating, not engineering work.

### Prior artifact boundaries

- Working doctor from Chunks 2 and 3 (Gate 3 → 4 passed).
- Real published canonical from Chunk 1 at a block height suitable for the drill.
- Project-internal test node available (per One-Time Setup Checklist).

### Functional requirements owned

No new FRs. This chunk validates FR-019 and FR-020 from Chunk 3 under realistic conditions.

### Edge cases owned

None new. All ECs are owned by Chunks 2 or 3.

### Behavioral criteria

- A deliberately damaged node recovers to a state where `pocketnet-core` starts and reports a block at or descended from the canonical's pinned block height.
- Apply on a 4 GB total-fetch with simulated 256 MB-spaced TCP-connection-kills completes via re-invocation without operator intervention beyond running the doctor again.
- Drill is reproducible from snapshot — the same damage injection produces the same diagnose plan and the same apply outcome.

### Testable success criteria

- **SC-007** End-to-end recovery drill restores the node so `pocketnet-core`'s `getbestblockhash` RPC returns a block at or descended from the canonical's pinned block height.
- **SC-008** Apply over an intermittent network connection (simulated drops every 256 MB on a 4 GB total fetch) completes the recovery without operator intervention beyond re-invocation.

### Speckit Stop Resolutions

- **Plan-stage / drill node provisioning.** Project-internal test node under virtual-machine-snapshot discipline. Pre-drill snapshot captured; post-drill snapshot is restored if the drill is re-run. Drill instrumentation (damage-injection script, observation of `getbestblockhash`) committed to `experiments/02-recovery-drill/` for reproducibility.
- **Plan-stage / SC-008 256 MB drop semantics.** "Drops every 256 MB" is realized as: kill the active TCP connection (via `tc` egress policy combined with iptables `REJECT --reject-with tcp-reset` rules on the simulator host) once per 256 MB of cumulative bytes transferred to the doctor's HTTP client. The doctor's per-chunk retry-and-resume path (Chunk 3 FR-019, FR-020) is the unit under test. No in-binary instrumentation; the test exercises the real network code path.
- **Plan-stage / network-drop simulation tooling.** Linux `tc` (Traffic Control) plus `iptables` on the drill host. Avoids in-binary instrumentation that would bypass the doctor's real network code path.
- **Tasks-stage / drill canonical provenance.** The drill canonical is produced by Chunk 1's server-side workflow at a pinned block height. Re-running the drill against a different block height requires updating the drill instrumentation; this is intentional friction to preserve drill reproducibility.

### What this chunk unblocks

- Chunk 5 (release polish) — release artifacts cannot ship until network resilience is exercised (Gate 4 → 5).

---

## Chunk 5: Release Polish

### Scope

Engineering work that makes Chunk 4's verified doctor a publicly distributable v1 artifact. Anchored in pre-spec Design Principle 9 ("operator-verifiable release artifacts").

- Multi-platform binary builds (Linux, macOS, Windows; single static binary per platform per Chunk 2 Speckit Stop Resolution).
- Release artifact signing.
- Verification key publication on the canonical publisher's distribution channel.
- Public download channel mirroring on the same channel as today's full-snapshot distribution; GitHub Releases for community discoverability.
- Troubleshooting guide covering every doctor exit code (codes 0..6 from Chunk 2; 10..19 from Chunk 3) with a diagnostic message and an operator action per code.
- README updated to "v1 released" with download links.

### Prior artifact boundaries

- Verified doctor from Chunk 4 (Gate 4 → 5 passed).
- Pre-spec Design Principle 9 (added in pre-spec v0.3.2).
- Trust-root constant for the v1 release canonical (re-pinned per One-Time Setup if different from Chunks 2/3 development pin).

### Functional requirements owned

No new doctor FRs. This chunk operationalizes pre-spec Design Principle 9 through release engineering.

### Edge cases owned

None.

### Behavioral criteria

- Released binaries are reproducibly built from a tagged source revision.
- Released binaries are signed by the project's publisher key.
- The verification key is published on the canonical publisher's distribution channel and is documented in the troubleshooting guide.
- Operators downloading v1 can verify the binary's signature against the published key using only standard platform tools (`gpg --verify` on Linux/macOS; `signtool verify` or PowerShell `Get-AuthenticodeSignature` on Windows).

### Testable success criteria

- **CSC5-001** Released binaries match a documented checksum and are signed by the published key. An out-of-band verifier (someone who is not the release author) confirms the signature using only the published key and standard tools.
- **CSC5-002** Troubleshooting guide enumerates every doctor exit code (one per refusal predicate plus apply-failure codes from Chunks 2 and 3) with at least one diagnostic message and one operator action per code.
- **CSC5-003** README points operators at the download channel and the verification-key publication location.

### Speckit Stop Resolutions

- **Plan-stage / release artifact hosting.** Hosted on the project-pinned publisher's HTTPS endpoint, same channel as full-snapshot distribution. GitHub Releases mirrors the artifacts.
- **Plan-stage / signing scheme.** Long-lived publisher key. Public component published in the project README and on the canonical publisher's distribution channel. Authenticode signature for Windows binaries; GPG-signed sha256sums file for Linux/macOS binaries (or platform-equivalent).
- **Plan-stage / Windows code-signing path.** Authenticode signature using the project's existing publisher cert. Same key family as macOS/Linux GPG signing where possible (or a Windows-specific certificate of the same provenance). Tooling: Windows SDK `signtool.exe` invoked from CI on a Windows runner.
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

### Chunk 1 addenda

- [ ] **Manifest schema documented** in `pocketnet_create_checkpoint` repo so future canonical formats can preserve compatibility intentionally.
- [ ] **Trust-root constant publication channel documented** so doctor builds can pin the right value at build time.
- [ ] **Smoke test:** at least one published canonical's manifest fetched and trust-root-verified by an out-of-band consumer (curl + sha256sum) before any doctor build consumes it.

### Chunk 2 addenda

- [ ] **Plan-format library has unit tests** covering canonical-form serialization, self-hash round-trip, format-version field handling, `trust_anchors` reserved-block parsing, and tampering detection.
- [ ] **Manifest-verifier unit tests** include the trust-root mismatch case (correct refusal, no chunk-store fetch attempted) AND the future-format-version case (CSC2-002).
- [ ] **Pre-flight predicate unit tests** cover each of the five conditions in isolation; integration test confirms documented ordering.
- [ ] **Diagnose progress output** is human-readable on a real terminal; a 5-minute run on the reference rig does not produce silent stretches > 30 seconds.
- [ ] **CLI exit codes** documented in `--help` output (full table per Chunk 2 Speckit Stop Resolutions exit-code allocation).

### Chunk 3 addenda

- [ ] **Apply unit tests** cover the rollback path on simulated mid-rename failure, on simulated post-rename verification failure, and on simulated mid-fetch failure.
- [ ] **Resumability test** kills the apply process at three points (first chunk fetched, half chunks fetched, all chunks fetched but pre-rename) and confirms re-run completes without redundant fetches in each case.
- [ ] **Integrity-check failure injection** (synthetic SQLite corruption introduced post-rename) confirms `PRAGMA integrity_check` failure triggers rollback even if all per-chunk hashes verified.
- [ ] **Disk-cost measurement** on a representative apply run records observed peak (`pocketdb` size + staging size + shadow size) for the troubleshooting guide.
- [ ] **EC-005 detection unit test:** apply against a plan whose `canonical_identity.manifest_hash` does not match the served manifest's hash triggers the warn-and-offer path with the documented diagnostic.
- [ ] **EC-002 round-trip test:** diagnose against a partial pocketdb produces a plan with `expected_source: "fetch_full"` markers; apply consumes the plan and produces a complete pocketdb.
- [ ] **Concurrency stress test** at `--parallel 4` (default) and `--parallel 16` confirms no chunk-promotion ordering anomaly under load.

### Chunk 4 addenda

- [ ] **Drill runbook authored** at `experiments/02-recovery-drill/RUNBOOK.md` covering damage injection, doctor invocation, observation, and snapshot restore.
- [ ] **Drill executed** on the project-internal test node under virtual-machine snapshot discipline; pass/fail recorded.
- [ ] **Network-drop test executed** with the documented `tc` + iptables configuration; SC-008 confirmed against the real chunk store.
- [ ] **`tc` configuration committed** alongside the drill instrumentation so the test is reproducible by anyone with the test rig.

### Chunk 5 addenda

- [ ] **Release artifacts published and signature-verified** by an out-of-band party (sanity check that operators can verify too) — CSC5-001.
- [ ] **README updated** to "v1 released" and points operators at the download channel — CSC5-003.
- [ ] **Troubleshooting guide complete** covering every doctor exit code (Chunk 2 codes 0..6, Chunk 3 codes 10..19) with a diagnostic and an operator action per code — CSC5-002.
- [ ] **Verification key publication** on the canonical publisher's distribution channel; key fingerprint also recorded in README.
- [ ] **Open issues filed** for known v1 limitations (Windows installer, on-binary self-update, chain-anchored verification, healthy-peer cross-check) with explicit roadmap commitments.

---

## Companion Document

Stage 5 audited this chunking against [`audit-criteria.md`](../../docs/pre-spec-build/audit-criteria.md). The audit findings (CSA-* criteria including CSA-11 SpecKit Stop Coverage at chunk granularity) are recorded in [`pre-spec-strategic-chunking-audit.md`](pre-spec-strategic-chunking-audit.md) v0.1.0 and applied in this v0.2.0 revision.
