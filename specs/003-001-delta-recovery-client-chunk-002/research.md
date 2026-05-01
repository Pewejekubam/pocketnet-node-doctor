# Phase 0 Research: Client Foundation + Diagnose (Chunk 002)

**Branch**: `003-001-delta-recovery-client-chunk-002` | **Date**: 2026-04-30 | **Plan**: [plan.md](plan.md)

## Scope

Phase 0 records findings backing the plan-stage decisions in [plan.md § Plan-Stage Decisions](plan.md). No `NEEDS CLARIFICATION` markers were carried into this phase: the spec's Clarifications session 2026-04-30 (Q1–Q5) closed every spec-level unknown except Q4 (the `--plan-out` writability timing), which the spec explicitly deferred to plan-stage and is resolved here at D6.

## Decision: Go SQLite binding (D2) — `modernc.org/sqlite` over `mattn/go-sqlite3`

- **Decision**: `modernc.org/sqlite`.
- **Rationale**:
  - **CGO-free static-binary requirement**: pre-spec Implementation Context pins "single static binary across Linux, macOS, and Windows with no runtime dependencies." `mattn/go-sqlite3` requires CGO, which (a) needs a C toolchain on every cross-compilation target, (b) produces dynamically-linked binaries by default unless caller takes care with `CGO_ENABLED=1` + static `-extldflags`, and (c) on macOS makes universal-binary builds harder. `modernc.org/sqlite` is a transpiled-from-C-source pure-Go SQLite that compiles with `go build` alone, no C toolchain required, producing a true static binary on all three target platforms.
  - **API parity**: both bindings register a `database/sql` driver. Code written against `database/sql` works against either — switching is a one-import-line change. Inheritance to Chunk 003 is non-coupling.
  - **License compatibility**: `modernc.org/sqlite` is BSD-3-Clause; `mattn/go-sqlite3` is MIT. Both are permissive and compatible with the doctor binary's intended distribution posture.
- **Alternatives considered**:
  - `mattn/go-sqlite3` — the older, more popular choice; rejected for the CGO posture above.
  - `crawshaw.io/sqlite` — pure-Go, but uses a non-`database/sql` API (`sqlite.OpenURI` style) which would couple the doctor's SQLite use sites to the binding choice. Rejected as more invasive.
  - Implementing the file-format parsing entirely without a binding — feasible for `change_counter` (D7 below) but not for chunk 003's `PRAGMA integrity_check`, which requires a live SQLite engine. The chunking-doc "single binding" pin requires choosing one; no point splitting.

## Decision: CLI flag grammar (D4) — long-form-only, stdlib `flag`

- **Decision**: stdlib `flag` package with one `flag.FlagSet` per subcommand. Long-form-only flags. No env-var overrides. Spec-pinned set: `--canonical`, `--pocketdb`, `--plan-out`, `--verbose`. Globals: `--help`, `--version`.
- **Rationale**:
  - **No-runtime-deps posture**: pre-spec pins "no runtime dependencies"; chunking-doc pins HTTP client to stdlib `net/http`. `flag` matches that pin.
  - **Subcommand structure**: spec/chunking-doc both pin subcommands `diagnose` and `apply` (no subcommand-collapsed-into-flags). `flag.NewFlagSet` per subcommand gives clean per-subcommand `--help` output and prevents flag-namespace collision between subcommands.
  - **No short forms in v1**: short-form flags are namespace decisions that are hard to reverse (operators acquire muscle memory). Reserving short-form namespace for v2 keeps options open.
  - **No env-var overrides**: chunking-doc Speckit Stop pins "no user-config file in v1; behavior controlled by CLI flags only." Env-var overrides would re-introduce the implicit-config surface that pin avoids.
- **Alternatives considered**:
  - `spf13/cobra` — popular, feature-rich; rejected for dep-weight relative to the small CLI surface.
  - `urfave/cli` — same rationale.
  - Stdlib `flag` with positional subcommand dispatch — chosen.

## Decision: `--plan-out` writability timing (D6) — up-front non-predicate probe (resolves spec Q4)

- **Decision**: after all five pre-flight predicates pass, before any pocketdb byte is read for hashing, the doctor probes the resolved `--plan-out` parent directory by writing and unlinking a small temporary file. On failure, refuse with exit code 1 and a diagnostic naming the unwritable target.
- **Rationale**:
  - **Operator UX**: the worst observable failure mode is "diagnose runs for 5 minutes and then errors at plan-write time." Up-front detection eliminates that mode.
  - **Why not a sixth predicate**: spec pins five predicates scoped to the volume holding `pocketdb/` (FR-013, EC-011). Plan-out target may live elsewhere. Adding a sixth would expand the spec-frozen surface; using exit code 1 keeps codes 2–6 reserved for spec-pinned predicate refusals.
  - **Why not at plan-write time**: this is the failure mode operators dislike most; the cost of an up-front probe is one tiny file create + unlink, which is trivial against a 5-minute hashing budget.
  - **US-002 acceptance scenario 7 still holds**: the writability probe runs after pre-flight, so on pre-flight refusal the writability probe never fires. On predicate-pass + writability-fail, the doctor has not read any pocketdb byte yet (writability probe runs before hash phase).
- **Alternatives considered**:
  - **Sixth pre-flight predicate at code 8 or new code in 2..7 range**: rejected for spec-surface expansion.
  - **At plan-write time only**: rejected for operator UX.
  - **Both up-front and at plan-write time**: rejected as redundant; up-front sufficient since intervening hash work doesn't require write access to plan-out.

## Decision: `change_counter` mechanism (D7) — direct file-header byte parsing

- **Decision**: read first 100 bytes of `pocketdb/main.sqlite3` with `O_RDONLY`; validate magic bytes `"SQLite format 3\0"` at offset 0; read 4-byte big-endian unsigned integer at offset 24 as `change_counter`.
- **Rationale**:
  - **Chunking-doc preferred**: spec pins "where possible via direct file-header parsing without invoking the engine."
  - **Stable file format**: SQLite file format ([sqlite.org/fileformat.html](https://www.sqlite.org/fileformat.html)) is a public, stable spec. Header layout has not changed across SQLite 3.x. Offset 24, 4 bytes BE, "File change counter" — verbatim from the spec.
  - **Side-effect-free**: a 100-byte `O_RDONLY` read leaves no journal, WAL, or lock state. Engine-open could trigger WAL recovery on a crash-recovered file, which would be a write — violates FR-005's "diagnose performs zero writes."
  - **Failure modes**: file shorter than 100 bytes / missing magic / unreadable → predicate cannot evaluate `change_counter`; doctor returns generic exit code 1 with diagnostic. Not the ahead-of-canonical refusal.
- **Alternatives considered**:
  - **Engine-open via `modernc.org/sqlite`**: rejected for the side-effect risk above and for the spec's explicit preference.
  - **`sqlite3` CLI subprocess**: rejected as a runtime dependency the operator must install.

## Decision: Running-node mechanism (D8) — advisory-lock probe + process-table scan

- **Decision**: two-step combination check evaluated in order; either trip refuses with running-node code 2.
  1. Advisory-lock probe on `pocketdb/main.sqlite3` (non-blocking exclusive lock attempt + immediate release).
  2. Process-table scan for `pocketnet-core` / `pocketnetd` holding any open file descriptor under `pocketdb/`.
- **Rationale**:
  - **Spec line 124**: "Doctor MUST refuse to run if a `pocketnet-core` process is currently using `pocketdb/` (lockfile or process check); EC-004 — a non-`pocketnet-core` OS-level lock on `main.sqlite3` — is handled under this same predicate." The advisory-lock probe satisfies EC-004 by not distinguishing lock owners.
  - **Why both checks**: the lock probe alone may miss a pocketnet-core that uses non-locking access patterns (rare but possible). The process scan is defense-in-depth. Spec wording "lockfile or process check" admits the conjunction.
  - **Cross-platform**: `flock` on POSIX, `LockFileEx` on Windows; `gopsutil/v3/process` is pure-Go and supports all three target platforms.
  - **`gopsutil` dependency**: pure-Go, BSD-3-Clause; "no runtime dependencies" in pre-spec context applies to libs the operator must install at runtime, not Go-vendored libs baked into the static binary. Test confirms `go build` produces a single static binary with `gopsutil` linked in.
- **Alternatives considered**:
  - **Lock probe only**: rejected for missed-detection risk under non-locking access patterns.
  - **Process scan only**: rejected for EC-004 (a non-`pocketnet-core` OS-level lock would not match the process scan).
  - **Lockfile inspection (`pocketdb/.lock`)**: there is no documented pocketnet-core lockfile contract; rejected as a brittle assumption.

## Decision: Diagnose summary grammar (D9) — fixed plain-text template

- **Decision**: fixed template per [plan.md § D9](plan.md). Plain-text on stderr. IEC binary units. ETA = `total_bytes / 50 MiB/s`.
- **Rationale**:
  - **Operator-readable**: structured machine output is `plan.json`; the summary is for humans.
  - **Fixed template, not free-form**: predictable layout for screenshot-and-paste-into-issue-tracker workflows.
  - **ETA constant 50 MiB/s**: typical residential downlink rates are ~50–500 Mbps (≈ 6–60 MiB/s). The lower bracket gives a deliberately-conservative ETA so the operator's wait isn't undershot. Tunable in chunk 005 troubleshooting guide once observed apply throughput is available.
  - **IEC binary units**: GB ambiguity (decimal vs binary) costs operator-trust in incident-triage contexts. KiB / MiB / GiB / TiB is unambiguous.
- **Alternatives considered**:
  - **Free-form prose**: rejected for predictability.
  - **JSON to stdout**: rejected per spec Q3/A3 (stdout unused in v1).
  - **YAML / TOML**: rejected as adding parse surface for no doctor-side benefit.

## Decision: Progress message cadence (D10) — 5% / 25-file milestones

- **Decision**: per [plan.md § D10](plan.md). 5% of total pages within `main.sqlite3`; 25 files within each non-SQLite class.
- **Rationale**:
  - **Bounded total volume**: 5% on 38M pages → 20 milestones. 25 files on ~2000 `blocks/*.dat` → ~80 milestones. Plus class-entry/exit lines ≈ 110 milestone lines per run. Operator-readable, not a noise wall.
  - **Liveness on long runs**: a 5-minute diagnose with no stderr output for 4 minutes is alarming. 5% cadence gives ~20 lines over the page-hashing phase, ~one every 5–15 seconds — clearly alive.
  - **Cadence numbers are tunable**: research.md explicitly notes them as v1 starting points, revisited in chunk 004 / 005 against real-world feedback.

## Decision: Trust-root constant compilation (D11) — ldflags-overridable default constant

- **Decision**: `internal/trustroot.PinnedHash` is a `var` initialized to the v1 development trust-root (`a939828d…`). Build-time injection via `-ldflags -X internal/trustroot.PinnedHash=<hex>` re-pins it without source change.
- **Rationale**:
  - **Pre-spec line 154**: "Trust-root constant value is published and pinned in build configuration." `ldflags` is the Go-idiomatic build-config knob.
  - **Default-fallback**: vanilla `go build` produces a working dev binary; CI / tests work without injection.
  - **One-Time Setup re-pin event**: chunk 005 release flips ldflags to the live canonical's trust-root via a one-line build-script edit.
- **Alternatives considered**:
  - **Source-code constant only**: rejected — re-pin requires a source change, which is a heavier event than the One-Time Setup Checklist suggests.
  - **External file read at startup**: rejected — pre-spec pins "trust-root compiled in" (chunking-doc Speckit Stop "no user-config file in v1; trust-root is compiled in").
  - **PKI signature verification**: rejected — pre-spec Out-of-Scope explicitly excludes PKI in v1.

## Decision: Hash utility streaming model (D14) — Go 1.23+ iterator

- **Decision**: `internal/hashutil.HashSQLitePages` returns `iter.Seq2[PageHash, error]` (Go 1.23+ range-over-func iterator).
- **Rationale**:
  - **Backpressure**: iterator yields one `(offset, hash)` per page; the consumer (diagnose orchestrator) can pause / abort mid-iteration. Useful for a future feature where diagnose stops at first divergence (not v1, but the API doesn't preclude it).
  - **Memory boundedness**: even on a 600 GB `main.sqlite3` (hypothetical), the page-hash array would be 38 GB if loaded into memory all at once (32-byte hash × ~1.2B pages). Streaming keeps memory bounded.
  - **Go 1.23+ requirement**: pinning Go 1.23 or later in `go.mod` is the only constraint; 1.23 is GA as of Aug 2024 (well before this chunk's implementation date).
- **Alternatives considered**:
  - **Channel-based streaming**: rejected — heavier than iterator, requires explicit cancellation contract.
  - **Slice-return**: rejected for memory boundedness reason above.
  - **Callback-based**: rejected — iterators are the modern idiomatic Go choice for this pattern.

## Decision: Test-fixture strategy (D18) — small + reference-rig flavors

- **Decision**: `testdata/small/` for dev-laptop tests; `testdata/reference/` build-tag-gated for SC-001 / SC-002 timing on the reference rig.
- **Rationale**:
  - **CI velocity**: `go test ./...` against `testdata/small/` runs in seconds.
  - **Reference-rig timing claim**: SC-001 / SC-002 explicitly bound to the named reference rig (8 vCPU x86_64, NVMe-class disk, 16 GB RAM). Running the timing test on a dev laptop produces misleading data.
  - **Build-tag gating**: `//go:build reference_rig` ensures the reference fixture is never accidentally exercised by `go test ./...`; only `go test -tags reference_rig` opts in.
  - **Generator script over committed fixture**: a multi-GB fixture in git would bloat clones; the generator (`tests/integration/gen-reference-fixture.sh`) builds the fixture from a source canonical on first reference-rig run.

## Inheritance hand-off to Chunk 003

The following Chunk 002 decisions inherit unchanged into Chunk 003 per chunking-doc Speckit Stops:

- Go module path and project layout (D1).
- SQLite binding: `modernc.org/sqlite` (D2).
- HTTP client: stdlib `net/http` with chunk-003-tunable parallel-fetch overlay (Chunk 003 adds `Accept-Encoding: zstd, gzip`).
- Plan-format library (D12) — Chunk 003's apply consumes plans without modification.
- Manifest verifier (D13) — Chunk 003's EC-005 superseded-canonical detection re-fetches the manifest using this verifier (chunking-doc Speckit Stop).
- Hash utilities (D14) — Chunk 003's pre-rename per-chunk hash verification reuses streaming SHA-256.
- Canonical-form serializer (`internal/canonform`) — Chunk 003's plan-tamper detection (EC-009) re-uses self-hash-via-canonform path.
- Trust-root constant pin (D11) — Chunk 003 builds against the same constant Chunk 002 was tested against.
- Exit-code allocation (D15) — Chunk 003 owns codes 10–19 reserved here.
