# Feature Specification: Server-Side Manifest Schema + Chunk Store Generation

**Feature Branch**: `002-001-delta-recovery-client-chunk-001`
**Created**: 2026-04-30
**Status**: Verified
**Input**: User description: "Chunk 001 of 001-delta-recovery-client. Extend the existing pocketnet_create_checkpoint workflow to publish a frozen manifest schema, a per-canonical manifest, an HTTPS-addressable chunk store, and a published trust-root SHA-256 alongside each full-snapshot artifact, so that the doctor (downstream chunks) can authenticate canonicals and fetch only differing chunks."

## Context anchors

- Authoritative scope source: [`pre-spec-strategic-chunking.md`](../001-delta-recovery-client/pre-spec-strategic-chunking.md) §Chunk 001.
- Pre-spec source of truth (US/FR/EC referenced from the doctor side): [`pre-spec.md`](../001-delta-recovery-client/pre-spec.md).
- This chunk is server-side. The implementation lives in the sibling `pocketnet_create_checkpoint` repo (epic child delt.3); the chunking document treats Chunk 001 as a contract that the doctor side consumes. Scope here is the contract, not the engineering inside that sibling repo.

## Clarifications

### Session 2026-04-30

- **Q1**: How does a per-file entry in the manifest distinguish "page-level / SQLite shape" (CR001-002) from "whole-file / non-SQLite shape" (CR001-003) — explicit `entry_kind` discriminator, or implied by the presence/absence of a page-array field?
  - **A1**: Deferred to /speckit.plan — see plan-layer decision: concrete shape of the manifest schema's per-file entry. The spec pins both shapes (page-level for `main.sqlite3`, whole-file for non-SQLite); the discriminator mechanism falls under the existing "Manifest schema document concrete format and publication URL pattern" plan-layer deferral.

- **Q2**: For per-file entries describing `main.sqlite3`, must the manifest enumerate page-level hashes for every 4 KB page in the canonical's file, or only a subset?
  - **A2**: Every page. Pre-spec FR-001/FR-002 require diagnose to identify "differing 4 KB pages of `main.sqlite3`" by comparing local pages to the canonical's published page hashes — coverage of the full canonical file is required. CR001-002 tightened in-place to make this explicit.

- **Q3**: Does CR001-007 (`change_counter` declared) apply only to `main.sqlite3`, or also to any other SQLite-shaped artifacts addressed under the page-level entry shape per the spec's Assumptions?
  - **A3**: Only `main.sqlite3`. Pre-spec FR-011 references the local `pocketdb/main.sqlite3` SQLite header `change_counter` exclusively; the ahead-of-canonical pre-flight check is the only consumer, and it operates on `main.sqlite3` alone. CR001-007 tightened in-place to remove ambiguity.

- **Q4**: How long does a published canonical's manifest URL remain accessible after a newer canonical is published? CR001-008 pins publication freshness (latest ≤ 30 days old) but does not pin retention of prior canonicals, which affects whether a doctor binary built against a given trust-root can resolve its manifest within its distribution-and-use window.
  - **A4**: Defensive default — revisit at /speckit.plan. CR001-001 specifies the manifest URL as "stable" without time bounds; pre-spec characterizes canonicals as "≤ 30 days old by operational policy" — a publication-freshness guarantee, not a retention guarantee. Conservative interpretation adopted: a published canonical's manifest URL remains accessible at least until the next canonical at a higher block height is published, so a doctor binary released against trust-root T can resolve T's manifest at any time within one publication cadence. The concrete retention SLO (e.g., last-N canonicals retained, or fixed-day retention window) is a publisher operational decision owned by the sibling `pocketnet_create_checkpoint` repo (delt.3) and a plan-layer concern here.

- **Q5**: Is the reserved `trust_anchors` block's empty-in-v1 form an empty object `{}`, an empty array `[]`, or `null`? The choice affects the canonical-form-hash output and therefore the trust-root constant — but the manifest generator (this chunk) and the doctor parser (Chunk 002) inherit a single schema, so consistency is determined by the schema document.
  - **A5**: Deferred to /speckit.plan — see plan-layer decision: concrete shape of the manifest schema. The schema document (plan-layer artifact under "Manifest schema document concrete format" deferral) pins the form; both producer and consumer derive the canonical-form-hash input from the same schema, so any single committed form satisfies BC-001/BC-002 determinism.

## User Scenarios & Testing *(mandatory)*

The "users" of this server-side feature are two consumer roles, not human end-users. The pocketnet operator (the eventual human consumer) is one step removed: they consume the doctor binary, which consumes the contract this chunk publishes.

### User Story 1 — Doctor consumes a published canonical (Priority: P1)

A doctor binary, built against a pinned trust-root constant, fetches the manifest URL for that canonical, authenticates the served manifest by hashing its canonical-form payload and comparing to the pinned constant, parses the manifest fields per the frozen schema, and uses the per-file entries to fetch only differing chunks via discrete HTTPS GETs.

**Why this priority**: This is the load-bearing contract — every downstream chunk (002 diagnose, 003 apply, 004 drill) depends on it. If a doctor cannot authenticate a manifest and locate a chunk, no downstream value is possible.

**Independent Test**: An out-of-band consumer (curl + sha256sum, no doctor binary needed) fetches a published manifest URL, computes SHA-256 over the canonical-form payload, and confirms the result equals the published trust-root constant for that canonical. Then sampled chunk URLs (one `main.sqlite3` page, one `blocks/` file, one `chainstate/` file) are fetched and their SHA-256 hashes match the manifest's recorded hashes.

**Acceptance Scenarios**:

1. **Given** a published canonical at block height H with a published trust-root constant T, **When** an out-of-band consumer fetches the manifest URL for H, **Then** the consumer can compute SHA-256 of the canonical-form payload and obtain T.
2. **Given** a published manifest for canonical at block height H, **When** an out-of-band consumer parses the manifest, **Then** the manifest validates against the frozen schema and exposes `format_version`, `canonical_identity` (with `block_height`, `pocketnet_core_version`, `created_at`), per-file entries, and a (possibly empty) `trust_anchors` block.
3. **Given** a per-file entry for `main.sqlite3` in a published manifest, **When** the consumer reads the entry, **Then** the entry enumerates page-level hashes at the 4 KB SQLite page boundary, each addressable by `(path, offset)`.
4. **Given** a per-file entry for a non-SQLite artifact (e.g., a file under `blocks/` or `chainstate/`), **When** the consumer reads the entry, **Then** the entry carries the whole-file SHA-256.
5. **Given** a manifest entry referencing a chunk, **When** the consumer issues a discrete HTTPS GET against the chunk URL, **Then** the server returns the chunk's bytes and the bytes' SHA-256 (computed over the uncompressed payload after any Content-Encoding is applied) matches the manifest's recorded hash.

---

### User Story 2 — Two doctor binaries, same trust-root, see the same canonical (Priority: P1)

Two independently built doctor binaries pinning the same trust-root constant T, fetching the same manifest URL, agree on the served canonical's identity. Neither binary will accept a manifest whose canonical-form-hash differs from T.

**Why this priority**: This is the determinism-and-pinning guarantee the chunking doc names as a behavioral criterion. Without it, "the same canonical" is not a meaningful concept across builds.

**Independent Test**: With trust-root T pinned in build configuration, two doctor binaries built from the same source revision but on different hosts (or by different developers) fetch the same manifest URL and report the identical canonical_identity block. Replacing the served manifest's payload with any other manifest causes both binaries to refuse with a trust-root mismatch.

**Acceptance Scenarios**:

1. **Given** two builds of a doctor binary pinning trust-root T, **When** both fetch the manifest URL for canonical at block height H, **Then** both authenticate the manifest and surface the same `canonical_identity` block.
2. **Given** a doctor binary pinning trust-root T, **When** the doctor fetches a manifest whose canonical-form payload hashes to a value other than T (i.e., any manifest other than the one T was minted from), **Then** the doctor refuses without fetching any chunk-store byte (this is the doctor-side EC-008 path; the contract owned here is "trust-root T uniquely identifies one manifest").

---

### User Story 3 — Doctor pre-flight reads SQLite ahead-of-canonical reference (Priority: P1)

A doctor performing the pre-flight ahead-of-canonical check (pre-spec FR-011) needs to compare the local `pocketdb/main.sqlite3` SQLite header `change_counter` field against the canonical's. The manifest declares the canonical's `change_counter` for `main.sqlite3` so the doctor has a reference value without parsing the canonical's database.

**Why this priority**: Without the declared `change_counter`, the doctor cannot perform pre-spec FR-011 cheaply at pre-flight time. The doctor would need to fetch and inspect bytes from the chunk store before refusing — defeating the "refuse before fetching" property the pre-flight predicates require.

**Independent Test**: A consumer parsing the manifest can read a single declared `change_counter` value associated with `main.sqlite3` and compare it numerically against any candidate value.

**Acceptance Scenarios**:

1. **Given** a published manifest, **When** the consumer reads the `main.sqlite3` per-file entry, **Then** the entry exposes the SQLite header `change_counter` value the canonical was minted with.
2. **Given** the declared `change_counter` value, **When** a doctor compares it against a local `change_counter`, **Then** the comparison is a simple numeric ordering (no further server interaction required).

---

### User Story 4 — Chunk delivery honors Accept-Encoding (Priority: P2)

A doctor's HTTP client sends `Accept-Encoding: zstd, gzip` when fetching a chunk. The server returns a pre-compressed payload in one of those encodings. When the request offers neither supported encoding, the server returns HTTP 406 Not Acceptable with a body that names the supported encodings.

**Why this priority**: Pre-compressed cached payloads are how the bandwidth win is realized in practice. The HTTP-406-with-body contract makes the "unsupported encoding" path observable and machine-checkable, not silent or ambiguous.

**Independent Test**: `curl -H 'Accept-Encoding: zstd' <chunk-url>` returns a zstd-encoded body that decompresses to the manifest-recorded bytes. `curl -H 'Accept-Encoding: gzip' <chunk-url>` does the same with gzip. `curl -H 'Accept-Encoding: identity' <chunk-url>` returns HTTP 406 and a body containing both the strings `zstd` and `gzip`.

**Acceptance Scenarios**:

1. **Given** a chunk URL and a request offering `Accept-Encoding: zstd`, **When** the server responds, **Then** the response carries `Content-Encoding: zstd` and the decompressed payload's SHA-256 equals the manifest's recorded hash for that chunk.
2. **Given** a chunk URL and a request offering `Accept-Encoding: gzip`, **When** the server responds, **Then** the response carries `Content-Encoding: gzip` and the decompressed payload's SHA-256 equals the manifest's recorded hash for that chunk.
3. **Given** a chunk URL and a request offering only an unsupported encoding (e.g., `identity`), **When** the server responds, **Then** the status is HTTP 406 and the response body names both supported encodings (`zstd` and `gzip`).

---

### User Story 5 — Server publishes manifests no older than 30 days (Priority: P2)

The publisher's release cadence keeps a recently-published canonical available so the doctor's design point — operators 30 days behind canonical — has a target.

**Why this priority**: Without a fresh-enough canonical, the doctor's bandwidth-saving design point cannot be exercised at typical operator cadence. This is a publisher-side service-level commitment, not a per-request contract.

**Independent Test**: At any sampled time, the manifest URL for the latest published canonical references a `created_at` timestamp no older than 30 days.

**Acceptance Scenarios**:

1. **Given** the publisher's running publication workflow, **When** a consumer fetches the latest canonical's manifest URL at any time, **Then** the manifest's `canonical_identity.created_at` is within 30 days of the current date.

---

### User Story 6 — Chunk 004 drill canonical exists (Priority: P2)

For Chunk 004's end-to-end drill to be possible, the publisher must have published at least one canonical at a block height suitable for the drill rig.

**Why this priority**: Chunk 004 is gated on the existence of this canonical. Without it, the integration drill cannot run, and the v1 release-polish (Chunk 005) is blocked on the gate that Chunk 004 → 005 imposes.

**Independent Test**: At least one canonical published by this chunk has been pinned as the drill canonical, its trust-root constant has been recorded for the drill rig's doctor build, and an out-of-band consumer can fetch its manifest and verify the trust-root.

**Acceptance Scenarios**:

1. **Given** a pinned drill canonical published by this chunk, **When** the drill rig's doctor build is configured, **Then** the build's pinned trust-root constant equals the published trust-root for that canonical.

---

### Edge Cases

This chunk owns no edge cases from the pre-spec EC list (the chunking doc §Chunk 001 explicitly states "None directly from pre-spec EC list. Server-side EC behavior is addressed in delt.3"). The Acceptance Scenarios above cover the only externally-observable boundary conditions in this chunk's contract surface:

- Trust-root mismatch on the doctor side is owned by Chunk 002 (EC-008). The contract owned here — "the published trust-root uniquely identifies one manifest" — is exercised in US-2 acceptance scenario 2.
- Unsupported `Accept-Encoding` returns HTTP 406 with a body naming supported encodings (US-4 acceptance scenario 3).
- The chunk store survives concurrent fetches at typical operator scale (BC-003 below).

Server-side internal failure modes (publisher pipeline failures, mirror outages, cache invalidation) are owned by the sibling `pocketnet_create_checkpoint` repo (epic child delt.3) and are out of scope for this contract spec.

## Requirements *(mandatory)*

### Functional Requirements

These are integration contracts, not pre-spec FRs (the pre-spec is doctor-side). Every CR001-* from §Chunk 001 of the chunking doc appears verbatim in scope:

- **CR001-001**: The chunk-store HTTPS endpoint MUST serve a JSON manifest at a stable URL for each published canonical block height. The manifest MUST carry `format_version`, `canonical_identity` (containing `block_height`, `pocketnet_core_version`, `created_at`), per-file entries, and a reserved `trust_anchors` block (empty in v1).
- **CR001-002**: Per-file entries for `main.sqlite3` MUST enumerate page-level hashes at the 4 KB SQLite page boundary, covering every 4 KB page of the canonical's file, each addressable by `(path, offset)`.
- **CR001-003**: Per-file entries for non-SQLite artifacts MUST carry whole-file SHA-256 hashes.
- **CR001-004**: Chunk URLs MUST be addressable as discrete HTTPS GETs.
- **CR001-005**: The server MUST honor `Accept-Encoding: zstd` and `Accept-Encoding: gzip`; payloads MUST be pre-compressed and cached server-side. Absence of either supported encoding in `Accept-Encoding` MUST return HTTP 406 with a body naming the supported encodings.
- **CR001-006**: The SHA-256 of the manifest's canonical-form payload (per the canonical-form rule pinned in pre-spec Implementation Context — sorted JSON keys, no insignificant whitespace, UTF-8) MUST be published alongside the manifest as the trust-root constant for that canonical.
- **CR001-007**: The manifest MUST declare the SQLite header `change_counter` value for `main.sqlite3` (and only `main.sqlite3`) so the doctor's pre-flight ahead-of-canonical check (pre-spec FR-011) has a reference. Other SQLite-shaped artifacts addressed under the page-level entry shape (per Assumptions) are not subject to this requirement, since FR-011 references `main.sqlite3` exclusively.
- **CR001-008**: The publisher MUST publish manifests no older than 30 days (continuous publication cadence; the latest published canonical's `created_at` MUST be within 30 days at any sampled moment).

### Non-functional behavioral criteria

These come from §Chunk 001 "Behavioral criteria" and must hold:

- **BC-001**: A doctor binary built against the trust-root constant for the canonical at block height H authenticates that exact manifest, and only that manifest. (Trust-root pins one and only one manifest.)
- **BC-002**: Two doctor binaries built against the same trust-root, fetching the same manifest URL, see the same canonical. (Determinism across builds.)
- **BC-003**: The chunk store survives concurrent fetches at typical operator scale.

### Key Entities

- **Manifest schema document**: A frozen schema describing the manifest's structure, required fields, and the canonical-form-hash rule the trust-root depends on. Published as a JSON-Schema-format document (or equivalent) at a stable URL before the chunk store is built. Schema-freeze is the gate that unblocks Chunk 002.
- **Manifest**: A per-canonical JSON document conforming to the manifest schema. Carries `format_version`, `canonical_identity` (`block_height`, `pocketnet_core_version`, `created_at`), per-file entries, the `main.sqlite3` `change_counter`, and a reserved `trust_anchors` block (empty in v1).
- **Per-file entry (main.sqlite3 variant)**: An entry enumerating page-level SHA-256 hashes at the 4 KB SQLite page boundary, addressable by `(path, offset)`.
- **Per-file entry (non-SQLite variant)**: An entry carrying the file's whole-file SHA-256 hash.
- **Chunk**: A discrete HTTPS-addressable byte source. For `main.sqlite3` a chunk is one 4 KB page identified by `(path, offset)`; for non-SQLite artifacts a chunk is the whole file.
- **Trust-root constant**: The published SHA-256 of the canonical-form manifest payload. Doctor binaries are built against this value (compiled in at build time via the One-Time Setup Checklist in the chunking doc).
- **Canonical (published)**: The end-to-end published artifact set for a single canonical block height — schema-conforming manifest, chunk store entries, and trust-root constant — together comprising one consumable canonical for the doctor.

## Success Criteria *(mandatory)*

### Measurable Outcomes

These are the testable success criteria from §Chunk 001 verbatim:

- **CSC001-001**: All Gate 001-Schema → 002 predicates pass — i.e., (a) the manifest schema document is published at a stable URL as a JSON Schema (Draft 2020-12, or current draft at time of authoring) enumerating every required field including `format_version`, `canonical_identity`, per-file entries with page-grid offsets for `main.sqlite3`, and the reserved `trust_anchors` block; AND (b) the schema document cites the canonical-form serialization rule (sorted keys, no insignificant whitespace, UTF-8) so the manifest generator and the doctor's plan-format library hash identically.
- **CSC001-002**: All Gate 001 → 002 predicates pass for a canonical published by the server-side workflow — i.e., (a) the manifest URL serves a manifest for a pinned canonical block height whose canonical-form-hash matches the published trust-root constant; (b) the manifest fields parse cleanly per the frozen schema; (c) for at least three sampled chunks (one `main.sqlite3` page, one `blocks/` file, one `chainstate/` file), an HTTPS GET returns bytes whose SHA-256 (over the uncompressed payload) matches the manifest's recorded hash; (d) the encoding-negotiation contract verifies — `Accept-Encoding: zstd` returns zstd, `Accept-Encoding: gzip` returns gzip, `Accept-Encoding: identity` returns HTTP 406 with a body containing both encoding names.
- **CSC001-003**: At least one canonical is published whose block height is suitable for Chunk 004's drill. (The drill canonical is the seed for the v1 end-to-end recovery exercise.)

## What this chunk unblocks

- **Chunk 002 (Client Foundation + Diagnose)** may begin after manifest schema freeze (Gate 001-Schema → 002).
- **Chunk 003 (Client Apply)** may begin after the full chunk store is available (Gate 001 → 002).
- **Chunk 004 (End-to-End Drill + Network Resilience)** drill scenario requires this chunk's published canonical; the drill rig's doctor binary is built against this canonical's trust-root.

## Speckit Stop Resolutions inherited from the chunking doc

These resolutions are pinned by §Chunk 001 of the chunking doc and are not re-decided in this spec. They are surfaced here so the downstream pipeline (`/speckit.plan`, `/speckit.tasks`, `/speckit.implement`) does not stop on them:

- **Manifest generator language and runtime**: extend the existing `pocketnet_create_checkpoint` workflow's language and runtime. No new language is introduced.
- **Chunk-store hosting topology**: the same hosting channel as today's full-snapshot distribution.
- **Compression on the server side**: pre-compress chunks with both Zstandard and gzip; cache the compressed payloads server-side; serve per `Accept-Encoding`; absence of either supported encoding returns HTTP 406 with a body naming supported encodings (CR001-005).
- **Canonical-form serialization rule**: inherited from pre-spec Implementation Context (sorted JSON keys, no insignificant whitespace, UTF-8). Both the manifest-trust-root hash (this chunk) and the doctor-side plan self-hash (Chunk 002) inherit from this single rule. No chunk owns the rule independently.
- **Manifest schema publication mechanism**: the manifest schema is published as a JSON-Schema-format document (or equivalent) in the project's docs or at a stable URL before the chunk store is built. Schema-freeze is Gate 001-Schema → 002.
- **Drill canonical source (PSA-11-F06)**: a canonical published by this chunk is the drill canonical for Chunk 004; the drill rig's doctor binary is built against this canonical's trust-root.

## Plan-layer deferrals

The following decisions belong to `/speckit.plan` (HOW), not to this spec (WHAT). They are recorded here so they are not silently absorbed at spec time:

- **Plan-layer decision**: Manifest schema document concrete format and publication URL pattern (the spec pins "JSON-Schema-format document or equivalent at a stable URL"; the exact draft, file naming, and URL convention are plan-layer choices within that constraint).
- **Plan-layer decision**: Concrete chunk-URL scheme and path structure under the existing hosting channel (the spec pins "discrete HTTPS GETs"; the URL grammar and naming convention are plan-layer).
- **Plan-layer decision**: Concrete trust-root publication mechanism (file alongside the manifest, separate endpoint, embedded inside a release-notes document, etc. — the spec pins "published alongside the manifest"; the concrete artifact shape is plan-layer).
- **Plan-layer decision**: Server-side caching strategy and cache key shape for the dual-encoding (zstd + gzip) pre-compressed payloads (the spec pins "pre-compressed and cached server-side"; cache layer choice and key shape are plan-layer).
- **Plan-layer decision**: Concurrency / fan-out tuning for the chunk store at typical operator scale (the spec pins BC-003 "survives concurrent fetches at typical operator scale"; concrete capacity targets and fan-out architecture are plan-layer).

## Assumptions

- The existing `pocketnet_create_checkpoint` workflow exists and is extensible; this chunk extends it rather than replacing it. (The implementation lives in the sibling `pocketnet_create_checkpoint` repo via epic child delt.3.)
- The publisher's existing full-snapshot distribution channel is HTTPS-capable and is the channel through which the chunk store and manifests are also served.
- The pre-spec's Implementation Context is the single authoritative source for the canonical-form serialization rule; this chunk does not independently re-define it.
- `main.sqlite3` is the doctor's primary SQLite artifact whose 4 KB-page divergences drive the bandwidth win (per the pre-spec's empirical baseline at `experiments/01-page-alignment-baseline/`); other SQLite-shaped artifacts in `pocketdb/`, if any, are addressed equivalently by per-file entries enumerating page-level hashes at the 4 KB boundary.
- The doctor side (Chunks 002 and 003) builds against a pinned trust-root constant per the One-Time Setup Checklist; this chunk's job is to publish a value that matches what the doctor build pins.
- "Typical operator scale" for BC-003 is the population of pocketnet operators recovering nodes within any 30-day publishing window. A concrete capacity target is a plan-layer decision.
- Manifest schema-freeze is a one-shot event at Gate 001-Schema → 002. After freeze, schema evolution is a pre-spec FR-018 concern (the manifest carries a `format_version` field so future versions can extend without breaking v1 parsers); schema-evolution mechanics are out of scope for this chunk.
