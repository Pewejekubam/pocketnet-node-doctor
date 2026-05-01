# Tasks: Client Foundation + Diagnose (Chunk 002)

**Branch**: `003-001-delta-recovery-client-chunk-002` | **Date**: 2026-04-30
**Input**: Design documents from `/specs/003-001-delta-recovery-client-chunk-002/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/plan.schema.json, contracts/cli-surface.md, quickstart.md

**Tests**: TDD ordering is mandatory for this chunk per the chunk-runner discipline. Every user story phase orders fixtures → RED tests → implementation → GREEN verification.

**Organization**: Tasks grouped by user story. All three user stories are P1 in the spec. Execution order is dependency-driven (US3 manifest verifier first → US2 predicates that consume the verified manifest → US1 diagnose orchestrator that integrates all foundational scaffolding).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Different file, no dependency on incomplete tasks — safe to parallelize.
- **[Story]**: `[US1]`/`[US2]`/`[US3]` only on user-story phase tasks; Setup, Foundational, and Polish carry no story label.

## Path Conventions

Idiomatic Go layout (per plan.md § Project Structure):

- `cmd/pocketnet-node-doctor/` — binary entry point
- `internal/<package>/` — library packages (Go-toolchain-enforced unexported)
- `tests/contract/`, `tests/integration/` — cross-package tests
- `testdata/small/`, `testdata/reference/` — fixture data
- `specs/003-001-delta-recovery-client-chunk-002/contracts/` — published contracts (plan.schema.json, cli-surface.md)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project-skeleton initialization. This is the first chunk that introduces in-repo source code.

- [X] T001 Initialize `go.mod` at repo root with module path `github.com/pocketnet-team/pocketnet-node-doctor` and Go 1.23+ minimum (per plan.md D1; iterator API in D14 requires 1.23). Pin specific minor version from current stable.
- [X] T002 [P] Create skeleton directory tree: `cmd/pocketnet-node-doctor/`, `internal/{cli,diagnose,preflight,manifest,plan,canonform,hashutil,exitcode,stderrlog,trustroot,buildinfo}/`, `tests/{contract,integration}/`, `testdata/{small,reference}/`. Empty `doc.go` per package to make Go-toolchain-recognizable.
- [X] T003 [P] Add `go.sum` placeholder + `.gitignore` entries for build artifacts (`pocketnet-node-doctor`, `*.test`, `coverage.out`, `testdata/reference/*.bin`).
- [X] T004 [P] Configure `gofmt` + `go vet` as the lint posture (no third-party linters in v1; matches "no runtime deps" pin from plan.md D2/D3 spirit). Document in repo root README or scripts/check.sh.

**Checkpoint**: Project compiles (`go build ./...` returns clean even with empty packages).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared infrastructure consumed by every user story. Must be complete + green before any user story starts.

**⚠️ CRITICAL**: No US3/US2/US1 work can begin until T021 passes.

### Foundational fixtures

- [X] T005 [P] Create canonform test fixtures in `internal/canonform/testdata/`: pairs of equivalent JSON inputs (different key orderings, varying whitespace) and the expected canonical-form bytes for each.
- [X] T006 [P] Create hashutil test fixtures in `internal/hashutil/testdata/`: a small synthetic SQLite-shaped page file (deterministic per-page bytes; pageSize=4096, ~16 pages) and a small whole-file fixture (a few KB of arbitrary bytes); record expected SHA-256 values in `expected.txt`.

### Foundational RED tests (write first; expected to fail)

- [X] T007 [P] `internal/canonform/canonform_test.go` — `Marshal(any) ([]byte, error)` produces sorted-keys, no-insignificant-whitespace, UTF-8 bytes per pre-spec Implementation Context. Round-trip stability: same input → same bytes regardless of source key order.
- [X] T008 [P] `internal/exitcode/exitcode_test.go` — typed sentinel constants `Success=0`, `GenericError=1`, `RunningNode=2`, `AheadOfCanonical=3`, `VersionMismatch=4`, `Capacity=5`, `PermissionReadOnly=6`, `ManifestFormatVersionUnrecognized=7` per cli-surface.md § Exit code allocation.
- [X] T009 [P] `internal/stderrlog/stderrlog_test.go` — `Logger.Info(format, args...)` always writes; `Logger.Debug(format, args...)` gated on `verbose=true`; output destination is `os.Stderr`; nothing written to `os.Stdout` (D16).
- [X] T010 [P] `internal/hashutil/whole_file_test.go` — `HashWholeFile(path) (string, error)` returns lowercase 64-hex SHA-256, streamed via 1 MiB buffer (D14); compares against fixture's `expected.txt`.
- [X] T011 [P] `internal/hashutil/sqlite_pages_test.go` — `HashSQLitePages(path, pageSize) (iter.Seq2[PageHash, error], error)` (Go 1.23+ iterator) yields `{offset, hash}` per page, `offset` non-negative multiple of `pageSize`, sorted ascending; compares against fixture's `expected.txt`.
- [X] T012 [P] `internal/buildinfo/buildinfo_test.go` — `Version`, `Commit`, `BuildDate` are package-level `var`s overridable via `-ldflags -X` per D11 mechanism (mirror).
- [X] T013 [P] `internal/trustroot/trustroot_test.go` — `PinnedHash` defaults to `a939828d349bc5259d2c79fe9251d4e3497d2d1518c944dfc91ae9594f029249` (v1 development trust-root per pre-spec Implementation Context); ldflags-overridable shape verified by reflection or build-tag test.

### Foundational implementations (make tests pass)

- [X] T014 [P] `internal/canonform/canonform.go` — `Marshal(any) ([]byte, error)`. Implement sorted-keys + no-insignificant-whitespace JSON via custom encoder or stdlib `encoding/json` + post-process; UTF-8 enforced; trailing newline NOT emitted (consumers SHA-256 the exact bytes).
- [X] T015 [P] `internal/exitcode/exitcode.go` — typed `Code int` with sentinel constants per T008.
- [X] T016 [P] `internal/stderrlog/stderrlog.go` — `Logger` struct wrapping `os.Stderr`; `New(verbose bool) *Logger`; `Info`/`Debug` methods. No structured logging (D16).
- [X] T017 [P] `internal/hashutil/whole_file.go` — `HashWholeFile(path string) (string, error)` using `crypto/sha256` streaming with 1 MiB buffer.
- [X] T018 [P] `internal/hashutil/sqlite_pages.go` — `HashSQLitePages(path string, pageSize int) (iter.Seq2[PageHash, error], error)`; `PageHash struct { Offset int64; Hash string }`; per-page exact-`pageSize` reads; emit `{offset, hash}` per page.
- [X] T019 [P] `internal/buildinfo/buildinfo.go` — `var Version, Commit, BuildDate string` — populated at build via `-ldflags -X internal/buildinfo.<field>=<value>`.
- [X] T020 [P] `internal/trustroot/trustroot.go` — `var PinnedHash = "a939828d349bc5259d2c79fe9251d4e3497d2d1518c944dfc91ae9594f029249"`. Override mechanism: `go build -ldflags "-X internal/trustroot.PinnedHash=<hex>"` per D11.

### Foundational GREEN verification

- [X] T021 Run `go test ./internal/canonform/... ./internal/exitcode/... ./internal/stderrlog/... ./internal/hashutil/... ./internal/buildinfo/... ./internal/trustroot/...` and confirm all foundational tests pass.

**Checkpoint**: Foundational scaffolding green. User story phases may now begin in dependency order.

---

## Phase 3: User Story 3 — Refuse an Inauthentic or Forward-Versioned Manifest (Priority: P1)

**Goal**: Doctor authenticates the canonical manifest by comparing its canonical-form-payload SHA-256 to the compiled-in trust-root. Mismatch → refuse with no chunk-store byte fetched. Unrecognized `format_version` → refuse with exit code 7. Non-empty `trust_anchors` → parsed but contents ignored (FR-018 forward-compat surface).

**Independent Test**: Four fixture rigs (Rig A valid; Rig B tampered manifest; Rig C `format_version: 2`; Rig D non-empty `trust_anchors`). Diagnose against Rig A succeeds; B refuses with EC-008 diagnostic + exit 1 + zero chunk fetches; C refuses exit 7; D succeeds with `trust_anchors` parsed but ignored.

**Why first in execution order**: US-001's diagnose orchestrator and US-002's version-mismatch and ahead-of-canonical predicates all consume the verified manifest. Implementing the manifest verifier first eliminates downstream blocking.

### US3 fixtures

- [ ] T022 [P] [US3] Create manifest fixture corpus in `tests/integration/testdata/manifests/`: `valid_v1.json` (parses, hashes to a known trust-root we mint here), `tampered.json` (bytewise edited after minting), `format_version_2.json` (otherwise valid manifest with `format_version: 2`), `trust_anchors_nonempty.json` (valid v1 manifest with `trust_anchors: {"experimental": "ignored-by-v1"}`); record each manifest's canonform SHA-256 in `expected.txt`.
- [ ] T023 [P] [US3] Create test HTTPS rig harness in `tests/integration/testdata/rigs/manifest_serving.go`: `httptest.NewTLSServer` instances Rig A/B/C/D each serving the corresponding fixture at `/canonicals/3806626/manifest.json`.

### US3 RED tests

- [ ] T024 [P] [US3] `tests/contract/manifest_schema_test.go` — load Chunk 001's manifest schema (sibling spec dir's `contracts/manifest.schema.json`) and validate the four fixtures from T022 — `valid_v1`, `format_version_2`, `trust_anchors_nonempty` parse cleanly; `tampered` may or may not depending on tamper kind (document expectation in test).
- [ ] T025 [P] [US3] `internal/manifest/fetch_test.go` — `Fetch(ctx, url) ([]byte, error)` GETs manifest via stdlib `net/http`; 30 s timeout (D17); custom `User-Agent: pocketnet-node-doctor/<version> (chunk-002)` header set; HTTPS-only enforcement (refuse non-`https://` URLs).
- [ ] T026 [P] [US3] `internal/manifest/verify_test.go` — `Verify(bytes []byte, pinnedHash string) error` re-serializes parsed manifest via `internal/canonform` and SHA-256s; PASS when computed == pinned; REFUSE with `TrustRootMismatchError{Computed, Expected}` (EC-008) when ≠.
- [ ] T027 [P] [US3] `internal/manifest/parse_test.go` — `Parse(bytes []byte) (*Manifest, error)` typed-struct unmarshal of v1 manifest fields the doctor consumes (per data-model.md § Entity: Manifest (consumed)): `format_version`, `canonical_identity.{block_height,pocketnet_core_version,created_at}`, `entries[*]` (page-level for `main.sqlite3`, whole-file for non-SQLite), `entries[*].change_counter` (where `path == "pocketdb/main.sqlite3"`), `trust_anchors`.
- [ ] T028 [P] [US3] `internal/manifest/format_version_test.go` — `CheckFormatVersion(*Manifest) error` PASS when `format_version == 1`; REFUSE with `FormatVersionUnrecognizedError{Got, Recognized: 1}` when `≠ 1` (CSC002-002).
- [ ] T029 [P] [US3] `internal/manifest/trust_anchors_test.go` — non-empty `trust_anchors` block parsed for presence (required field per Chunk 001 schema) but contents not inspected; doctor proceeds normally (FR-018; US-003 acceptance scenario 4).
- [ ] T030 [P] [US3] `tests/integration/us003_trust_root_test.go` — end-to-end: drive `internal/manifest` against Rig A → `Verify` PASS; Rig B → `Verify` returns `TrustRootMismatchError`, no subsequent chunk-store fetch attempted (assertion: rig logs zero post-manifest GETs); Rig C → `CheckFormatVersion` returns `FormatVersionUnrecognizedError`, mapped exit 7 by orchestrator; Rig D → both Verify and CheckFormatVersion PASS, `trust_anchors` populated but contents not consulted (US-003 acceptance scenarios 1–4).

### US3 implementations

- [ ] T031 [P] [US3] `internal/manifest/fetch.go` — `Fetch(ctx context.Context, url string) ([]byte, error)` with `http.Client{Timeout: 30 * time.Second}`, default redirect (follow up to 10), default TLS (system CA trust), custom `User-Agent` via custom `http.RoundTripper` per D17.
- [ ] T032 [P] [US3] `internal/manifest/verify.go` — `Verify(bytes []byte, pinnedHash string) error`. Steps per D13: parse → canonform-re-serialize → SHA-256 → compare. Mismatch returns `TrustRootMismatchError{Computed, Expected string}`.
- [ ] T033 [P] [US3] `internal/manifest/parse.go` — typed `Manifest` struct mirroring Chunk 001's frozen schema (data-model.md § Entity: Manifest (consumed)); `Parse(bytes []byte) (*Manifest, error)` via `encoding/json`.
- [ ] T034 [P] [US3] `internal/manifest/format_version.go` — `CheckFormatVersion(m *Manifest) error`; `FormatVersionUnrecognizedError` typed.
- [ ] T035 [US3] `internal/manifest/trust_anchors.go` — `ParseTrustAnchors(m *Manifest) (TrustAnchors, error)`; presence-required, contents-ignored (FR-018).

### US3 GREEN verification

- [ ] T036 [US3] Run `go test ./internal/manifest/... ./tests/contract/manifest_schema_test.go ./tests/integration/us003_trust_root_test.go` and confirm all US3 tests pass.

**Checkpoint**: Manifest verifier (US-003) is fully functional and independently testable. US2 + US1 may now consume `*Manifest`.

---

## Phase 4: User Story 2 — Refuse to Damage a Healthy or Running Node (Priority: P1)

**Goal**: Five pre-flight refusal predicates evaluated in canonical order with stop-at-first-refusal. Each predicate emits a distinct exit code (2/3/4/5/6) and a diagnostic naming the predicate; no `pocketdb/` byte read on refusal; no `plan.json` emitted on refusal.

**Independent Test**: Six fixture rigs — five each violating exactly one predicate, plus one all-pass rig from US-001. Each refusing rig produces predicate-specific exit code + diagnostic; no pocketdb mutation; all-pass rig proceeds to manifest verification.

### US2 fixtures

- [ ] T037 [P] [US2] Create six fixture rigs under `tests/integration/testdata/rigs-us002/`: `rig_running_node/` (advisory lock held on `main.sqlite3` by harness), `rig_ahead_of_canonical/` (synthetic `main.sqlite3` whose header `change_counter` strictly exceeds canonical), `rig_version_mismatch/` (stub `pocketnet-core` shim binary in `PATH` reporting non-canonical version), `rig_capacity/` (small loop-mounted volume sized below 2× plan-listed-size), `rig_permission_readonly/` (read-only-mounted volume), `rig_all_pass/` (everything green; reused as US-001 fixture base).

### US2 RED tests

- [ ] T038 [P] [US2] `internal/preflight/running_node_test.go` — predicate trips when (a) advisory lock probe fails (foreign lock per EC-004), or (b) process scan finds `pocketnet-core`/`pocketnetd` holding any fd under resolved pocketdb tree; returns `Refuse{Code: 2, Diagnostic: ...}`. Cross-platform: stub `golang.org/x/sys/unix` flock on POSIX, `golang.org/x/sys/windows.LockFileEx` on Windows (D8).
- [ ] T039 [P] [US2] `internal/preflight/version_mismatch_test.go` — invokes `pocketnet-core --version` via `os/exec`, parses first stdout line, string-compares against `manifest.canonical_identity.pocketnet_core_version`. Mismatch → `Refuse{Code: 4}`. `pocketnet-core` not on PATH → fail-open: returns generic-error sentinel (mapped to exit 1 by orchestrator) with diagnostic "pocketnet-core not on PATH" — NOT the version-mismatch refusal (data-model.md § Special case).
- [ ] T040 [P] [US2] `internal/preflight/volume_capacity_test.go` — predicate computes required-bytes = 2 × Σ(manifest entry sizes) per data-model.md row; `syscall.Statfs` (POSIX) / `GetDiskFreeSpaceExW` (Windows) on the volume holding `pocketdb/`; refuses with `Refuse{Code: 5, Diagnostic: "<volume> has <free> free; needs <required>"}` when `free < required`.
- [ ] T041 [P] [US2] `internal/preflight/permission_readonly_test.go` — `access(W_OK)` probe + mount-flag check (Linux: parse `/proc/mounts`; Darwin: `getmntinfo`; Windows: `GetVolumeInformation` for `FILE_READ_ONLY_VOLUME` flag). Refuses with `Refuse{Code: 6}` when either trips (EC-011).
- [ ] T042 [P] [US2] `internal/preflight/ahead_of_canonical_test.go` — direct file-header parse per D7: `O_RDONLY` open → 100-byte read → validate magic `"SQLite format 3\0"` at offset 0 → BE-uint32 `change_counter` at offset 24. Refuses with `Refuse{Code: 3}` when `local > canonical`. Malformed/short header → fail-open with generic-error sentinel (NOT the ahead-of-canonical code).
- [ ] T043 [P] [US2] `internal/preflight/orchestrator_test.go` — `Evaluate(ctx PreflightContext) PredicateResult` runs predicates in canonical order: running-node → (manifest fetch+verify happens between in caller) → version-mismatch → volume-capacity → permission/read-only → ahead-of-canonical. **Stop at first refusal** (Q2/A2): only the first refusing predicate's `Refuse{Code,Diagnostic}` is returned; subsequent predicates are NOT invoked (assertion: count predicate call invocations).
- [ ] T044 [P] [US2] `tests/integration/us002_predicates_test.go` — drive end-to-end against the six rigs from T037: each refusing rig produces its predicate-specific exit code + diagnostic on stderr; FR-005 invariant verified (mtime+sha256 of all `pocketdb/` files unchanged after refusal — US-002 scenario 7); `plan.json` is NOT created at the resolved `--plan-out` path (Q1/A1; US-002 scenario 7); the `rig_all_pass` rig proceeds past predicates.

### US2 implementations

- [ ] T045 [P] [US2] `internal/preflight/types.go` — `PredicateResult` typed (Pass | Refuse); `Refuse{Code int, Diagnostic string}`; `PreflightContext{PocketDBPath string; Manifest *manifest.Manifest; Logger *stderrlog.Logger}` per data-model.md § Entity: Pre-flight Context.
- [ ] T046 [P] [US2] `internal/preflight/running_node.go` — D8 mechanism: step 1 advisory-lock probe (`flock LOCK_EX|LOCK_NB` on POSIX via `golang.org/x/sys/unix`; `LockFileEx` w/ `LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY` on Windows via `golang.org/x/sys/windows`; release immediately on success); step 2 process scan via `gopsutil/v3/process` for `pocketnet-core`/`pocketnetd` holding fd in pocketdb tree.
- [ ] T047 [P] [US2] `internal/preflight/version_mismatch.go` — `os/exec` invoke `pocketnet-core --version`; parse first line; compare against `ctx.Manifest.CanonicalIdentity.PocketnetCoreVersion`.
- [ ] T048 [P] [US2] `internal/preflight/volume_capacity.go` — POSIX `syscall.Statfs` / Windows `GetDiskFreeSpaceExW` (build-tag-split files `volume_capacity_unix.go`, `volume_capacity_windows.go`); required = 2 × Σ(manifest entry sizes).
- [ ] T049 [P] [US2] `internal/preflight/permission_readonly.go` — `access(W_OK)` probe via `syscall.Access`; mount-flag check (build-tag-split `permission_readonly_linux.go`/`_darwin.go`/`_windows.go`).
- [ ] T050 [P] [US2] `internal/preflight/ahead_of_canonical.go` — `os.OpenFile(path, O_RDONLY, 0)` → `io.ReadFull(f, header[:100])` → magic-bytes-at-0 check → `binary.BigEndian.Uint32(header[24:28])`; compare to `ctx.Manifest.entries["pocketdb/main.sqlite3"].change_counter`.
- [ ] T051 [US2] `internal/preflight/orchestrator.go` — `Evaluate(ctx)` linear runner; canonical order (running-node first, then post-manifest predicates: version-mismatch → capacity → permission → ahead-of-canonical); stop-at-first-refusal.

### US2 GREEN verification

- [ ] T052 [US2] Run `go test ./internal/preflight/... ./tests/integration/us002_predicates_test.go` and confirm all US2 tests pass.

**Checkpoint**: All five refusal predicates fire correctly; orchestrator stops at first refusal. US-002 independently functional.

---

## Phase 5: User Story 1 — Diagnose a Dead Node (Priority: P1) 🎯 MVP

**Goal**: `pocketnet-node-doctor diagnose --canonical <url> --pocketdb <path>` produces a `plan.json` listing divergences + a human-readable summary on stderr; exits 0 on success; performs zero writes to `pocketdb/`. Integrates US-002's predicate orchestrator and US-003's manifest verifier.

**Independent Test**: 30-day-divergent fixture pocketdb against fixture canonical → plan with divergent entries + summary + exit 0 + bitwise-unchanged pocketdb. Identical-to-canonical fixture → zero-entry plan + "no recovery needed" summary + exit 0.

### US1 fixtures

- [ ] T053 [P] [US1] Create five US1 fixture rigs under `tests/integration/testdata/rigs-us001/`: `fixture_30day_divergent/` (synthetic ~30-day-aged pocketdb against fixture canonical; small-scale — laptop-runnable), `fixture_identical_to_canonical/` (bitwise-identical rig), `fixture_corrupt_main_sqlite3/` (selectively corrupted pages — US-001 scenario 3), `fixture_missing_pocketdb/` (entirely-absent pocketdb directory — EC-001), `fixture_partial_pocketdb/` (`main.sqlite3` present, `chainstate/` missing — EC-002).

### US1 RED tests

- [ ] T054 [P] [US1] `tests/contract/plan_schema_test.go` — emitted `plan.json` from `fixture_30day_divergent` validates against `specs/003-001-delta-recovery-client-chunk-002/contracts/plan.schema.json` (Draft 2020-12); both `sqlite_pages` and `whole_file` divergence shapes exercised.
- [ ] T055 [P] [US1] `internal/plan/marshal_test.go` — `Marshal(p Plan) ([]byte, error)` produces canonform bytes via `internal/canonform`; `Unmarshal(b []byte) (Plan, error)` round-trips; `unevaluatedProperties: false` enforced (top-level + sub-objects per data-model.md).
- [ ] T056 [P] [US1] `internal/plan/self_hash_test.go` — `ComputeSelfHash(p Plan) (string, error)` strips `self_hash` field, canonform-serializes, SHA-256s, returns lowercase 64-hex; `VerifySelfHash(p Plan) error` re-computes and compares; tampered plan (mutated `divergences[0].expected_hash`) detected (CSC002-001).
- [ ] T057 [P] [US1] `internal/cli/parse_test.go` — `flag.NewFlagSet` per subcommand (`diagnose`, `apply`); long-form-only flags `--canonical`, `--pocketdb`, `--plan-out`, `--verbose`; global `--help`, `--version` (D3, D4); unknown short forms rejected.
- [ ] T058 [P] [US1] `internal/cli/plan_out_default_test.go` — when `--plan-out` is unset, `ResolvePlanOut(pocketdbPath, planOut)` returns `<dirname pocketdbPath>/plan.json` (D5; e.g., `/var/lib/pocketnet/pocketdb` → `/var/lib/pocketnet/plan.json`).
- [ ] T059 [P] [US1] `internal/diagnose/plan_out_writability_test.go` — up-front non-predicate writability probe creates `<plan-out-dir>/.pocketnet-node-doctor-writeprobe-<rand>`, writes one byte, `fsync`s, unlinks. Failure (permission denied / ENOSPC / read-only / missing parent dir) returns generic-error sentinel + diagnostic naming the unwritable target (D6; cli-surface.md § Plan-out writability probe).
- [ ] T060 [P] [US1] `internal/diagnose/orchestrator_test.go` — `Diagnose(ctx, opts)` execution sequence per cli-surface.md § Predicate Sequence: argument validation → running-node predicate → manifest fetch+verify+format_version → remaining 4 predicates → plan-out writability probe → hash phase → plan emission → summary emission → clean exit.
- [ ] T061 [P] [US1] `internal/diagnose/missing_file_test.go` — EC-001: `fixture_missing_pocketdb` rig — every canonical entry becomes a `whole_file` divergence with `expected_source: "fetch_full"` (data-model.md § Sub-entity: Divergence — `whole_file` shape).
- [ ] T062 [P] [US1] `internal/diagnose/partial_pocketdb_test.go` — EC-002: `fixture_partial_pocketdb` — missing files become `whole_file` divergences with `expected_source: "fetch_full"`; present-but-divergent files use the normal divergence shape (no `expected_source` marker).
- [ ] T063 [P] [US1] `internal/diagnose/atomic_write_test.go` — plan written via temp-file-and-rename: write to `<plan-out>.tmp.<rand>` → `fsync` → `os.Rename` to `<plan-out>` (cli-surface.md § Output destinations); on any failure during write, temp file is unlinked. Concurrent-process safe.
- [ ] T064 [P] [US1] `internal/diagnose/no_write_test.go` — FR-005: capture `mtime`+SHA-256 of every file under `pocketdb/` before run; run diagnose; capture again; assert zero diff (US-001 acceptance scenario 1; quickstart.md Step 7).
- [ ] T065 [P] [US1] `internal/diagnose/summary_test.go` — D9 fixed-template summary on stderr; IEC binary units (KiB/MiB/GiB/TiB); ETA = `total_bytes_to_fetch / 50 MiB/s`; exact template per cli-surface.md § Summary; zero-divergence variant ("no recovery needed: local pocketdb matches canonical bitwise.").
- [ ] T066 [P] [US1] `internal/diagnose/progress_test.go` — D10 progress messages on stderr: class-entry `[diagnose] hashing <class>...`; `main.sqlite3` 5%-cadence `[diagnose] hashing main.sqlite3 pages: <N> / <total> (<pct>%)`; `blocks/`/`chainstate/`/`indexes/` 25-files-cadence `[diagnose] hashing <class>: <N> / <total> files`; class-exit `[diagnose] hashed <class> in <elapsed>`.
- [ ] T067 [P] [US1] `internal/diagnose/stdout_silence_test.go` — diagnose writes nothing to `os.Stdout` (Q3/A3; cli-surface.md § Output destinations). Capture stdout, assert empty.
- [ ] T068 [P] [US1] `internal/diagnose/zero_divergence_test.go` — `fixture_identical_to_canonical` → `divergences: []` plan + "no recovery needed" summary variant (US-001 scenario 2; SC-002).
- [ ] T069 [P] [US1] `internal/diagnose/canonical_identity_test.go` — emitted plan's `canonical_identity.{block_height, manifest_hash, pocketnet_core_version}` is copied verbatim from the verified manifest (US-001 acceptance scenario 5; data-model.md § Sub-entity: Canonical Identity).
- [ ] T070 [P] [US1] `internal/diagnose/corruption_indistinguishable_test.go` — `fixture_corrupt_main_sqlite3` → divergences for corrupt pages, indistinguishable in shape from drift divergences (US-001 acceptance scenario 3).
- [ ] T071 [P] [US1] `tests/integration/us001_diagnose_test.go` — end-to-end on small fixtures: `fixture_30day_divergent` → exit 0, plan listing differing pages + files, summary on stderr, FR-005 zero-write invariant. `fixture_identical_to_canonical` → exit 0, zero-entry plan, no-recovery-needed summary.
- [ ] T072 [US1] `tests/integration/sc001_timing_test.go` — SC-001 timing-half: build-tag `//go:build reference_rig`. Diagnose against reference-rig-scale 30-day-divergent fixture completes ≤ 5 min end-to-end wall-clock (process invocation → clean exit; `plan.json` fully written + fsynced; all stderr flushed) on the reference rig (8 vCPU x86_64, NVMe-class disk, 16 GB RAM). Test calls `time.Now()` at process spawn and at exit; asserts < 5 min.
- [ ] T073 [US1] `tests/integration/sc002_zero_entry_timing_test.go` — SC-002: `//go:build reference_rig`. `fixture_identical_to_canonical` reference-rig-scale variant → zero-entry plan within 5 min same end-to-end wall-clock boundary as T072.
- [ ] T074 [US1] `tests/integration/sc006_predicate_codes_test.go` — SC-006: each of the five predicate rigs from T037 produces its distinct exit code (2/3/4/5/6); cross-references US-002 phase but bound to SC-006 in the evidence matrix.

### US1 implementations

- [ ] T075 [P] [US1] `internal/plan/types.go` — `Plan{FormatVersion int; CanonicalIdentity CanonicalIdentity; Divergences []Divergence; SelfHash string}`; `CanonicalIdentity{BlockHeight int64; ManifestHash, PocketnetCoreVersion string}`; `Divergence` discriminated by `DivergenceKind`: `SqlitePagesDivergence{Kind, Path string; Pages []PageEntry}` and `WholeFileDivergence{Kind, Path, ExpectedHash string; ExpectedSource string,omitempty}` (data-model.md § Sub-entity: Divergence).
- [ ] T076 [P] [US1] `internal/plan/marshal.go` — `Marshal(p Plan) ([]byte, error)` via `internal/canonform`; `Unmarshal(b []byte) (Plan, error)` via `encoding/json` with discriminated-union dispatch on `divergence_kind`.
- [ ] T077 [P] [US1] `internal/plan/self_hash.go` — `ComputeSelfHash(p Plan) (string, error)` clones plan, zeros `SelfHash`, canonform-serializes, SHA-256s, returns lowercase 64-hex; `VerifySelfHash(p Plan) error` re-computes and compares.
- [ ] T078 [P] [US1] `internal/cli/cli.go` — subcommand dispatcher; `flag.FlagSet` per subcommand; `--help` per-subcommand and top-level (per cli-surface.md § --help output); `--version` writes to stdout (the single intentional stdout writer; not part of diagnose pathway).
- [ ] T079 [P] [US1] `internal/cli/plan_out.go` — `ResolvePlanOut(pocketdbPath, planOut string) (string, error)` per D5.
- [ ] T080 [P] [US1] `internal/diagnose/writability_probe.go` — `ProbeWritable(planOutPath string) error` per D6.
- [ ] T081 [P] [US1] `internal/diagnose/page_compare.go` — `ComparePages(pocketdbPath string, manifestEntry ManifestEntry) ([]PageEntry, error)` — stream-iterates `hashutil.HashSQLitePages` over `<pocketdb>/main.sqlite3`, compares each `(offset, hash)` against the manifest's per-page hash, accumulates divergent pages.
- [ ] T082 [P] [US1] `internal/diagnose/file_compare.go` — `CompareFile(pocketdbPath string, manifestEntry ManifestEntry) (Divergence, error)` — `hashutil.HashWholeFile` for non-SQLite artifacts; missing file → `WholeFileDivergence{ExpectedSource: "fetch_full"}` (EC-001/EC-002).
- [ ] T083 [P] [US1] `internal/diagnose/atomic_write.go` — `WritePlanAtomic(p Plan, planOutPath string) error` — temp file + fsync + rename; cleanup on error.
- [ ] T084 [P] [US1] `internal/diagnose/summary.go` — D9 renderer; IEC binary units; 50 MiB/s ETA constant.
- [ ] T085 [P] [US1] `internal/diagnose/progress.go` — D10 emitter; 5%-cadence + 25-file-cadence milestones; via `stderrlog.Logger.Info`.
- [ ] T086 [US1] `internal/diagnose/orchestrator.go` — `Diagnose(ctx context.Context, opts Options) (exitcode.Code, error)` — sequences: arg validation → running-node predicate → manifest Fetch/Verify/Parse/CheckFormatVersion/ParseTrustAnchors → remaining 4 predicates with manifest-populated PreflightContext → plan-out writability probe → page+file compare → plan emission → summary emission. Stop-at-first-refusal at every refusing surface.
- [ ] T087 [US1] `cmd/pocketnet-node-doctor/main.go` — entry point: parse top-level subcommand, dispatch to `internal/cli`; map orchestrator's `exitcode.Code` to `os.Exit`; `apply` subcommand stub returns generic error 1 with "apply not implemented in chunk 002" diagnostic (Chunk 003 owns).

### US1 GREEN verification

- [ ] T088 [US1] Run `go test ./...` (without `reference_rig` build tag) and confirm all small-fixture tests pass.
- [ ] T089 [US1] On the reference rig (8 vCPU x86_64, NVMe-class disk, 16 GB RAM), run `go test -tags reference_rig ./tests/integration/sc001_timing_test.go ./tests/integration/sc002_zero_entry_timing_test.go` and confirm SC-001 timing-half + SC-002 5-minute budgets are met. Record wall-clock results in evidence matrix (T096). This is a manual run; not a CI gate (per Known Coverage Gaps in plan.md).

**Checkpoint**: All three user stories independently functional. Diagnose pathway is the chunk's MVP.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Quickstart validation, build-time verification, outbound-gate evidence bundle, evidence matrix.

- [ ] T090 [P] Implement `--help` output text per cli-surface.md § --help output (top-level + per-subcommand text, including exit-code allocation).
- [ ] T091 [P] Implement `--version` output text per cli-surface.md (semver from `internal/buildinfo.Version` + commit SHA + build date + `internal/trustroot.PinnedHash`); written to stdout per the single-intentional-stdout-writer carve-out.
- [ ] T092 [P] `tests/integration/quickstart_test.go` — execute quickstart.md Steps 1–8 against a fixture rig: build via `go build`, `--version` round-trip, `diagnose` against fixture, schema-validate emitted plan via `check-jsonschema`, self-hash round-trip via `jq -cS 'del(.self_hash)' | tr -d '\n' | sha256sum`, no-write invariant, trust-root negative test (build with `-ldflags -X internal/trustroot.PinnedHash=00...00`).
- [ ] T093 Verify `go build ./cmd/pocketnet-node-doctor` produces a single static binary on linux/amd64, darwin/arm64, windows/amd64 with no CGO (`CGO_ENABLED=0 go build` succeeds; binary `file` reports static linkage).
- [ ] T094 Verify static-binary completeness: `gopsutil/v3` and `modernc.org/sqlite` are both linked in (via `go list -deps`) but produce no operator-runtime dependencies (Linux: `ldd` reports no external libs; Darwin: `otool -L` minimal; Windows: `dumpbin /dependents` minimal).
- [ ] T095 Outbound Gate 002 → 003 evidence bundle — bundle: T072 (SC-001 timing half on reference rig), T073 (SC-002 zero-entry timing on reference rig), T056 + T030 (CSC002-001 plan self-hash round-trip — covered by self-hash unit tests + integration paths), T069 (plan canonical-identity bound to verified manifest), T074 (SC-006 five-predicate distinct codes), T028 + T030 (CSC002-002 manifest format-version refusal exit code 7). Per chunking-doc § Gate 002 → 003 predicates. Output: `tests/integration/gate_002_003_evidence.md` enumerating each predicate from chunking-doc Gate 002 → 003 with the task ID(s) producing the evidence and the test command + expected output for re-verification.
- [ ] T096 Evidence matrix — every FR + SC + EC the chunk owns maps to the concrete task(s) producing the evidence. Output: `specs/003-001-delta-recovery-client-chunk-002/evidence-matrix.md`. Required rows: FR-001 → T011/T018/T081; FR-002 → T010/T017/T082; FR-003 → T054/T055/T075/T076; FR-004 → T065/T084; FR-005 → T064/T071; FR-010 (+ EC-004) → T038/T046; FR-011 → T042/T050; FR-012 → T039/T047; FR-013 → T040/T048; EC-011 → T041/T049; FR-017 (+ EC-008) → T026/T030/T032; FR-018 → T028/T029/T030/T034/T035; SC-001 (timing half) → T072; SC-002 → T068/T073; SC-006 → T044/T074; CSC002-001 → T056/T071; CSC002-002 → T028/T030; EC-001 → T061/T082; EC-002 → T062/T082.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies — start immediately.
- **Foundational (Phase 2)**: depends on Setup; **BLOCKS all user stories** until T021 GREEN.
- **US3 (Phase 3)**: depends on Foundational; manifest verifier consumed by US2 + US1.
- **US2 (Phase 4)**: depends on Foundational + US3 (predicates orchestrator consumes `*Manifest`).
- **US1 (Phase 5)**: depends on Foundational + US3 + US2 (orchestrator integrates predicate orchestrator + manifest verifier + plan-format library + hash utilities).
- **Polish (Phase 6)**: depends on US1 GREEN; T095 + T096 are terminal evidence tasks.

### Within Each User Story

- Fixtures FIRST (no dependencies on other tasks within the story).
- RED tests SECOND — written and observed FAILING before any implementation.
- Implementation THIRD — writes the production code that turns RED tests GREEN.
- GREEN verification FOURTH — runs the test suite and confirms PASS.

This ordering is mandatory per chunk-runner discipline. If `speckit.superb.tdd` observes implementation-before-test in any phase, the chunk halts.

### Parallel Opportunities

- All Phase 1 tasks except T001 are `[P]` (T002–T004 operate on different paths).
- All Foundational fixtures (T005–T006), RED tests (T007–T013), and implementations (T014–T020) are `[P]` within their step (different files; no inter-task dependency until T021 verification).
- All US3 RED tests (T024–T030) are `[P]` (different files); T031–T034 implementations are `[P]`; T035 sequential after T033 (depends on `Manifest` struct).
- All US2 fixtures (T037), RED tests (T038–T044), and implementations (T045–T050) are `[P]` (different files); T051 orchestrator depends on T046–T050.
- All US1 RED tests (T054–T071) are `[P]` (different files); T072–T074 reference-rig and SC tests are sequential against the reference-rig environment; T075–T085 implementations are `[P]`; T086 orchestrator and T087 main.go are sequential.
- Polish tasks T090–T094 are `[P]`; T095 + T096 are terminal evidence and depend on prior tasks completing.

### Suggested MVP Scope

User Story 1 (diagnose pathway) is the MVP — it integrates US-002's predicate orchestrator and US-003's manifest verifier as direct dependencies, so reaching US-001 GREEN delivers the full chunk's value (read-only diagnose pathway + refusal posture + trust authentication).

---

## Notes

- All three user stories are P1 in the spec. Execution order is dependency-driven (US3 → US2 → US1) rather than priority-driven.
- The US-002 phase (predicates) consumes the verified `*Manifest` from US-003; that's why US-003 is sequenced first.
- The reference-rig timing tests (T072, T073) are gated behind `//go:build reference_rig` and are NOT exercised by `go test ./...` on dev laptops. They run as a manual chunk-acceptance gate on the named reference rig (per plan.md § Known Coverage Gaps).
- All foundational packages (`internal/canonform`, `internal/hashutil`, `internal/exitcode`, `internal/stderrlog`, `internal/buildinfo`, `internal/trustroot`) inherit unchanged into Chunk 003 — they are the cross-chunk inheritance surface from Chunk 002 → Chunk 003.
- The `apply` subcommand is reserved at the CLI surface (T087) but emits "not implemented in chunk 002" with exit code 1; Chunk 003 implements its body.
- Evidence-matrix discipline: T096 enumerates every FR/SC/EC the chunk owns and maps it to concrete task output. This is the chunk's audit-trail surface for the outbound Gate 002 → 003 review.
