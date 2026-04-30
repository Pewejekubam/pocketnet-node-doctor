---
version: 0.1.0
status: draft
created: 2026-04-30
last_modified: 2026-04-30
authors: [pewejekubam, claude]
related: ../tasks.md
changelog:
  - version: 0.1.0
    date: 2026-04-30
    summary: FR/SC/BC traceability matrix mapping every chunk requirement to tasks and evidence (T053)
    changes:
      - "Map every CR001-001..008 to the implementing task and evidence file"
      - "Map every CSC001-001..003 to the verifying task and evidence file"
      - "Map every BC-001..003 to the verifying task / inheritance invariant"
      - "Cross-reference every AS-N from spec.md's six user stories"
---

# Chunk 001 Evidence Matrix

This matrix is the load-bearing traceability artifact for Chunk 001. Every
contract requirement (CR001-*), testable success criterion (CSC001-*), and
behavioral criterion (BC-*) maps to:

- the verifying task in `../tasks.md`,
- the harness predicate(s) that exercise it,
- the evidence log capturing the green run.

Every acceptance scenario (US-N AS-M) from `../spec.md` is also cross-referenced.

Outbound gate bundles aggregate from this matrix:

- Gate 001-Schema → 002 evidence: `gate-001-schema-to-002.md`
- Gate 001 → 002 evidence:        `gate-001-to-002.md`

## Functional contract requirements (CR001-*)

| Requirement | Task(s) | Harness predicate | Evidence log |
|---|---|---|---|
| CR001-001 (manifest at stable URL with `format_version`, `canonical_identity`, per-file entries, reserved `trust_anchors`) | T007 + T015 + T022 + T050 | verify-schema.sh; chunk-url-grammar.md "Manifest URL" section | schema-required-fields.log; us1-schema-pass.log; quickstart-end-to-end.log |
| CR001-002 (`main.sqlite3` page-level hashes at 4 KB boundary, addressable by `(path, offset)`) | T012 + T015 + T018 + T022 + T024 | check-jsonschema validates `pages[*].offset multipleOf 4096`; verify-sampled-chunks.sh fetches by `(path, offset)` | us1-schema-pass.log; us1-sampled-chunks-pass.log |
| CR001-003 (non-SQLite artifacts carry whole-file SHA-256) | T013 + T014 + T018 + T024 | verify-sampled-chunks.sh exercises both `blocks/` and `chainstate/` entries | us1-sampled-chunks-pass.log |
| CR001-004 (discrete HTTPS GETs) | T009 + T011 + T024 + T038-T040 | chunk-url-grammar.md (path-grammar consistency); stub-server.py serves discrete URLs | path-grammar-consistency.log; us1-sampled-chunks-pass.log; us4-zstd-pass.log; us4-gzip-pass.log; us4-406-pass.log |
| CR001-005 (`Accept-Encoding: zstd \| gzip`, pre-compressed + cached, HTTP 406 + body on mismatch) | T011 + T020 + T021 + T035-T040 | stub-server.py + verify-accept-encoding-{zstd,gzip,406}.sh | us4-zstd-pass.log; us4-gzip-pass.log; us4-406-pass.log |
| CR001-006 (SHA-256 of canonical-form manifest published alongside as trust-root constant) | T010 + T016 + T019 + T023 | trust-root-format.md cross-check; verify-trust-root.sh | trust-root-shape-consistency.log; us1-trust-root-pass.log |
| CR001-007 (manifest declares `change_counter` for `main.sqlite3`) | T008 + T030-T034 | check-jsonschema if/then/else conditional; verify-change-counter.sh; negative fixtures | schema-change-counter-conditional.log; us3-change-counter-pass.log; us3-negative-rejections.log |
| CR001-008 (manifests no older than 30 days) | T041 + T042 + T044 + T045 | verify-freshness.sh against good + stale | us5-freshness-pass.log; us5-stale-rejection.log |

## Testable success criteria (CSC001-*)

| Criterion | Task(s) | Harness predicate | Evidence log |
|---|---|---|---|
| CSC001-001(a) (schema published as JSON Schema Draft 2020-12, enumerates required fields including the four top-level fields, page-grid offsets, `trust_anchors`) | T005 + T007 + T022 | check-jsonschema --check-metaschema; jq on .required | schema-meta-validation.log; schema-required-fields.log; us1-schema-pass.log |
| CSC001-001(b) (canonical-form serialization rule cited in schema) | T006 | grep on `$comment` field substrings | schema-comment-citation.log |
| CSC001-002(a) (trust-root match) | T016 + T019 + T023 | verify-trust-root.sh | us1-trust-root-pass.log |
| CSC001-002(b) (schema-clean parse) | T015 + T022 | verify-schema.sh on conforming manifest | us1-schema-pass.log |
| CSC001-002(c) (three sampled chunks verifiable) | T017 + T024 | verify-sampled-chunks.sh | us1-sampled-chunks-pass.log |
| CSC001-002(d) (encoding-negotiation contract verified) | T035-T040 | verify-accept-encoding-{zstd,gzip,406}.sh | us4-zstd-pass.log; us4-gzip-pass.log; us4-406-pass.log |
| CSC001-003 (drill canonical at block height suitable for Chunk 004 published) | T046-T048 + T049 (delt.3 hand-off) | verify-drill-canonical.sh against stub stand-in; CONTRACT-HANDOFF.md for live re-run | us6-drill-canonical-stub-pass.log; ../CONTRACT-HANDOFF.md |

## Behavioral criteria (BC-*)

| Criterion | Task(s) | Harness predicate | Evidence log |
|---|---|---|---|
| BC-001 (doctor binary built against trust-root T authenticates only that manifest) | T026 + T027 + T029 | verify-tamper-rejection.sh | us2-tamper-rejection-pass.log |
| BC-002 (two doctor binaries, same trust-root, same manifest URL → same canonical) | T025 + T028 | verify-determinism.sh | us2-determinism-pass.log |
| BC-003 (chunk store survives concurrent fetches at typical operator scale) | T049 | non-test invariant: inherited from existing distribution channel; documented in CONTRACT-HANDOFF.md | ../CONTRACT-HANDOFF.md (BC-003 section) |

## Acceptance scenarios (spec.md → tasks → evidence)

### User Story 1 — Doctor consumes a published canonical (P1)

| AS | Predicate | Task | Evidence |
|---|---|---|---|
| US-1 AS-1 | SHA-256(canonical_form(manifest)) == published T | T016 / T023 | us1-trust-root-pass.log |
| US-1 AS-2 | manifest validates against schema and exposes the four top-level fields | T015 / T022 | us1-schema-pass.log |
| US-1 AS-3 | `main.sqlite3` per-file entry enumerates page-level hashes at 4 KB boundary, addressable by `(path, offset)` | T017 / T024 | us1-sampled-chunks-pass.log |
| US-1 AS-4 | non-SQLite per-file entries carry whole-file SHA-256 | T017 / T024 | us1-sampled-chunks-pass.log |
| US-1 AS-5 | HTTPS GET returns chunk bytes whose SHA-256 matches manifest entry | T017 / T024 | us1-sampled-chunks-pass.log |

### User Story 2 — Two builds, same trust-root, see same canonical (P1)

| AS | Predicate | Task | Evidence |
|---|---|---|---|
| US-2 AS-1 | re-serialization is deterministic (BC-002) | T025 / T028 | us2-determinism-pass.log |
| US-2 AS-2 | tampered manifest fails trust-root match (BC-001) | T026 / T029 | us2-tamper-rejection-pass.log |

### User Story 3 — Doctor pre-flight reads SQLite ahead-of-canonical reference (P1)

| AS | Predicate | Task | Evidence |
|---|---|---|---|
| US-3 AS-1 | manifest exposes a non-negative integer `change_counter` for `main.sqlite3` exclusively | T030 / T033 | us3-change-counter-pass.log |
| US-3 AS-2 | `change_counter` is comparable as an integer (negative test variants rejected by schema) | T031 / T032 / T034 | us3-negative-rejections.log |

### User Story 4 — Chunk delivery honors Accept-Encoding (P2)

| AS | Predicate | Task | Evidence |
|---|---|---|---|
| US-4 AS-1 | zstd request → zstd-encoded response, decompressed hash matches | T035 / T038 | us4-zstd-pass.log |
| US-4 AS-2 | gzip request → gzip-encoded response, decompressed hash matches | T036 / T039 | us4-gzip-pass.log |
| US-4 AS-3 | neither encoding offered → HTTP 406 with body naming both | T037 / T040 | us4-406-pass.log |

### User Story 5 — Server publishes manifests no older than 30 days (P2)

| AS | Predicate | Task | Evidence |
|---|---|---|---|
| US-5 AS-1 | latest canonical's `created_at` is within 30 days | T041 / T044 | us5-freshness-pass.log |
| (negative cover) | stale variant rejected | T042 / T045 | us5-stale-rejection.log |

### User Story 6 — Chunk 004 drill canonical exists (P2)

| AS | Predicate | Task | Evidence |
|---|---|---|---|
| US-6 AS-1 | drill canonical's published trust-root matches the drill-rig's compiled-in pin | T046 / T048 (in-repo stand-in); T049 (delt.3 live re-run hand-off) | us6-drill-canonical-stub-pass.log; ../CONTRACT-HANDOFF.md |

## Foundational evidence (Phase 2 — contract self-validation)

These do not map to a single CR/CSC/BC; they verify the frozen artifacts are
self-consistent before any user-story phase begins.

| Property | Task | Evidence |
|---|---|---|
| Schema validates against Draft 2020-12 meta-schema | T005 | schema-meta-validation.log |
| Schema `$comment` cites canonical-form rule + trust-root construction | T006 | schema-comment-citation.log |
| Schema declares the four top-level required fields | T007 | schema-required-fields.log |
| Schema enforces `change_counter` ↔ `main.sqlite3` conditional | T008 | schema-change-counter-conditional.log |
| Path grammar consistent across schema + chunk-url-grammar.md | T009 | path-grammar-consistency.log |
| Trust-root sidecar shape consistent across format doc + data-model | T010 | trust-root-shape-consistency.log |
| Stub server implements the contract end-to-end | T011 + T050 | quickstart-end-to-end.log |

## Verdict

Every CR001-*, every CSC001-*, every BC-*, and every AS-N from `spec.md`'s
six user stories has a named verifying task and a captured evidence log
(or, for BC-003, a documented inheritance invariant). The two outbound
gate bundles (`gate-001-schema-to-002.md`, `gate-001-to-002.md`)
aggregate from this matrix.

Outbound-gate evidence is complete; chunk is ready for `/speckit.superb.verify`.
