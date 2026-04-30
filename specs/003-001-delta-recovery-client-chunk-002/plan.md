# Implementation Plan: Client Foundation + Diagnose (Chunk 002)

**Branch**: `003-001-delta-recovery-client-chunk-002` | **Date**: 2026-04-30 | **Spec**: [spec.md](spec.md)

## Summary

Chunk 002 produces the doctor binary's **read-only pathway** plus the foundational scaffolding both phases share: project skeleton, plan-format library (canonical-form-hashed JSON serializer), manifest verifier (trust-root pinned-hash compare), hash utilities (SHA-256 over 4 KB SQLite pages and whole files), diagnose phase (US-001), five pre-flight refusal predicates (US-002 — running-node, version-mismatch, volume-capacity, permission/read-only, ahead-of-canonical), and trust-root authentication including the FR-018 forward-compatibility surface (US-003 — `format_version` refusal, parsed-but-ignored `trust_anchors`).

The chunk inherits Chunk 001's frozen manifest schema and the v1 development trust-root constant (`a939828d…`) compiled into Chunk 002 + Chunk 003 development builds. It declares the `plan.json` shape that Chunk 003's apply consumes without modification.

## Technical Context

**Language/Version**: Go (specific minor version pinned at task-stage from current stable). Single static binary across Linux, macOS, Windows; no runtime dependencies. (Inherits pre-spec Implementation Context.)
**Primary Dependencies**: standard library `net/http` (chunking-doc Speckit Stop), standard library `flag` (CLI parsing — see D4), `modernc.org/sqlite` (Go SQLite binding — see D2; CGO-free pure-Go transpiled SQLite).
**Storage**: filesystem only. Doctor reads `pocketdb/` (read-only this chunk), writes `plan.json` to the operator-resolved `--plan-out` path. No databases, no caches.
**Testing**: standard library `testing`. No third-party test framework. Contract tests under `tests/contract/`, integration tests under `tests/integration/`, unit tests alongside production code (`*_test.go` per Go convention).
**Target Platform**: Linux, macOS, Windows. Reference rig for SC-001 timing: 8 vCPU x86_64, NVMe-class disk, 16 GB RAM (pre-spec Implementation Context).
**Project Type**: CLI tool — single binary `pocketnet-node-doctor` with subcommands `diagnose` (this chunk) and `apply` (reserved namespace; Chunk 003 implements).
**Performance Goals**: SC-001 — diagnose against a 30-day-divergent fixture pocketdb completes within 5 minutes end-to-end on the reference rig. SC-002 — diagnose against a node identical to canonical emits a zero-entry plan within 5 minutes (same boundary).
**Constraints**: Diagnose performs zero writes to `pocketdb/` (FR-005, observably read-only). Pre-flight predicates run before any pocketdb byte is read (chunking-doc behavioral criterion). Trust-root mismatch refuses without any chunk-store byte fetch (EC-008). Stdout unused by diagnose in v1 (spec Q3/A3); all human-readable output on stderr.
**Scale/Scope**: ~38M page hashes for a single canonical's `main.sqlite3` (per pre-spec empirical baseline); thousands of `blocks/*.dat` whole-file hashes; emitted plan typically lists 14% of pages (per the empirical baseline 85.83% reuse) plus a smaller set of full-file divergences.

## Constitution Check

The repo's `.specify/memory/constitution.md` is the unfilled SpecKit template (placeholders only — no ratified principles). There are no concrete gates to evaluate. This is consistent with the pre-implementation, pre-spec posture in [CLAUDE.md](../../CLAUDE.md): the project's behavioral constraints live in the pre-spec and the chunking doc, both of which are honored throughout this plan.

**Result**: PASS (vacuous — no constitution principles to violate). Re-check after Phase 1: still PASS.

## Project Structure

### Documentation (this feature)

```text
specs/003-001-delta-recovery-client-chunk-002/
├── spec.md                         # /speckit.specify + /speckit.clarify output (existing)
├── plan.md                         # this file
├── research.md                     # Phase 0 output
├── data-model.md                   # Phase 1 output (Plan, Manifest-as-consumed, Refusal-Predicate, Trust-Root)
├── quickstart.md                   # Phase 1 output (operator-facing diagnose recipe)
└── contracts/
    ├── plan.schema.json            # JSON Schema (Draft 2020-12) for plan.json — Chunk 003 consumer contract
    └── cli-surface.md              # diagnose subcommand contract: flags, exit codes, stderr/stdout, predicate ordering, diagnostics
```

### Source Code (repository root)

This chunk is the first to introduce in-repo source. Layout:

```text
cmd/
└── pocketnet-node-doctor/
    └── main.go                     # binary entry point: subcommand dispatch, exit-code mapping

internal/
├── cli/                            # CLI parsing (flag.NewFlagSet per subcommand; --help, --version)
├── diagnose/                       # orchestrator: pre-flight → manifest fetch+verify → hash → emit plan
├── preflight/                      # five refusal predicates + linear ordering evaluator
├── manifest/                       # fetch (net/http), verify (trust-root compare), parse (typed structs)
├── plan/                           # Plan struct + canonical-form marshal + self-hash compute/verify
├── canonform/                      # canonical-form JSON serializer (sorted keys, no insig. whitespace, UTF-8) — shared by plan + manifest verifier
├── hashutil/                       # streaming SHA-256: per-4KB-page (sqlite_pages), whole-file (whole_file)
├── exitcode/                       # typed exit-code sentinel constants (0..7 per chunking-doc allocation)
├── stderrlog/                      # stderr writer with --verbose gate; info-default, debug-on-verbose
├── trustroot/                      # compiled-in trust-root constant (build-tag/ldflags overridable at chunk 005)
└── buildinfo/                      # ldflags-injected version / git SHA for --version output

tests/
├── contract/                       # consumes Chunk 001's contracts/manifest.schema.json + plan.schema.json
└── integration/                    # end-to-end diagnose against fixture rigs (US-001/US-002/US-003 acceptance tests)

testdata/
├── small/                          # small synthetic pocketdb fixtures (dev-laptop scale; deterministic)
└── reference/                      # reference-rig-scale fixture (gated by build tag / env var; SC-001 timing)
```

**Structure Decision**: idiomatic Go layout — `cmd/<binary>/` for the entry point, `internal/` for non-exported library packages (Go-toolchain-enforced unexported), `tests/` for cross-package contract + integration tests. `testdata/` is the Go-convention name for fixture data. No `pkg/` exported tree: the doctor is an end-user binary, not a library — every package this chunk produces is `internal/`.

## Plan-Stage Decisions

Each decision below is resolved per the runner's order: pre-declared default (chunking doc § Plan-Stage Decisions Across All Chunks is empty for this chunk) → precedent from chunk 001 → pre-spec / chunking-doc constraint → narrower / more-testable / more-conservative.

### D1. Go module path and project layout

- **Option chosen**: module path `github.com/pocketnet-team/pocketnet-node-doctor` (placeholder host/org pending operational decision; the import path is the contract surface, not the publication target). Idiomatic layout: `cmd/pocketnet-node-doctor/` for the binary, `internal/` for all library packages, `tests/` for cross-package tests, `testdata/` for fixtures. No `pkg/` tree.
- **Rationale**: pre-spec pins "single static binary"; chunking doc pins "single binding inherits" — `internal/` enforces the no-public-library posture at toolchain level. `cmd/<binary>/` matches the Go-community standard for single-binary tools.

### D2. Go SQLite binding selection

- **Option chosen**: `modernc.org/sqlite` (pure-Go, CGO-free SQLite transpiled from C source).
- **Rationale**: pre-spec Implementation Context pins "single static binary across Linux, macOS, and Windows with no runtime dependencies." `mattn/go-sqlite3` requires CGO, which complicates static cross-platform builds (each target needs a C toolchain) and produces dynamically-linked binaries unless caller takes care. `modernc.org/sqlite` produces a true static binary from `go build` alone, supports all three target platforms, and is API-compatible with `database/sql`. Inherits unchanged to Chunk 003 for `PRAGMA integrity_check` per chunking-doc's "single binding" pin.
- **Scope this chunk**: dependency declared in `go.mod`; not invoked at runtime by this chunk's pre-flight (D8 below uses direct file-header parsing instead). The binding is on-disk for Chunk 003 to consume.

### D3. CLI parsing library

- **Option chosen**: standard library `flag` package, one `flag.FlagSet` per subcommand (`diagnose`, `apply`).
- **Rationale**: pre-spec Implementation Context pins "no runtime dependencies"; chunking-doc Speckit Stop pins HTTP client to stdlib `net/http` — same posture inherits. `flag` supports the spec-pinned subcommand structure (`diagnose`, `apply`) via per-subcommand FlagSets. Cobra/urfave-cli would add a heavyweight dep for a small CLI surface. Narrower / more-conservative.

### D4. CLI flag grammar (resolves spec plan-layer deferral on flag names beyond the spec-pinned set)

- **Option chosen**: long-form-only flags in v1; no short forms; no env-var overrides.
  - `pocketnet-node-doctor diagnose --canonical <url> --pocketdb <path> [--plan-out <path>] [--verbose]`
  - `pocketnet-node-doctor apply ...` (Chunk 003)
  - Global: `--help` (per-subcommand and top-level), `--version`.
- **Rationale**: chunking-doc Speckit Stop pins "behavior controlled by CLI flags only" + "no user-config file in v1." Long-form-only is the narrower choice that reserves short-form namespace and env-var namespace for future use without committing v1 to either. `--help` is auto-generated by `flag` plus a small subcommand dispatcher; `--version` reads from `internal/buildinfo` (D11).

### D5. Default `--plan-out` location (concretization of spec's "alongside the operator's pocketdb-parent directory")

- **Option chosen**: when `--plan-out` is unset, default = `<dirname of resolved --pocketdb>/plan.json`. Concrete: if `--pocketdb /var/lib/pocketnet/pocketdb` then default `--plan-out` = `/var/lib/pocketnet/plan.json`.
- **Rationale**: spec's "alongside the pocketdb-parent directory" admits two readings (sibling-of-pocketdb vs. inside-pocketdb-parent); the chosen option avoids writing inside `pocketdb/` (which would conflict with FR-005's "diagnose performs zero writes to `pocketdb/`"). Sibling placement is the read-only safe interpretation. Operator can always override with explicit `--plan-out`.

### D6. `--plan-out` writability verification timing (resolves spec D6 — Q4/A4 deferral)

- **Option chosen**: **up-front non-predicate writability probe**. After all five spec-pinned pre-flight predicates pass, before any pocketdb byte is read for hashing, the doctor probes the resolved `--plan-out` directory by creating a small temporary file (`<plan-out-dir>/.pocketnet-node-doctor-writeprobe-<rand>`), writing one byte, fsyncing, and unlinking. On failure (permission denied, ENOSPC, read-only, missing parent directory) the doctor refuses with **exit code 1 (generic error)** and a diagnostic naming the unwritable plan-out target.
- **Rationale**:
  - Operator-friendliness: wasting up to 5 minutes of diagnose work on an unwritable plan-out target is the failure mode operators least want to debug.
  - **Not added as a sixth predicate**: the spec pins five pre-flight predicates scoped to the volume holding `pocketdb/` (FR-013, EC-011); plan-out target may live on a different volume. Adding a sixth predicate would expand the spec-frozen surface; mapping to generic exit code 1 keeps codes 2–6 reserved for the spec-pinned predicate refusals.
  - Narrower than "skip up-front, fail at write time": still pre-pocketdb-read so US-002 acceptance scenario 7 ("no byte under `pocketdb/` has been read") holds; but more-conservative-for-the-operator than late-stage failure.

### D7. `change_counter` ahead-of-canonical mechanism (resolves spec plan-layer deferral)

- **Option chosen**: **direct SQLite file-header byte parsing** (no SQLite engine invocation in this chunk's pre-flight). Read the first 100 bytes of `pocketdb/main.sqlite3`, validate the magic header `"SQLite format 3\0"` at offset 0, read `change_counter` as a 4-byte big-endian unsigned integer at offset 24 per the SQLite file-format spec.
- **Rationale**: spec pins "where possible via direct file-header parsing without invoking the engine"; the SQLite file-format spec is public, stable, and the header layout has not changed across SQLite 3.x. Direct parsing keeps the pre-flight observably read-only (`O_RDONLY` open, 100-byte read, close) and avoids any engine-level side effects (WAL recovery, journal touching). The `modernc.org/sqlite` binding (D2) is reserved for chunk 003's post-apply `integrity_check` per the chunking-doc inheritance pin.
- **Failure modes**: file shorter than 100 bytes, missing magic header, or unreadable → predicate fails open (cannot evaluate `change_counter`); doctor returns generic exit code 1 with a diagnostic naming the malformed-header condition. Not the ahead-of-canonical refusal (code 3) — that fires only on a successful header parse where `local_change_counter > canonical_change_counter`.

### D8. Running-node predicate mechanism (resolves spec plan-layer deferral on FR-010)

- **Option chosen**: **two-step combination check** evaluated in order; either trip refuses with running-node code 2.
  1. **Advisory-lock probe** on `pocketdb/main.sqlite3`: attempt a non-blocking exclusive advisory lock (`flock(LOCK_EX | LOCK_NB)` on Linux/macOS via `golang.org/x/sys/unix`; `LockFileEx` with `LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY` on Windows via `golang.org/x/sys/windows`); release immediately on success. Lock-acquisition failure → predicate trips. **This single check satisfies pre-spec EC-004** (a non-`pocketnet-core` OS-level lock is treated as the running-node refusal case) — no lock-owner identification needed.
  2. **Process-table scan** for `pocketnet-core` (and known aliases: `pocketnetd`) holding any open file descriptor under the resolved `pocketdb/` directory tree. Best-effort defense-in-depth: catches the rare case where pocketnet-core is running but uses a non-blocking access pattern (no advisory lock held at probe time). Implemented via `gopsutil/v3/process` (read-only system enumeration; pure-Go, no CGO).
- **Rationale**:
  - Spec pins "lockfile or process check"; pre-spec EC-004 requires foreign locks treated as running-node refusal. The advisory-lock probe is the cheapest check that satisfies both: it doesn't distinguish lock owners (matches EC-004 exactly).
  - Two-step ordering matches the chunking-doc's "cheapest checks fire first" principle within the predicate itself.
  - **Dependency**: `gopsutil/v3` is permissive-licensed, pure-Go, widely used in Go observability tools; tolerable given pre-spec's "no runtime dependencies" applies to runtime libs the operator must install — Go-vendored libraries baked into the static binary do not violate that pin.

### D9. Diagnose human-readable summary grammar (resolves spec plan-layer deferral on FR-004)

- **Option chosen**: plain-text on stderr, fixed-template format. Example:
  ```
  pocketnet-node-doctor diagnose summary
    canonical block height: 3806626
    divergent files: 3 (12.4 GiB total)
    by class:
      main.sqlite3 pages: 5,432,109 of 38,290,432 (14.18%; 20.7 GiB)
      blocks/      :    142 of 2,104 files (    8.3 GiB)
      chainstate/  :      8 of    23 files (   42.1 MiB)
      indexes/     :      0 of     7 files (    0 B)
      other        :      0 of     0 files (    0 B)
    plan written to: /var/lib/pocketnet/plan.json
    estimated apply ETA: ~14 minutes (assuming 50 MiB/s sustained download)
  ```
  Bytes rendered as IEC binary units (KiB / MiB / GiB / TiB). ETA = `total_bytes_to_fetch ÷ 50 MiB/s` (placeholder constant; tunable in chunk 005 troubleshooting guide).
- **Rationale**: spec FR-004 pins fields (total entries, total bytes-to-fetch, breakdown by artifact class, ETA estimate); the rendered text format is plan-layer. Fixed template prioritizes operator-readability over machine-parseability (machine-parseable output is `plan.json`, not the summary). ETA placeholder constant of 50 MiB/s matches typical residential downlink assumptions and is documented as a v1 placeholder in research.md.

### D10. Diagnose progress-message grammar (resolves spec plan-layer deferral)

- **Option chosen**: plain-text on stderr, one line per milestone. Templates:
  - At entry to each file class: `[diagnose] hashing <class>...`
  - Within `main.sqlite3`: every 5% of total pages: `[diagnose] hashing main.sqlite3 pages: <N> / <total> (<pct>%)`
  - Within `blocks/`, `chainstate/`, `indexes/`: every 25 files: `[diagnose] hashing <class>: <N> / <total> files`
  - At exit from each file class: `[diagnose] hashed <class> in <elapsed>` (elapsed in seconds with one decimal).
- **Rationale**: chunking-doc pins "human-readable, at file-class boundaries"; spec pins "progress messages on stderr at file-class boundaries (e.g., `main.sqlite3` page-hashing milestones, `blocks/` file-by-file)." 5% / 25-file cadence keeps total stderr volume bounded (≤ ~80 lines for a typical run) so operators can read it. `--verbose` adds debug lines (one per individual divergence) for troubleshooting; default mode emits only the milestone lines.

### D11. Trust-root constant compilation mechanism

- **Option chosen**: build-time injection via `-ldflags -X internal/trustroot.PinnedHash=<hex>`, with a default constant in `internal/trustroot/trustroot.go` set to the v1 development trust-root (`a939828d349bc5259d2c79fe9251d4e3497d2d1518c944dfc91ae9594f029249`) so a vanilla `go build` produces a working development binary. At chunk 005 release, ldflags inject the live `delt.3`-published canonical's trust-root.
- **Rationale**:
  - Pre-spec line 154 pins "build configuration" as the location for the trust-root pin — ldflags is the Go-idiomatic build-config knob.
  - Default-constant fallback means tests, dev builds, and CI runs work without ldflags arguments.
  - One-Time Setup Checklist re-pin at chunk 005 is a one-line build-system change (Makefile or release script edit) — no source-code change.

### D12. Plan-format library structure and JSON schema for `plan.json`

- **Option chosen**: `internal/plan` package exposes `Marshal(p Plan) ([]byte, error)`, `Unmarshal(b []byte) (Plan, error)`, `ComputeSelfHash(p Plan) (string, error)`, `VerifySelfHash(p Plan) error`. Marshal produces canonical-form bytes via `internal/canonform` (shared with `internal/manifest`). Plan JSON schema is published as `contracts/plan.schema.json` (JSON Schema Draft 2020-12, matching chunk-001 precedent). Top-level shape per pre-spec Implementation Context plan-artifact (already pinned):
  - `format_version` (integer; `1`)
  - `canonical_identity` (object: `block_height`, `manifest_hash`, `pocketnet_core_version`)
  - `divergences` (array of `{path, offset?, length?, expected_hash}`)
  - `self_hash` (64-char lowercase hex; SHA-256 over canonical-form payload with `self_hash` removed)
- **Rationale**: pre-spec Implementation Context pins the four top-level fields and the canonical-form-with-`self_hash`-removed self-hash construction; chunk-001 precedent (D11/D12 in chunk-001 plan.md) sets JSON Schema Draft 2020-12 as the schema-document format. Publishing `plan.schema.json` makes the plan a first-class consumer contract for Chunk 003. `internal/canonform` shared between plan-marshal and manifest-trust-root-input addresses CSA-11-F07 ("both Chunk 001 manifest and Chunk 002 plan-format inherit a single source").

### D13. Manifest ingestion and runtime validation posture

- **Option chosen**: parse manifest JSON via stdlib `encoding/json` into typed Go structs that mirror Chunk 001's frozen schema. Validation chain:
  1. Fetch manifest bytes via `net/http` (timeout 30 s; default redirect policy).
  2. Compute SHA-256 over canonical-form-re-serialized bytes via `internal/canonform`.
  3. Compare to compiled-in `internal/trustroot.PinnedHash`. **Mismatch → refuse with EC-008 diagnostic; no chunk-store byte fetch ever attempted.**
  4. Parse trust-verified bytes into typed struct. Unmarshal failure → generic exit code 1 (a trust-verified manifest that fails to unmarshal indicates a publisher bug, not an attack).
  5. Check `format_version`; if not `1`, refuse with code 7 (CSC002-002 surface).
  6. Parse `trust_anchors` block presence (required field per FR-018); contents are not inspected.
- **Rationale**: trust-root compare is the load-bearing integrity check. Running a JSON-Schema validator at runtime would add a dependency for a check the trust-root already covers (a publisher-bug-shipped malformed manifest is a publisher problem, not a doctor problem). Narrower / no-runtime-deps. Schema validation is a publisher-side contract test (chunk 001 owns it).

### D14. Hash-utilities streaming model

- **Option chosen**: `internal/hashutil` exposes `HashWholeFile(path string) (sha256hex string, err error)` and `HashSQLitePages(path string, pageSize int) (iter.Seq2[PageHash, error], err error)` (Go 1.23+ iterator pattern). Both use a fixed 1 MiB buffer and `crypto/sha256`'s streaming `New()` interface; whole-file hashing single-passes to a hash sink, page-hashing reads exactly `pageSize` bytes per iteration and emits a `{offset, hash}` per page.
- **Rationale**: streaming avoids loading multi-GB `blocks/*.dat` files into memory. 1 MiB buffer is the conventional Go I/O buffer size; matches typical NVMe sector-aligned I/O. Iterator (Go 1.23+) makes per-page hash emission resumable and testable without loading the full page array. PageSize parameterized: spec pins 4096 for `main.sqlite3`; the parameter is plan-stage-flexible so tests can use smaller pages on synthetic fixtures without recompilation.

### D15. Pre-flight predicate ordering and exit-code mapping

- **Option chosen**: `internal/preflight` exposes `Evaluate(ctx) (PredicateResult, error)`. The five predicates run in the chunking-doc-pinned order: running-node → version-mismatch → volume-capacity → permission/read-only → ahead-of-canonical. **Stop-at-first-refusal** per spec Q2/A2: only the first refusing predicate's exit code and diagnostic are emitted; subsequent predicates are not evaluated. Each predicate is a `func(ctx PreflightContext) PredicateResult` returning either `Pass` or `Refuse{Code, Diagnostic}`. Exit codes per `internal/exitcode` constants matching the chunking-doc allocation: 2 running-node, 3 ahead-of-canonical, 4 version-mismatch, 5 capacity, 6 permission/read-only, 7 manifest-format-version-unrecognized.
- **Rationale**: spec/chunking-doc pin both ordering and stop-at-first semantics. Linear evaluator with hardcoded order matches the contract literally. Code 7 is allocated to manifest-format-version-unrecognized per chunking-doc; it fires inside `internal/manifest` not `internal/preflight`, so the manifest verifier returns a typed error that the diagnose orchestrator maps to code 7. Both refusal surfaces share the same exit-code-mapping infrastructure in `internal/exitcode`.

### D16. Logging surface implementation

- **Option chosen**: `internal/stderrlog` package wraps `os.Stderr` with two write methods: `Info(format, args...)` (default-on) and `Debug(format, args...)` (gated by `--verbose`). No structured logging in v1 (chunking-doc Speckit Stop). Stdout is unused by diagnose in v1 (spec Q3/A3); the diagnose orchestrator writes nothing to `os.Stdout`. The `plan.json` artifact is written to the file at the resolved `--plan-out` path (not stdout).
- **Rationale**: chunking-doc Speckit Stop pins "plain-text to stderr at info level by default; `--verbose` flag enables debug." Two-method surface is the minimal API matching that pin. Reserving stdout (no writes) preserves the v1 "stdout is unused" contract from spec Q3/A3 — a future v2 may emit structured machine output to stdout without breaking v1 consumers.

### D17. HTTP client policies for manifest fetch

- **Option chosen**: `net/http.Client` with per-request timeout 30 s for manifest GET; `http.Client.CheckRedirect` left at default (follow up to 10); TLS config left at default (system CA trust); custom `User-Agent: pocketnet-node-doctor/<version> (chunk-002)` set via custom transport.
- **Rationale**: manifest is small (KB-scale); 30 s is generous for high-latency networks without enabling indefinite hangs. Default redirect / TLS posture matches chunking-doc Speckit Stop "no bespoke HTTP framework." Custom User-Agent helps publisher-side observability without leaking operator-identifying info. Connection re-use, parallel-fetch tuning, and `Accept-Encoding: zstd, gzip` are Chunk 003 concerns (this chunk fetches one manifest, single GET).

### D18. Test-rig fixture strategy

- **Option chosen**: two fixture flavors under `testdata/`:
  - `testdata/small/` — synthetic minimal pocketdb (a few MB `main.sqlite3` of fewer pages, a handful of `blocks/*.dat` files in the KB-MB range). Used for unit + contract + integration tests on dev laptops; exercises every code path with deterministic inputs.
  - `testdata/reference/` — reference-rig-scale fixture (≥30-day-divergent, multi-GB). Gated behind build tag `//go:build reference_rig` and env var `POCKETNET_DOCTOR_REFERENCE_RIG=1`. Used to verify SC-001 and SC-002 timing on the reference rig.
  Reference-rig fixture generator script lives under `tests/integration/` so the rig can rebuild fixtures from a source canonical without committing multi-GB binaries.
- **Rationale**: dev-loop velocity matters; small fixtures keep `go test` fast on laptops. SC-001 / SC-002 timing claims require the named reference rig; gating prevents accidental laptop runs from producing misleading timing data. Generator-script-not-committed-binary keeps the repo size tractable.

## Non-goals

- **No apply-side code in this chunk.** Apply (FR-006..009), verification (FR-014..016), network resilience (FR-019..020), and apply-time exit codes (10..19) are owned by Chunk 003. The exit-code allocation reserves codes 10–19 here so Chunk 003 can claim them without re-negotiating the surface.
- **No drill rig.** US-005 / SC-005 (end-to-end recovery drill) is owned by Chunk 004; this chunk does not validate against the project-internal test node.
- **No range-request HTTP fetch.** Chunk 003 will implement parallel chunk fetches with `Accept-Encoding: zstd, gzip`; this chunk performs one manifest GET.
- **No structured logging or stdout output.** The chunking-doc Speckit Stop pins plain-text stderr, and spec Q3/A3 pins stdout-unused. v1 stays inside that pin.
- **No JSON-Schema runtime validation in the doctor.** Schema validity is a publisher-side contract (Chunk 001 owns it via `tests/contract/`); the trust-root pinned-hash compare is the doctor-side integrity gate. Adding a runtime validator would add a dependency for a redundant check.
- **No retry / backoff for the manifest GET in this chunk.** Network resilience primitives (FR-019, FR-020) are owned by Chunk 003. A single manifest GET that fails returns generic exit code 1; the operator re-runs.
- **No CLI short-form flags or environment-variable overrides.** Long-form flags only in v1; namespace reserved for future use.
- **No public `pkg/` tree.** All packages are `internal/`; the doctor is an end-user binary, not a Go library.

## Artifacts Created

- `specs/003-001-delta-recovery-client-chunk-002/plan.md` (this file)
- `specs/003-001-delta-recovery-client-chunk-002/research.md`
- `specs/003-001-delta-recovery-client-chunk-002/data-model.md`
- `specs/003-001-delta-recovery-client-chunk-002/quickstart.md`
- `specs/003-001-delta-recovery-client-chunk-002/contracts/plan.schema.json`
- `specs/003-001-delta-recovery-client-chunk-002/contracts/cli-surface.md`

## Artifacts Updated

- `CLAUDE.md` (root) — touched by `.specify/scripts/bash/update-agent-context.sh claude` if Go is added as a new known technology. This chunk introduces the Go language pin into the agent context for the first time.

## Phase Outputs Reference

- **Phase 0 (research.md)**: consolidates rationales for D1–D18, with primary focus on the spec's plan-layer deferrals (D2 SQLite binding, D4 CLI grammar, D6 plan-out timing, D7 change_counter mechanism, D8 running-node mechanism, D9 summary grammar, D10 progress grammar). No NEEDS CLARIFICATION items were carried into this phase: the spec's Clarifications session 2026-04-30 (Q1–Q5) closed Q1, Q2, Q3, Q5 inside the spec and deferred Q4 to plan-stage (D6 here).
- **Phase 1 (data-model.md, contracts/, quickstart.md)**: pins the Plan / Manifest-as-consumed / Refusal-Predicate / Trust-Root entity model, publishes the JSON Schema for `plan.json` (Chunk 003 consumer contract), publishes the CLI surface contract (operator-facing), and provides an operator-facing diagnose recipe (build → run → verify).

## Re-evaluation After Phase 1

- **Constitution**: still PASS (still vacuous — no principles ratified).
- **Spec Clarifications**: Q1, Q2, Q3, Q5 closed in the spec itself; Q4 (the `--plan-out` writability timing) resolved by D6 above.
- **Plan-layer deferrals from spec**: all seven resolved (D2, D4 covers two, D6, D7, D8, D9, D10).
- **Inheritance to Chunk 003**: HTTP client (`net/http`), SQLite binding (`modernc.org/sqlite`), exit-code allocation (codes 10–19 reserved), plan-format library, manifest verifier, hash utilities, canonical-form serializer (`internal/canonform`), trust-root constant pin mechanism (ldflags-overridable). Chunk 003 inherits the same Go module path and project layout.

## Known Coverage Gaps

- **SC-001 timing-half on reference rig** — the timing claim is verified only when the reference-rig-gated test fixture is exercised on the reference rig (8 vCPU x86_64 / NVMe / 16 GB). Dev-laptop runs against `testdata/small/` cannot validate the 5-minute budget against a 30-day-divergent fixture. The integration test for SC-001 is build-tag-gated; running it on the reference rig is a chunk 002 acceptance gate, not a CI gate.
- **D11 trust-root re-pin at chunk 005** — this chunk hardcodes the v1 development trust-root (`a939828d…`) as the default constant. Chunk 005 release is the One-Time Setup Checklist event that re-points ldflags to the live `delt.3`-published canonical's trust-root. The re-pin event itself is a chunk-005 task; this chunk pins the mechanism.
