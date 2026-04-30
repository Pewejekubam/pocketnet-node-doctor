# Implementation Plan: Server-Side Manifest Schema + Chunk Store Generation (Chunk 001)

**Branch**: `002-001-delta-recovery-client-chunk-001` | **Date**: 2026-04-30 | **Spec**: [spec.md](spec.md)

## Summary

Chunk 001 publishes a contract — not in-repo code. The deliverables are (a) a frozen manifest **schema document**, (b) a per-canonical **manifest** payload shape, (c) a **chunk-URL grammar** for HTTPS-addressable byte sources, (d) the **trust-root sidecar** shape, and (e) the **HTTP encoding-negotiation contract** (zstd/gzip pre-compressed, HTTP 406 fallback). The implementation that produces these artifacts lives in the sibling `pocketnet_create_checkpoint` repository (epic child `delt.3`); this plan pins what those artifacts must look like so doctor-side chunks (002 diagnose, 003 apply, 004 drill) can be built against a stable contract.

## Technical Context

**Artifact type**: contract-spec chunk (no source code is generated in this repo for Chunk 001).
**Schema language**: JSON Schema Draft 2020-12 (per CSC001-001).
**Hash algorithm**: SHA-256 (lowercase 64-char hex), single algorithm across manifest entries, trust-root, and downstream plan self-hash (pre-spec Implementation Context).
**Canonical-form serialization rule**: sorted JSON keys, no insignificant whitespace, UTF-8 — owned by pre-spec Implementation Context, inherited unchanged.
**Transport**: HTTPS, discrete GETs per chunk URL.
**Compression**: zstd + gzip pre-compressed payloads, served per `Accept-Encoding`; absence of either supported encoding returns HTTP 406 with a body naming the supported encodings.
**Server-side runtime**: extends the existing `pocketnet_create_checkpoint` workflow (Speckit Stop resolved in chunking doc); language and runtime inherit from that sibling repo and are not chosen here.
**Hosting topology**: same channel as today's full-snapshot distribution (Speckit Stop resolved).
**Performance target**: BC-003 — chunk store survives concurrent fetches at typical operator scale; concrete capacity is owned operationally by `delt.3` (sibling repo) and bounded by the same channel that already serves full-snapshot traffic.
**Project type**: contract artifacts only (schema + URL grammar + sidecar formats + HTTP contract).

## Constitution Check

The repo's `.specify/memory/constitution.md` is the unfilled SpecKit template (placeholders only — no ratified principles). There are no concrete gates to evaluate. This is consistent with the pre-implementation, pre-spec posture documented in [CLAUDE.md](../../CLAUDE.md): the project's behavioral constraints live in the pre-spec and the chunking doc, both of which are honored throughout this plan.

**Result**: PASS (vacuous — no constitution principles to violate).

## Project Structure

### Documentation (this feature)

```text
specs/002-001-delta-recovery-client-chunk-001/
├── spec.md                         # /speckit.specify + /speckit.clarify output (existing)
├── plan.md                         # this file
├── research.md                     # Phase 0 output
├── data-model.md                   # Phase 1 output (manifest entity model)
├── quickstart.md                   # Phase 1 output (out-of-band verification recipe)
├── contracts/
│   ├── manifest.schema.json        # JSON Schema Draft 2020-12 — frozen manifest schema
│   ├── chunk-url-grammar.md        # HTTPS chunk-URL grammar + path conventions
│   ├── trust-root-format.md        # trust-root sidecar shape
│   └── http-encoding.md            # Accept-Encoding / 406 contract
├── checklists/                     # /speckit.checklist output (pre-existing)
├── fixtures/                       # /speckit.tasks output — synthetic reference canonical
│   ├── canonical/source/           # raw byte sources for synthetic canonical
│   ├── canonical/served/           # served manifest, trust-root sidecar, pre-compressed chunks
│   └── negative/                   # negative-test variants (tampered, stale, schema-violating)
├── harness/                        # /speckit.tasks output — verification scripts + stub server
└── evidence/                       # /speckit.tasks output — captured run logs and gate bundles
```

### Source Code (repository root)

Not applicable for Chunk 001. The implementation that produces conforming manifests, chunks, and trust-root sidecars lives in the sibling `pocketnet_create_checkpoint` repository (epic child `delt.3`). This plan publishes contract artifacts only.

**Structure Decision**: contract-spec layout under `specs/002-001-delta-recovery-client-chunk-001/`; no `src/` or `tests/` directories are created in this repo for this chunk.

## Plan-Stage Decisions

Each decision below is resolved per the order: pre-declared default (none in chunking doc § Plan-Stage Decisions Across All Chunks for this chunk) → precedent (no merged-chunk precedent — Chunk 001 is first) → pre-spec constraint → narrower / more-testable / more-conservative.

### D1. Manifest schema concrete format and publication URL

- **Option chosen**: JSON Schema Draft 2020-12, published as `manifest.schema.v1.json` at a stable URL on the same hosting channel as canonicals; the schema document carries a `$comment` field citing pre-spec Implementation Context's canonical-form serialization rule.
- **Rationale**: CSC001-001(a) pins JSON Schema Draft 2020-12; CSC001-001(b) requires the schema to cite the canonical-form rule. Versioned filename (`...v1.json`) lets future `format_version` upgrades coexist without URL churn. "Same hosting channel" is the chunking doc's Speckit Stop resolution.

### D2. Per-file entry shape — discriminator mechanism (resolves spec Q1)

- **Option chosen**: explicit `entry_kind` discriminator with values `"sqlite_pages"` (page-level shape) and `"whole_file"` (whole-file shape). JSON Schema uses `oneOf` keyed on `entry_kind`.
- **Rationale**: more testable and more conservative than implied-by-field-presence. An explicit discriminator survives schema evolution (new entry kinds in future `format_version`) without ambiguity, and JSON-Schema validators surface clear errors. Implied-by-presence couples schema validity to the absence of fields — a brittle invariant that complicates the trust-root canonical-form hash if optional fields drift.

### D3. `trust_anchors` empty form (resolves spec Q5)

- **Option chosen**: empty array `[]`.
- **Rationale**: pre-spec Trust-root design (Implementation Context line on trust root) and FR-018 framing both treat trust anchors as a list of independent publishers/keys. List shape is the natural extension; `null` is rejected because it overlaps semantically with "absent"; `{}` is rejected because anchors are not a keyed map. Single committed empty form satisfies BC-001/BC-002 determinism (any single committed form would, but `[]` aligns with intended v1.x → v2 evolution shape).

### D4. Per-file entry — page-array element shape

- **Option chosen**: each `sqlite_pages` entry's `pages` is an array of objects `{"offset": <integer-bytes>, "hash": "<64-hex>"}`. Pages are sorted by `offset` ascending. Coverage is total: every 4 KB page of the canonical's `main.sqlite3` file is enumerated (CR001-002, spec Q2/A2).
- **Rationale**: explicit `offset` makes each page self-describing under the canonical-form sorted-keys rule and lets validators reject malformed entries individually. A bare array of hex strings indexed by position would conflate ordering with addressability and impose a hidden invariant on canonical-form serializers. Pre-spec FR-001/FR-002 require addressing by `(path, offset)` — explicit offset matches.

### D5. Per-file entry — `change_counter` placement (CR001-007 / spec Q3)

- **Option chosen**: `change_counter: <integer>` field on the `sqlite_pages` entry whose `path` is `"pocketdb/main.sqlite3"` only. The schema permits `change_counter` only on the entry for `main.sqlite3`; other `sqlite_pages` entries (e.g., other SQLite-shaped artifacts under `pocketdb/`, if any) MUST NOT carry it.
- **Rationale**: spec Q3/A3 pins this — pre-spec FR-011 references `main.sqlite3` exclusively. Restricting at schema level prevents accidental misuse and keeps the doctor's pre-flight (FR-011) unambiguous.

### D6. Chunk-URL scheme and path structure

- **Option chosen** (under-the-channel-base; concrete grammar in [contracts/chunk-url-grammar.md](contracts/chunk-url-grammar.md)):
  - Manifest:    `<base>/canonicals/<block_height>/manifest.json`
  - Trust root:  `<base>/canonicals/<block_height>/trust-root.sha256`
  - SQLite page: `<base>/canonicals/<block_height>/files/<file_path>/pages/<offset>`
  - Whole file:  `<base>/canonicals/<block_height>/files/<file_path>`
  - `<base>` is whatever the existing full-snapshot distribution channel exposes; the per-canonical prefix `canonicals/<block_height>/` is the only structure this chunk pins.
- **Rationale**: spec pins "discrete HTTPS GETs"; pre-spec Implementation Context observes "per-page chunks are addressable as discrete URLs to keep server-side caching simple." A per-canonical prefix is the narrowest structural commitment that lets the doctor build a chunk URL from `(canonical_identity.block_height, file_path, offset)` without further server interaction. `<offset>` is the byte offset as a decimal integer (matches manifest entry).

### D7. Trust-root publication mechanism

- **Option chosen**: plain-text sidecar file `trust-root.sha256` next to `manifest.json`, containing exactly one line: 64 lowercase hex characters followed by a single `\n`. No JSON wrapper.
- **Rationale**: spec pins "published alongside the manifest"; concrete artifact shape is plan-layer. Plain-text sidecar is the most testable form (a single `curl ... | tr -d '\n' | wc -c` predicate verifies it; `sha256sum -c` is one step). A JSON wrapper would couple the trust-root format to a hash-of-the-wrapper question and add no value. CSC001-002(a) is checked by `sha256sum` on the manifest body vs. this sidecar's content.

### D8. Server-side caching strategy and cache key shape

- **Option chosen**: pre-compressed payloads stored at rest in two on-origin variants per chunk URL — `<chunk-path>.zst` and `<chunk-path>.gz`. The server selects the variant per request `Accept-Encoding`. Cache key shape: `(full URL) × (selected Content-Encoding)`; responses carry `Vary: Accept-Encoding`. The chunk URL itself is encoding-agnostic (no `.zst` / `.gz` extension visible to the doctor).
- **Rationale**: spec pins "pre-compressed and cached server-side" — concrete cache layer and key shape are plan-layer. Two-on-origin-variants matches the existing static-file distribution channel posture (the same channel today serves a single full-snapshot blob; here it serves N small static files, twice). `Vary: Accept-Encoding` is the standard HTTP cache-key extension and is what intermediate caches (CDN/proxy) honor without bespoke configuration.

### D9. Concurrency / fan-out target for BC-003

- **Option chosen**: the chunk store inherits the throughput envelope of the existing full-snapshot distribution channel (same hosting channel — chunking doc Speckit Stop). Concrete capacity numbers (concurrent operators, requests/sec, byte/sec) are owned operationally by the sibling `pocketnet_create_checkpoint` repo (`delt.3`) and are sized by today's operator population × the doctor's default 4-way concurrency (pre-spec Implementation Context). No bespoke origin is introduced.
- **Rationale**: spec pins "typical operator scale"; concrete capacity is plan-layer but the chunking doc already constrained the topology to "same hosting channel." No precedent exists for different numbers, and the more-conservative choice is to not exceed today's posture. Tightening capacity (autoscaling, edge caching) is `delt.3`'s call once real fetch traffic is observable.

### D10. HTTP 406 response body shape

- **Option chosen**: plain-text body, exactly: `Supported encodings: zstd, gzip\n`. `Content-Type: text/plain; charset=utf-8`.
- **Rationale**: CR001-005 / US-4 acceptance scenario 3 require "a body containing both the strings `zstd` and `gzip`." Plain text with both names matches the requirement; a JSON body would meet the requirement but adds parsing surface for no doctor-side benefit. The doctor never inspects this body programmatically beyond the contract test in CSC001-002(d) (`grep zstd && grep gzip`).

### D11. `format_version` initial value

- **Option chosen**: `format_version: 1` (integer; matches pre-spec Implementation Context plan-artifact `format_version: 1`).
- **Rationale**: pre-spec Implementation Context pins the doctor-side plan's `format_version` to integer 1. Manifest's `format_version` is a separate counter but follows the same shape and starting value; alignment makes both `format_version` axes legible at a glance during incident triage.

### D12. Schema document — citation of canonical-form rule

- **Option chosen**: schema document carries a top-level `$comment` field citing pre-spec Implementation Context (specifically the line "Canonical-form serialization (for hash inputs): sorted JSON keys, no insignificant whitespace, UTF-8") and naming the trust-root construction (SHA-256 of canonical-form payload of the manifest JSON). The manifest instance carries no fields excluded from the canonical-form-hash input — the schema's `unevaluatedProperties: false` constraint at every nesting level forbids any field other than the four required top-level fields (`format_version`, `canonical_identity`, `entries`, `trust_anchors`), so a `$schema` reference field cannot legally appear in a manifest instance and the hash input is therefore exactly the byte-for-byte canonical-form serialization of the manifest as validated.
- **Rationale**: CSC001-001(b) requires the schema to cite the canonical-form rule. `$comment` is the JSON-Schema-native field for non-validation prose. The `unevaluatedProperties: false` posture (chosen for forward-compatibility safety in D2 / D3) doubles as the mechanism that keeps the trust-root hash input deterministic — no schema-tooling field can sneak into the hashed bytes because no such field can be present in a valid instance.

## Non-goals

- **No source code is produced in this repo for this chunk.** The conforming manifest generator, chunk store builder, and trust-root publisher live in the sibling `pocketnet_create_checkpoint` repo (epic child `delt.3`). This plan defines what those artifacts must look like, not how they are produced.
- **No retention SLO is pinned here.** Spec Q4/A4 carries forward the conservative interpretation (a published canonical's manifest URL remains accessible at least until the next canonical at higher block height is published). A concrete retention window (last-N canonicals or fixed-day) is `delt.3`'s operational decision.
- **No third-party trust anchors.** v1 ships with `trust_anchors: []`. Chain-anchored verification, healthy-peer cross-check, and independent canonical publishers are pre-spec FR-018 / out-of-v1-scope.
- **No range-request contract.** Pre-spec Implementation Context permits range requests but does not require them. The discrete-URL-per-page contract (CR001-004) is the v1 commitment; range requests are a server-side optimization the doctor does not depend on.
- **No public-key signature on the manifest.** Trust-root is a pinned-hash compare (pre-spec Implementation Context); no PKI is introduced here.
- **No bespoke origin or CDN topology.** Same hosting channel as today's full-snapshot distribution (Speckit Stop resolution); no auth, no rate-limiting, no per-operator metering.
- **No internal failure-mode contract.** Publisher pipeline failures, mirror outages, cache invalidation paths are owned by `delt.3`. The contract here is what a successful publication looks like.

## Artifacts Created

- `specs/002-001-delta-recovery-client-chunk-001/plan.md` (this file)
- `specs/002-001-delta-recovery-client-chunk-001/research.md`
- `specs/002-001-delta-recovery-client-chunk-001/data-model.md`
- `specs/002-001-delta-recovery-client-chunk-001/quickstart.md`
- `specs/002-001-delta-recovery-client-chunk-001/contracts/manifest.schema.json`
- `specs/002-001-delta-recovery-client-chunk-001/contracts/chunk-url-grammar.md`
- `specs/002-001-delta-recovery-client-chunk-001/contracts/trust-root-format.md`
- `specs/002-001-delta-recovery-client-chunk-001/contracts/http-encoding.md`

## Artifacts Updated

- `CLAUDE.md` (root) — touched by `.specify/scripts/bash/update-agent-context.sh claude` if new technologies are introduced; this chunk introduces no new language/runtime, so the script may be a no-op. Recorded here for completeness.

## Phase Outputs Reference

- **Phase 0 (research.md)**: resolves any NEEDS CLARIFICATION items (none surfaced — all unknowns were closed by spec Clarifications session 2026-04-30, the chunking doc's Speckit Stop Resolutions, and the plan-stage decisions D1–D12 above) and consolidates findings on JSON Schema Draft 2020-12 conventions, canonical-form serialization in practice, and the encoding-negotiation contract.
- **Phase 1 (data-model.md, contracts/, quickstart.md)**: pins the manifest entity model, publishes the JSON Schema and human-readable companion contracts, and provides an out-of-band verification recipe (curl + sha256sum + zstd) usable by the chunking-doc Independent Test for US-1.

## Re-evaluation After Phase 1

Constitution: still PASS (still vacuous — no principles ratified).
Spec Clarifications: Q1 resolved by D2; Q5 resolved by D3. Q2, Q3, Q4 were closed in the spec itself.
Plan-layer deferrals from spec: all five resolved (D1, D6, D7, D8, D9).

## Known Coverage Gaps

Two acknowledged-non-blocking partial coverages, recorded so they are visible during TDD and do not silently propagate:

- **BC-003 (chunk store survives concurrent fetches at typical operator scale)** — covered structurally by tasks.md T049 (`CONTRACT-HANDOFF.md`) as an inheritance-from-existing-channel invariant rather than by harness load testing in this chunk. Justification: the chunking doc Speckit Stop pins hosting topology to "same channel as today's full-snapshot distribution," and per plan §D9 concrete capacity numbers are owned operationally by the sibling `pocketnet_create_checkpoint` repo (`delt.3`). No harness in this repo can exercise real production capacity. The adjacent contract guarantee (chunk URLs are discrete static GETs over an existing high-capacity channel) is the load-bearing invariant; numerical capacity verification is a `delt.3` deployment-time concern.
- **CSC001-003 / US-6 (drill canonical exists)** — verified at the harness level by tasks.md T046–T048 against the synthetic fixture as a stand-in for the real drill canonical; the live-drill-canonical predicate runs at `delt.3` deployment time, not in this chunk's evidence bundle. Justification: a real drill canonical can only be published by `delt.3`, which is the sibling repo this contract serves. The harness predicate (`harness/verify-drill-canonical.sh`) is the testable contract this chunk owns; T047 (`fixtures/README.md`) documents the pinning procedure for `delt.3` to follow at deployment time.
