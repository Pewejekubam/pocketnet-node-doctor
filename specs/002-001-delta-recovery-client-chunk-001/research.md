# Phase 0 Research: Server-Side Manifest Schema + Chunk Store Generation

**Branch**: `002-001-delta-recovery-client-chunk-001` | **Date**: 2026-04-30 | **Plan**: [plan.md](plan.md)

## Scope

Phase 0 records the findings that back the plan-stage decisions in [plan.md § Plan-Stage Decisions](plan.md). No `NEEDS CLARIFICATION` markers were carried into this phase: the spec's Clarifications session (2026-04-30, Q1–Q5) and the chunking doc's Speckit Stop Resolutions closed every spec-level unknown; the remaining plan-stage decisions are discriminated by precedent, pre-spec constraint, and conservative-default reasoning, all consolidated below.

## Decision: JSON Schema draft for the manifest schema document

- **Decision**: JSON Schema **Draft 2020-12**.
- **Rationale**: CSC001-001(a) names "JSON Schema (Draft 2020-12, or current draft at time of authoring)." 2020-12 is the current draft as of 2026-04-30 (no successor draft has been ratified by the JSON Schema TSC; the latest released version at this writing is 2020-12). Pinning the older-but-stable 2020-12 over a hypothetical newer draft maximizes validator support across languages used by the doctor (Chunk 002) and the publisher (sibling `delt.3`).
- **Alternatives considered**:
  - **Draft 07** — widely supported but lacks `unevaluatedProperties`, which is useful for guarding against accidental field additions in the manifest. Rejected.
  - **Self-rolled schema dialect** — rejected as a non-starter against CSC001-001's explicit JSON-Schema requirement.

## Decision: Discriminator mechanism for per-file entry shapes

- **Decision**: explicit `entry_kind` discriminator with values `"sqlite_pages"` and `"whole_file"`; schema uses a top-level `oneOf` keyed on the discriminator.
- **Rationale**:
  - **Testability**: a JSON-Schema validator's error message points at the unrecognized discriminator value rather than at a confusing missing/extra field. This matters for the contract tests in CSC001-002(b).
  - **Forward compatibility**: adding a new entry kind in a future `format_version` is a purely additive schema change — append a new `oneOf` branch and a new enum value. Implied-by-presence schemes require renegotiating the absence/presence invariants for every existing entry to avoid ambiguity with new shapes.
  - **Determinism under canonical-form hash**: with explicit discriminator, the canonical-form serialized output of two equivalent entries is byte-identical regardless of which optional fields the producer chose to emit; with implied-by-presence, an "optional but absent" field has different canonical-form byte output than "optional but emitted as null," opening a subtle path to trust-root drift between independently built producers.
- **Alternatives considered**:
  - **Implied-by-field-presence** (page-array present ⇒ sqlite_pages; whole-file hash present ⇒ whole_file): rejected for the canonical-form determinism risk above.
  - **Two parallel entry arrays** (`sqlite_files: [...]`, `other_files: [...]`): rejected as more verbose at no testability gain; the discriminator approach keeps a single ordered iteration surface for the doctor.

## Decision: Empty form for `trust_anchors`

- **Decision**: empty array `[]`.
- **Rationale**:
  - Pre-spec FR-018 frames v1's trust-root as the seed for a future list of anchors (third-party publishers, healthy-peer cross-check, chain anchors). A list shape is the natural superset.
  - Pre-spec Implementation Context's "Out of scope for v1" enumerates these future anchor types as items, not keyed configurations — list-shape matches the planned extension grammar.
  - `null` would re-introduce the "absent vs. empty" ambiguity that D2 above explicitly avoids; `{}` would imply a keyed map, which contradicts the plural-list framing.
- **Alternatives considered**: `null`, `{}`, omitting the field entirely. All rejected per above.

## Decision: Page-array element shape

- **Decision**: `[{"offset": <int-bytes>, "hash": "<64-hex>"}, ...]` sorted by `offset` ascending; total coverage of every 4 KB page of the canonical's `main.sqlite3`.
- **Rationale**:
  - **Self-describing under canonical-form rule**: each element is fully addressed by its own object. Sorted-keys serialization yields a deterministic byte stream regardless of producer iteration order.
  - **Total coverage**: pre-spec FR-001/FR-002 require diagnose to identify "differing 4 KB pages of `main.sqlite3`" by comparing against the canonical's published page hashes; partial coverage would leave divergence-detection blind spots. Spec Q2/A2 already pinned this.
  - **Sorted by offset**: ascending offset is the natural order for a doctor scanning a local file linearly. Removes ordering as a source of drift across producers.
- **Alternatives considered**:
  - **Bare hex array indexed by page number**: rejected — couples ordering with addressability, complicates canonical-form serialization (no per-page object to sort keys within), and forces the doctor to compute `page_number = offset / 4096` rather than reading offset directly.
  - **Map keyed by stringified offset**: rejected — JSON keys must be strings, so offsets-as-keys lose integer typing; map iteration order is implementation-defined, requiring extra canonical-form rules per consumer.

## Decision: Chunk-URL grammar

- **Decision**: per-canonical prefix `<base>/canonicals/<block_height>/...` with `manifest.json`, `trust-root.sha256`, and `files/<file_path>[/pages/<offset>]` underneath. See [contracts/chunk-url-grammar.md](contracts/chunk-url-grammar.md) for the full grammar.
- **Rationale**:
  - The doctor must construct chunk URLs from `(canonical_identity.block_height, file_path, offset)` without further server interaction (chunking doc behavioral criteria; CR001-004 "discrete HTTPS GETs"). A flat algorithmic mapping from manifest fields to URL is the simplest construction the doctor side can implement.
  - **Per-canonical prefix** keeps simultaneously-published canonicals naturally segregated and lets a future retention sweep (`delt.3`-owned) prune by directory.
  - **`<file_path>` is the manifest's `path` value verbatim**, including any subdirectories (`blocks/000.dat`, `chainstate/CURRENT`, `pocketdb/main.sqlite3`). No path mangling: the manifest path IS the URL fragment, modulo URL-encoding of any reserved characters.
- **Alternatives considered**:
  - **Hashed URLs** (chunk URL is `sha256(path||offset).hex`): rejected — hides addressability, complicates debugging, no caching benefit on a static-file channel.
  - **Tarball-per-canonical with byte-range fetches**: rejected — spec pins discrete HTTPS GETs; range-request reliance contradicts CR001-004 and the static-file caching posture.

## Decision: Trust-root sidecar shape

- **Decision**: plain-text file `trust-root.sha256` next to `manifest.json`; exactly 64 lowercase hex chars + single `\n`.
- **Rationale**:
  - **Out-of-band verifiability**: the chunking doc's Independent Test for US-1 is `curl + sha256sum`. A plain-text sidecar is one `diff` away from a `sha256sum` result.
  - **Avoids meta-hash recursion**: a JSON wrapper would itself need a canonical-form rule for hash determinism, adding surface area for no benefit.
  - **Newline at end** matches POSIX text-file convention; `sha256sum -c` workflows expect it.
- **Alternatives considered**:
  - **JSON wrapper** (`{"trust_root": "<hex>"}`): rejected for meta-hash question and added parsing.
  - **Embedded inside the manifest itself**: rejected — circular (hashing a manifest that contains its own hash requires excluding the field from the hash input, which complicates the canonical-form rule). Pre-spec keeps trust-root external to the manifest.
  - **HTTP header on the manifest response** (`X-Trust-Root: <hex>`): rejected — not preservable across mirrors that re-serve static files; sidecar is mirror-agnostic.

## Decision: Server-side caching strategy

- **Decision**: pre-compressed payloads at rest (`<chunk-path>.zst` and `<chunk-path>.gz`); cache key `(URL) × (Content-Encoding)`; `Vary: Accept-Encoding` on responses.
- **Rationale**:
  - **Static-file channel posture**: the same hosting channel that serves today's full-snapshot tarball is the channel for the chunk store (Speckit Stop). Static-file servers (and CDNs in front of them) honor `Vary: Accept-Encoding` natively.
  - **No bespoke compressor at request time**: pre-compression at publish time means request-path CPU cost is zero — relevant at BC-003's "typical operator scale" of fan-out reads.
  - **Encoding-agnostic chunk URL**: the doctor constructs one URL and lets HTTP content negotiation pick the variant. Surfacing `.zst` / `.gz` extensions in URLs would require the doctor to know about server-side storage shape, which leaks implementation through the contract.
- **Alternatives considered**:
  - **Compress-on-the-fly per request**: rejected for CPU cost at fan-out and weaker cacheability (cache key would need to incorporate compression-level negotiation).
  - **Single-encoding store** (zstd only, gzip not pre-built): rejected — doctor compatibility argument: gzip is the universal fallback if a doctor build's zstd dependency is ever in question.

## Decision: BC-003 capacity envelope

- **Decision**: chunk store inherits the existing full-snapshot channel's throughput envelope; concrete numbers are owned by `delt.3` (sibling repo).
- **Rationale**:
  - The chunking doc's Speckit Stop pinned hosting topology to "same hosting channel." A second envelope target would contradict that.
  - The doctor's default 4-way concurrency (pre-spec Implementation Context) × an estimated concurrent-operator population gives an order-of-magnitude target, but a precise SLO needs production telemetry that does not yet exist. Premature optimization here would invent constraints the channel does not require.
- **Alternatives considered**:
  - **Pin a concrete RPS target** (e.g., 1000 RPS sustained): rejected as invention without measurement. `delt.3` is in a position to measure once chunks start flowing.
  - **Introduce a bespoke origin** (CDN, dedicated origin server): rejected as topology change — would re-open a Speckit Stop the chunking doc closed.

## Decision: HTTP 406 body shape

- **Decision**: plain-text body, exactly `Supported encodings: zstd, gzip\n`; `Content-Type: text/plain; charset=utf-8`.
- **Rationale**:
  - **Spec-required tokens**: US-4 acceptance scenario 3 requires "a body containing both the strings `zstd` and `gzip`." The chosen body satisfies this with a single grep on each token.
  - **No parsing surface**: the doctor's only programmatic interaction with this body is the contract test (CSC001-002(d)) — token presence, not field extraction. JSON would be over-engineered.
- **Alternatives considered**:
  - **JSON body** (`{"supported_encodings": ["zstd","gzip"]}`): meets the spec but adds parser surface; rejected.
  - **`Accept-Encoding` header echo with no body**: rejected — spec literally requires "a body."

## Decision: `format_version` initial value

- **Decision**: `format_version: 1` (integer).
- **Rationale**:
  - **Cross-axis alignment**: pre-spec Implementation Context pins the doctor-side plan's `format_version` to `1`. Manifest's `format_version` is a separate counter, but starting both at 1 makes triage logs legible (`manifest fv=1, plan fv=1`).
  - **Schema-evolution mechanics out of scope**: spec Assumptions explicitly defer schema evolution to FR-018; v1 only needs the field present so future versions can branch.
- **Alternatives considered**: `0` (rejected — non-conventional starting value), semver string (rejected — pre-spec uses integers for plan `format_version`; consistency wins).

## Decision: Schema-document citation of canonical-form rule

- **Decision**: top-level `$comment` field in `manifest.schema.json` carrying a one-paragraph quote of pre-spec Implementation Context's canonical-form rule and naming the trust-root construction. The schema document also names which fields are excluded from the canonical-form-hash input (none in v1 — the manifest itself contains no `self_hash` field; the trust-root is external).
- **Rationale**:
  - **CSC001-001(b) explicit requirement**: the schema document must cite the canonical-form serialization rule so the manifest generator and the doctor's plan-format library hash identically.
  - **Self-contained schema**: a downstream reader who has only the schema URL (not the pre-spec) can still see the rule and the trust-root construction in a single document.
- **Alternatives considered**:
  - **External README-only citation**: rejected — splits the rule across two documents, raising the chance one drifts from the other.
  - **Embed the rule as schema validation**: rejected — JSON Schema cannot validate canonical-form serialization (it's a producer-side discipline, not a structural property of the document).

## Out of Phase 0 scope

- Concrete RPS / byte/sec capacity numbers for BC-003 — operational, owned by `delt.3`.
- Retention SLO for prior canonicals' manifest URLs — operational, owned by `delt.3` (spec Q4/A4 carries the conservative interpretation).
- Mirror-coordination protocol — out of v1 scope per pre-spec.
- Manifest-schema evolution mechanics — pre-spec FR-018; out of this chunk's scope per spec Assumptions.
