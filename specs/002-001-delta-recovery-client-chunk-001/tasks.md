# Tasks: Server-Side Manifest Schema + Chunk Store Generation (Chunk 001)

**Input**: Design documents from `specs/002-001-delta-recovery-client-chunk-001/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓, quickstart.md ✓
**Branch**: `002-001-delta-recovery-client-chunk-001`

**Tests**: TDD is mandatory for this chunk. Each user story orders work as: fixture → RED tests → implementation → GREEN verification.

**Organization**: Tasks are grouped by user story so each can be implemented and verified independently against the frozen contract.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Different files, no dependency on incomplete tasks; safe to parallelize.
- **[Story]**: User story this task serves (US1..US6). Setup, Foundational, and Polish tasks have no story label.
- File paths are absolute under the chunk feature directory `specs/002-001-delta-recovery-client-chunk-001/` unless noted otherwise.

## Path Conventions

This chunk is **contract-spec only** — no `src/` is created in this repo. The verification harness and fixture canonical live under the feature directory:

- Frozen contracts: `specs/002-001-delta-recovery-client-chunk-001/contracts/` (already authored at plan stage)
- Synthetic reference fixture: `specs/002-001-delta-recovery-client-chunk-001/fixtures/`
- Verification harness scripts: `specs/002-001-delta-recovery-client-chunk-001/harness/`
- Captured evidence (gate bundles, run logs): `specs/002-001-delta-recovery-client-chunk-001/evidence/`

The conforming manifest generator + chunk-store builder + trust-root publisher live in the sibling `pocketnet_create_checkpoint` repo (epic child `delt.3`); this chunk's harness exists so `delt.3` (and any independent verifier) can run the contract predicates against any conforming canonical.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Scaffold the directories and document tool prerequisites used by every later task.

- [X] T001 Create `specs/002-001-delta-recovery-client-chunk-001/fixtures/` with subdirectories `canonical/source/`, `canonical/served/`, `negative/`
- [X] T002 [P] Create `specs/002-001-delta-recovery-client-chunk-001/harness/` for verification scripts
- [X] T003 [P] Create `specs/002-001-delta-recovery-client-chunk-001/evidence/` for captured run logs and gate bundles
- [X] T004 [P] Author `specs/002-001-delta-recovery-client-chunk-001/harness/README.md` enumerating tool prerequisites (`curl`, `jq`, `sha256sum`, `zstd`, `gzip`, `check-jsonschema` or `ajv`, `python3` ≥ 3.10) and their pinned-or-tested versions

---

## Phase 2: Foundational (Contract Validation + Test Infrastructure)

**Purpose**: Validate the frozen contract artifacts against their own self-claims and stand up the shared HTTP stub server. NO user-story work begins until these complete.

**⚠️ CRITICAL**: All tasks here block every user story phase.

- [X] T005 [P] Validate `contracts/manifest.schema.json` against the JSON Schema Draft 2020-12 meta-schema; capture pass log to `evidence/schema-meta-validation.log`
- [X] T006 [P] Verify `contracts/manifest.schema.json` `$comment` field cites the canonical-form serialization rule (sorted keys, no insignificant whitespace, UTF-8) and names the trust-root construction; capture grep evidence to `evidence/schema-comment-citation.log` (CSC001-001(b))
- [X] T007 [P] Verify `contracts/manifest.schema.json` declares `format_version`, `canonical_identity`, `entries`, `trust_anchors` as required at the top level; capture jq-extracted evidence to `evidence/schema-required-fields.log` (CSC001-001(a))
- [X] T008 [P] Verify `contracts/manifest.schema.json` enforces the `change_counter` ↔ `pocketdb/main.sqlite3` conditional via the `allOf` if/then/else block; capture evidence to `evidence/schema-change-counter-conditional.log` (CR001-007)
- [X] T009 Cross-check `contracts/chunk-url-grammar.md` path-segment grammar against `contracts/manifest.schema.json` `path` regex — ensure both reject `..`, leading `/`, and non-`[A-Za-z0-9_.\-]` component characters; capture diff/consistency check to `evidence/path-grammar-consistency.log` (CR001-004)
- [X] T010 Cross-check `contracts/trust-root-format.md` byte-shape (65 bytes; 64 hex + LF) against `data-model.md` Trust-Root section; capture consistency check to `evidence/trust-root-shape-consistency.log` (CR001-006)
- [X] T011 Build `harness/stub-server.py` — a minimal Python HTTP server that serves any fixture under the chunk-url grammar, honors the `Accept-Encoding` contract (zstd / gzip pre-compressed at rest, HTTP 406 with `Supported encodings: zstd, gzip\n` body on miss), emits `Vary: Accept-Encoding`, and serves manifest + trust-root sidecar identity-encoded

**Checkpoint**: Frozen contracts self-consistent; stub server ready; user-story phases unblocked.

---

## Phase 3: User Story 1 — Doctor consumes a published canonical (Priority: P1) 🎯 MVP

**Goal**: An out-of-band consumer (curl + sha256sum + zstd, no doctor binary) fetches the manifest, computes the canonical-form-hash and obtains the published trust-root, parses per the frozen schema, and verifies sampled chunks (`main.sqlite3` page, `blocks/` file, `chainstate/` file).

**Independent Test**: Run `harness/run-quickstart.sh` against the synthetic fixture; every Step 1–3 predicate from `quickstart.md` reports a match.

### Fixtures (test data)

- [X] T012 [P] [US1] Generate synthetic `pocketdb/main.sqlite3` source bytes (≥ 4 pages, page-aligned to 4096; valid SQLite header carrying a chosen `change_counter` integer) at `fixtures/canonical/source/pocketdb/main.sqlite3`
- [X] T013 [P] [US1] Generate synthetic `blocks/000000.dat` source bytes (small, opaque) at `fixtures/canonical/source/blocks/000000.dat`
- [X] T014 [P] [US1] Generate synthetic `chainstate/CURRENT` source bytes (small, opaque) at `fixtures/canonical/source/chainstate/CURRENT`

### RED tests for User Story 1

- [X] T015 [P] [US1] Author `harness/verify-schema.sh` — runs `check-jsonschema --schemafile contracts/manifest.schema.json <manifest>`; exits non-zero on any validation failure (US-1 AS-2)
- [X] T016 [P] [US1] Author `harness/verify-trust-root.sh` — re-serializes `<manifest>` via `jq -cS . | tr -d '\n'`, hashes with `sha256sum`, compares to first 64 chars of `<sidecar>`; exits non-zero on mismatch (US-1 AS-1, CR001-006)
- [X] T017 [P] [US1] Author `harness/verify-sampled-chunks.sh` — selects (a) first `sqlite_pages` page on `pocketdb/main.sqlite3`, (b) first `whole_file` entry under `blocks/`, (c) first `whole_file` entry under `chainstate/`; for each, GETs the chunk URL with `Accept-Encoding: zstd`, decompresses, hashes, compares to manifest's recorded hash (US-1 AS-3, AS-4, AS-5)

### Implementation for User Story 1

- [X] T018 [US1] Generate `fixtures/canonical/served/manifest.json` enumerating one `sqlite_pages` entry for `pocketdb/main.sqlite3` (every 4 KB page covered, sorted by offset, including `change_counter`) and `whole_file` entries for the `blocks/` and `chainstate/` source files; honors canonical-form serialization (sorted keys, no insignificant whitespace) (depends T012, T013, T014)
- [X] T019 [US1] Generate `fixtures/canonical/served/trust-root.sha256` — exactly 64 lowercase hex chars (SHA-256 of canonical-form-serialized manifest) followed by a single LF (depends T018)
- [X] T020 [P] [US1] Pre-compress every chunk source byte-stream into `<chunk-path>.zst` variants under `fixtures/canonical/served/files/...` (per-page splits for `main.sqlite3`, whole-file for others) (depends T012, T013, T014)
- [X] T021 [P] [US1] Pre-compress every chunk source byte-stream into `<chunk-path>.gz` variants under `fixtures/canonical/served/files/...` (depends T012, T013, T014)

### GREEN verification for User Story 1

- [X] T022 [US1] Run `harness/stub-server.py fixtures/canonical/served/` and execute `harness/verify-schema.sh fixtures/canonical/served/manifest.json`; capture pass log to `evidence/us1-schema-pass.log`
- [X] T023 [US1] Execute `harness/verify-trust-root.sh fixtures/canonical/served/manifest.json fixtures/canonical/served/trust-root.sha256`; capture pass log to `evidence/us1-trust-root-pass.log`
- [X] T024 [US1] Execute `harness/verify-sampled-chunks.sh <stub-base-url> fixtures/canonical/served/manifest.json`; capture pass log to `evidence/us1-sampled-chunks-pass.log`

**Checkpoint**: US1 fully verified end-to-end against the synthetic fixture; this is the MVP — chunking-doc Independent Test for US-1 passes.

---

## Phase 4: User Story 2 — Two builds, same trust-root, see same canonical (Priority: P1)

**Goal**: Determinism — re-serializing the same manifest from independent processes (or hosts) yields identical canonical-form bytes and identical trust-root; tampering any byte yields a mismatch.

**Independent Test**: `harness/verify-determinism.sh` re-serializes twice from disjoint workdirs and asserts equality; `harness/verify-tamper-rejection.sh` flips a byte and asserts mismatch.

### RED tests for User Story 2

- [X] T025 [P] [US2] Author `harness/verify-determinism.sh` — re-serializes `<manifest>` twice (independent jq invocations, fresh workdirs, optionally different working users) and asserts identical SHA-256 over canonical-form bytes (BC-002, US-2 AS-1)
- [X] T026 [P] [US2] Author `harness/verify-tamper-rejection.sh` — produces a tampered copy of `<manifest>` (single-byte mutation in a value field), re-hashes, and asserts the hash differs from `<sidecar>` (BC-001, US-2 AS-2)

### Implementation for User Story 2

- [X] T027 [US2] Generate `fixtures/negative/manifest-tampered.json` — copy of the US1 fixture manifest with a single value-field byte flipped, used by T026 (depends T018)

### GREEN verification for User Story 2

- [X] T028 [US2] Execute `harness/verify-determinism.sh fixtures/canonical/served/manifest.json`; capture pass log to `evidence/us2-determinism-pass.log`
- [X] T029 [US2] Execute `harness/verify-tamper-rejection.sh fixtures/canonical/served/manifest.json fixtures/canonical/served/trust-root.sha256 fixtures/negative/manifest-tampered.json`; capture pass log to `evidence/us2-tamper-rejection-pass.log`

**Checkpoint**: BC-001 and BC-002 verified against the fixture.

---

## Phase 5: User Story 3 — Doctor pre-flight reads SQLite ahead-of-canonical reference (Priority: P1)

**Goal**: The manifest exposes a single non-negative integer `change_counter` for `pocketdb/main.sqlite3` and only that path; the schema rejects deviations.

**Independent Test**: `harness/verify-change-counter.sh` reads the field from the fixture; schema validation rejects two negative-test variants.

### RED tests for User Story 3

- [ ] T030 [P] [US3] Author `harness/verify-change-counter.sh` — extracts `change_counter` from the `pocketdb/main.sqlite3` `sqlite_pages` entry, asserts integer ≥ 0, asserts no other `sqlite_pages` entry carries the field (CR001-007, US-3 AS-1)

### Negative-test fixtures for User Story 3

- [ ] T031 [P] [US3] Generate `fixtures/negative/cc-on-other-sqlite.json` — manifest variant with `change_counter` placed on a non-`main.sqlite3` `sqlite_pages` entry; schema MUST reject
- [ ] T032 [P] [US3] Generate `fixtures/negative/cc-missing-on-main.json` — manifest variant with the `main.sqlite3` `sqlite_pages` entry omitting `change_counter`; schema MUST reject

### GREEN verification for User Story 3

- [ ] T033 [US3] Execute `harness/verify-change-counter.sh fixtures/canonical/served/manifest.json`; capture pass log to `evidence/us3-change-counter-pass.log`
- [ ] T034 [US3] Execute `harness/verify-schema.sh fixtures/negative/cc-on-other-sqlite.json` and `harness/verify-schema.sh fixtures/negative/cc-missing-on-main.json`; assert non-zero exit on each; capture rejection logs to `evidence/us3-negative-rejections.log`

**Checkpoint**: CR001-007 verified — `change_counter` is exposed exclusively on the `main.sqlite3` entry.

---

## Phase 6: User Story 4 — Chunk delivery honors Accept-Encoding (Priority: P2)

**Goal**: Chunk URLs return `Content-Encoding: zstd` for `Accept-Encoding: zstd`, `Content-Encoding: gzip` for `Accept-Encoding: gzip`, and HTTP 406 with body containing `zstd` and `gzip` for any unsupported encoding.

**Independent Test**: `harness/verify-accept-encoding.sh` issues all three request shapes against the stub server and asserts the contract.

### RED tests for User Story 4

- [ ] T035 [P] [US4] Author `harness/verify-accept-encoding-zstd.sh` — `curl -sS -i -H 'Accept-Encoding: zstd' <chunk-url>`; assert HTTP 200, `Content-Encoding: zstd`, decompressed payload's SHA-256 matches manifest's recorded hash (US-4 AS-1)
- [ ] T036 [P] [US4] Author `harness/verify-accept-encoding-gzip.sh` — `curl -sS -i -H 'Accept-Encoding: gzip' <chunk-url>`; assert HTTP 200, `Content-Encoding: gzip`, decompressed payload's SHA-256 matches manifest's recorded hash (US-4 AS-2)
- [ ] T037 [P] [US4] Author `harness/verify-accept-encoding-406.sh` — `curl -sS -i -H 'Accept-Encoding: identity' <chunk-url>`; assert HTTP 406, body grep matches both `zstd` and `gzip` (US-4 AS-3, CR001-005)

### GREEN verification for User Story 4

- [ ] T038 [US4] Run `harness/stub-server.py fixtures/canonical/served/` and execute `harness/verify-accept-encoding-zstd.sh <stub-base-url>/files/pocketdb/main.sqlite3/pages/0`; capture pass log to `evidence/us4-zstd-pass.log`
- [ ] T039 [US4] Execute `harness/verify-accept-encoding-gzip.sh <stub-base-url>/files/pocketdb/main.sqlite3/pages/0`; capture pass log to `evidence/us4-gzip-pass.log`
- [ ] T040 [US4] Execute `harness/verify-accept-encoding-406.sh <stub-base-url>/files/pocketdb/main.sqlite3/pages/0`; capture pass log to `evidence/us4-406-pass.log`

**Checkpoint**: CR001-005 and US-4 verified end-to-end against the stub server.

---

## Phase 7: User Story 5 — Server publishes manifests no older than 30 days (Priority: P2)

**Goal**: The latest published canonical's `canonical_identity.created_at` is within 30 days of "now."

**Independent Test**: `harness/verify-freshness.sh` parses `created_at` and asserts `(now - created_at) ≤ 30 days`.

### RED tests for User Story 5

- [ ] T041 [P] [US5] Author `harness/verify-freshness.sh` — extracts `canonical_identity.created_at`, parses as RFC 3339 UTC, computes days delta against `date -u +%s`, asserts ≤ 30; emits `freshness OK` or `freshness VIOLATION` (CR001-008, US-5 AS-1)

### Negative-test fixture for User Story 5

- [ ] T042 [P] [US5] Generate `fixtures/negative/manifest-stale.json` — a manifest variant whose `canonical_identity.created_at` is 60 days before today (used to confirm the harness catches violations)

### GREEN verification for User Story 5

- [ ] T043 [US5] Set the US1 fixture manifest's `created_at` to `(today − 7 days)` (UTC) and re-emit `manifest.json` + recompute `trust-root.sha256` (depends T018, T019)
- [ ] T044 [US5] Execute `harness/verify-freshness.sh fixtures/canonical/served/manifest.json`; capture `freshness OK` log to `evidence/us5-freshness-pass.log`
- [ ] T045 [US5] Execute `harness/verify-freshness.sh fixtures/negative/manifest-stale.json`; assert non-zero exit / `freshness VIOLATION`; capture rejection log to `evidence/us5-stale-rejection.log`

**Checkpoint**: CR001-008 verified — freshness predicate is exercisable and discriminates conforming vs. stale.

---

## Phase 8: User Story 6 — Chunk 004 drill canonical exists (Priority: P2)

**Goal**: A canonical published by this chunk is pinned as the drill canonical for Chunk 004; the drill rig's doctor build pins this canonical's trust-root.

**Independent Test**: Given a pinned drill block height H, the manifest URL resolves and the published trust-root matches the drill rig's compiled-in pin.

### RED test for User Story 6

- [ ] T046 [US6] Author `harness/verify-drill-canonical.sh` — accepts `<base>`, `<drill-height>`, `<expected-trust-root-hex>`; fetches `<base>/canonicals/<drill-height>/manifest.json` and `<base>/canonicals/<drill-height>/trust-root.sha256`, runs `verify-trust-root.sh` against them, and asserts the sidecar value equals `<expected-trust-root-hex>` (CSC001-003, US-6 AS-1)

### Implementation for User Story 6

- [ ] T047 [US6] Author `fixtures/README.md` documenting (a) the drill-canonical pinning procedure for sibling `delt.3` (which canonical's trust-root the drill rig's doctor build will compile in), (b) how `harness/verify-drill-canonical.sh` is run against `delt.3`'s deployed canonical at gate-evaluation time

### GREEN verification for User Story 6

- [ ] T048 [US6] Execute `harness/verify-drill-canonical.sh <stub-base-url> <fixture-block-height> <fixture-trust-root>` against the synthetic fixture as a stand-in for the real drill canonical; capture pass log to `evidence/us6-drill-canonical-stub-pass.log` (real-canonical verification is deferred to `delt.3` deployment)

**Checkpoint**: CSC001-003 verified at the harness level; deferred concrete drill-canonical verification is documented as a `delt.3` action.

---

## Phase 9: Polish, Cross-Cutting, and Outbound Gates

**Purpose**: Capture the gate evidence bundles, document the hand-off to `delt.3`, run the quickstart end-to-end, and emit the FR/SC traceability matrix.

- [ ] T049 [P] Author `specs/002-001-delta-recovery-client-chunk-001/CONTRACT-HANDOFF.md` enumerating what `delt.3` must produce (manifest schema-conforming output, chunk store under the chunk-url grammar, trust-root sidecar, encoding-negotiation contract) and how to run the harness against `delt.3`'s deployed canonical (BC-003 inheritance from existing channel is recorded here as a non-test invariant)
- [ ] T050 Run `quickstart.md` Steps 1–6 end-to-end against the synthetic fixture (via `harness/stub-server.py`); capture full stdout transcript to `evidence/quickstart-end-to-end.log`
- [ ] T051 Outbound Gate 001-Schema → 002 evidence — bundle to `evidence/gate-001-schema-to-002.md`: (a) frozen `contracts/manifest.schema.json` reference, (b) schema meta-validation pass log (`evidence/schema-meta-validation.log`), (c) canonical-form rule citation evidence (`evidence/schema-comment-citation.log`), (d) required-fields evidence (`evidence/schema-required-fields.log`), (e) `change_counter` conditional evidence (`evidence/schema-change-counter-conditional.log`)
- [ ] T052 Outbound Gate 001 → 002 evidence — bundle to `evidence/gate-001-to-002.md`: (a) US1 trust-root match log, (b) US1 schema validation pass log, (c) US1 sampled-chunks SHA-256 match log (`main.sqlite3` page, `blocks/`, `chainstate/`), (d) US4 zstd / gzip / 406 logs, (e) US5 freshness pass log
- [ ] T053 Evidence matrix — write `evidence/evidence-matrix.md` mapping every CR001-001..008 and every CSC001-001..003 (and BC-001..003) to the concrete tasks and evidence files that verify them; cross-reference each acceptance scenario from `spec.md`'s six user stories

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies; can start immediately
- **Foundational (Phase 2)**: depends on Setup; BLOCKS every user story phase
- **User Stories (Phases 3–8)**: each depends on Foundational; once Foundational is complete, US1..US6 may proceed in parallel where staffing permits
- **Polish + Gates (Phase 9)**: depends on every story phase being green

### User Story Dependencies

- **US1 (P1)**: independent; produces the canonical fixture (`manifest.json`, `trust-root.sha256`, pre-compressed variants) reused by US2..US6
- **US2 (P1)**: depends on US1 fixture (T018, T019)
- **US3 (P1)**: depends on US1 fixture (T018) for `change_counter` baseline
- **US4 (P2)**: depends on US1 pre-compressed variants (T020, T021) and Foundational stub server (T011)
- **US5 (P2)**: depends on US1 fixture (T018, T019)
- **US6 (P2)**: depends on US1 fixture (T018, T019) for stand-in verification

### Within Each User Story

- Fixture (test data) → RED tests → implementation → GREEN verification (TDD discipline; do not invert)
- Different file = `[P]`; same file or sequential dependency = no `[P]`

### Parallel Opportunities

- All Setup `[P]` tasks (T002, T003, T004) run concurrently after T001
- All Foundational `[P]` tasks (T005–T008) run concurrently; T009 and T010 are sequential consistency checks; T011 is independent of T005–T010
- US1 fixtures T012, T013, T014 run concurrently; US1 RED tests T015, T016, T017 run concurrently; US1 pre-compression T020, T021 run concurrently
- Once US1 is green, US2..US6 phases may run concurrently
- Polish `[P]` tasks (T049) run concurrently with each other; T050–T053 are sequential

---

## Parallel Example: User Story 1

```bash
# Fixtures (test-data setup) — three independent source files
Task: "Generate synthetic pocketdb/main.sqlite3 source bytes (T012)"
Task: "Generate synthetic blocks/000000.dat source bytes (T013)"
Task: "Generate synthetic chainstate/CURRENT source bytes (T014)"

# RED tests — three independent harness scripts
Task: "Author harness/verify-schema.sh (T015)"
Task: "Author harness/verify-trust-root.sh (T016)"
Task: "Author harness/verify-sampled-chunks.sh (T017)"

# Pre-compression of fixture chunks — two independent passes
Task: "Pre-compress fixture chunks to .zst variants (T020)"
Task: "Pre-compress fixture chunks to .gz variants (T021)"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1: Setup
2. Phase 2: Foundational (frozen-contract self-validation + stub server)
3. Phase 3: US1 fixture + RED tests + implementation + GREEN
4. **STOP and VALIDATE** — chunking-doc Independent Test for US-1 passes against the fixture
5. This is the MVP — the load-bearing contract is verifiable end-to-end

### Incremental Delivery

1. After MVP, add US2 (determinism) → independently verifiable
2. Add US3 (`change_counter`) → independently verifiable, including negative cases
3. Add US4 (Accept-Encoding) → end-to-end via the stub server
4. Add US5 (freshness) → independently verifiable
5. Add US6 (drill canonical) → harness in place, real-canonical verification deferred to `delt.3`
6. Phase 9 packages outbound gate evidence and emits the FR→task→SC matrix

### Outbound Gates

Two outbound gates this chunk produces (per `pre-spec-strategic-chunking.md` §Chunk 001):

- **Gate 001-Schema → 002 (Manifest schema frozen)** — evidence bundle in T051
- **Gate 001 → 002 (Chunk Store Available, full)** — evidence bundle in T052

Both gates are predicated on the harness running green against a conforming canonical. The synthetic fixture proves the contract is satisfiable in this repo; the real-canonical verification is `delt.3`'s deployment-time gate, executed using this harness.

---

## Notes

- `[P]` tasks operate on different files with no dependency on incomplete tasks.
- This chunk produces **no production source code** in this repo (per plan.md non-goals); all artifacts are contracts, fixtures, harness scripts, and evidence logs.
- The harness is the test surface — running it green against a conforming canonical IS the gate evidence.
- BC-003 (concurrent fetches at typical operator scale) is inherited from the existing full-snapshot distribution channel and is operationally owned by `delt.3`; it is named in `CONTRACT-HANDOFF.md` (T049) but not exercised by harness load testing in this chunk.
- Verify each RED test fails before its implementation lands; commit per task or per logical group.
- Avoid: vague tasks, file-collision conflicts, cross-story dependencies that break US independence.
