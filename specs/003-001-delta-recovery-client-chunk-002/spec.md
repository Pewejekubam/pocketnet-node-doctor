# Feature Specification: Client Foundation + Diagnose

**Feature Branch**: `003-001-delta-recovery-client-chunk-002`
**Created**: 2026-04-30
**Status**: Verified
**Input**: User description: "Chunk 002 (Client Foundation + Diagnose) of pocketnet-node-doctor. Implements the doctor's read-only pathway plus shared scaffolding: project skeleton, plan-format library, manifest verifier, hash utilities, diagnose phase (US-001), five pre-flight refusal predicates (US-003), and trust-root authentication (FR-017, FR-018). Authoritative sources: specs/001-delta-recovery-client/pre-spec-strategic-chunking.md §Chunk 002 and specs/001-delta-recovery-client/pre-spec.md."

## Clarifications

### Session 2026-04-30

- **Q1**: When a pre-flight refusal predicate fires during a `diagnose` invocation, is `plan.json` emitted at all (e.g., a stub plan recording the refusal), or is no plan file written?
  - **A1**: No plan file is written on pre-flight refusal. Per pre-spec FR-005 ("diagnose performs zero writes to `pocketdb/`") and the chunking doc's behavioral criterion that "pre-flight predicates run before any pocketdb byte is read; refusal short-circuits with no I/O against pocketdb," predicates short-circuit before the diagnose phase begins. Plan emission is a downstream-of-diagnose action and does not occur on refusal. (Note: the `--plan-out` path may live outside `pocketdb/`; the no-emission rule still holds — refusal short-circuits all diagnose-phase output.) US-002 acceptance scenario 7 is tightened in-place to make this explicit.

- **Q2**: When the canonical pre-flight predicate order is evaluated and the first predicate would refuse, does evaluation stop at the first refusing predicate (only that predicate's exit code is emitted), or does it continue evaluating subsequent predicates?
  - **A2**: Stop-at-first. SC-006 specifies "blocks the operation with a distinct exit code" (singular); the chunking doc orders predicates "cheapest and least-invasive checks fire first" with explicit refusal semantics. Evaluation stops at the first refusing predicate; only that predicate's distinct exit code and naming diagnostic are emitted. Subsequent predicates are not evaluated. US-002 acceptance scenario 8 is tightened in-place to state this.

- **Q3**: What does diagnose write to stdout? The chunking doc's logging-surface stop pins all human-readable output (summary + progress) to stderr; `plan.json` is a file. Is stdout used at all by diagnose in v1?
  - **A3**: Stdout is unused by diagnose in v1. All human-readable output (summary, progress, predicate diagnostics) is emitted on stderr per the chunking doc's logging-surface Speckit Stop Resolution; the machine-readable plan is written to the path resolved from `--plan-out`. Stdout is reserved for future machine-readable output without committing v1 to a structured-stream contract. FR-004 is tightened in-place; US-001's narrative aligns with the chunking doc's stderr pin (overriding the pre-spec narrative line that predates the logging-surface stop).

- **Q4**: At what point does the doctor verify that the resolved `--plan-out` path is writable — up-front as a pre-flight check (refusal before any diagnose work), or only at plan-write time at the end of the diagnose phase (potentially wasting the diagnose work on an unwritable target)?
  - **A4**: Deferred to /speckit.plan — see plan-layer decision D6: `--plan-out` writability verification timing. This is a mechanism question (when to stat/probe the plan-out target) within the spec-pinned contract that the five v1 pre-flight predicates are scoped to the volume holding `pocketdb/` (per FR-013 and EC-011 wording), not the volume holding `--plan-out`. Either timing is consistent with the spec; the choice is plan-layer.

- **Q5**: SC-001 (timing half) and SC-002 specify "within 5 minutes" — what is the wall-clock measurement boundary?
  - **A5**: Defensive default — revisit at /speckit.plan if test rigging requires finer-grained boundaries. End-to-end wall-clock from doctor process invocation to clean exit (process exited 0, `plan.json` fully written and fsync'd, all stderr output flushed). The 5-minute budget is end-to-end on the reference rig (8 vCPU x86_64, NVMe-class disk, 16 GB RAM) and includes manifest fetch, page-hashing, file-hashing, and plan emission. SC-001 and SC-002 are tightened in-place.

## Context anchors

- Authoritative scope source: [`pre-spec-strategic-chunking.md`](../001-delta-recovery-client/pre-spec-strategic-chunking.md) §Chunk 002.
- Pre-spec source of truth (US/FR/SC/EC text): [`pre-spec.md`](../001-delta-recovery-client/pre-spec.md).
- Prior artifact boundaries:
  - Pre-spec v1.1.0 (status: approved).
  - Chunk 001's frozen manifest schema (Gate 001-Schema → 002).
  - Chunk 001's published trust-root constant, compiled in at build time per the One-Time Setup Checklist.
  - Pre-spec Implementation Context's canonical-form serialization rule (sorted JSON keys, no insignificant whitespace, UTF-8) — used identically by the manifest-trust-root verifier (this chunk) and the plan-format library's self-hash (this chunk).

## User Scenarios & Testing *(mandatory)*

The user is a pocketnet operator with a stopped or crashed node, invoking the doctor binary on the command line. Three independently testable user stories deliver this chunk's value: a read-only diagnose pathway, a five-predicate pre-flight refusal surface, and trust-root authentication of the canonical manifest.

### User Story 1 — Diagnose a Dead Node (Priority: P1)

An operator's pocketnet node has crashed or refuses to start. The operator runs `pocketnet-node-doctor diagnose --canonical <url> --pocketdb <path>`. Within minutes the operator receives (a) a human-readable summary on stderr naming what differs, what would be fetched, and how many bytes that represents; (b) a machine-readable `plan.json` written alongside the pocketdb path. The operator has not modified any byte on disk.

**Why this priority**: Diagnose is the first observable doctor surface an operator interacts with; without it the apply chunk has no input and the bandwidth-saving design point cannot be exercised. Diagnose also exercises every load-bearing library this chunk introduces (manifest verifier, hash utilities, plan-format library), so its acceptance is the integration test for the chunk's foundational scaffolding.

**Independent Test**: A fixture pocketdb 30 days behind a fixture canonical, the doctor binary built against that canonical's trust-root constant, and an HTTPS endpoint serving that canonical's manifest. Running `diagnose` against this rig produces a `plan.json` whose entries name the differing pages and files, prints a human-readable summary, exits 0, and leaves the fixture pocketdb bitwise unchanged. A second rig where the fixture pocketdb is bitwise-identical to the canonical produces a zero-entry plan and the same exit-0 outcome.

**Acceptance Scenarios**:

1. **Given** a stopped node with `pocketdb/main.sqlite3` 60 days behind the canonical checkpoint, **When** the operator runs diagnose, **Then** the tool produces a plan listing the differing pages, summarizes total bytes to fetch, and exits with code 0; no bytes in `pocketdb/` are modified.
2. **Given** a stopped node identical to canonical, **When** the operator runs diagnose, **Then** the tool produces a plan with zero entries, prints "no recovery needed," and exits with code 0.
3. **Given** a stopped node with corrupted `main.sqlite3`, **When** the operator runs diagnose, **Then** the tool produces a plan covering the corrupt pages without distinguishing them from drifted pages.
4. **Given** a successful diagnose run, **When** the emitted `plan.json` is parsed, **Then** its `self_hash` field equals SHA-256 over the plan's canonical-form payload with `self_hash` removed (per the pre-spec Implementation Context canonical-form rule), making tampering detectable downstream.
5. **Given** a successful diagnose run, **When** the emitted `plan.json` is parsed, **Then** its `canonical_identity` (block height, manifest hash, pocketnet-core version) and `format_version` fields are populated from the verified manifest the run consumed.
6. **Given** a long-running diagnose against a deeply-divergent pocketdb, **When** the run is in flight, **Then** the operator observes progress messages on stderr at file-class boundaries (e.g., `main.sqlite3` page-hashing milestones, `blocks/` file-by-file) so liveness is visible; the messages are human-readable, not a structured machine protocol.

---

### User Story 2 — Refuse to Damage a Healthy or Running Node (Priority: P1)

The operator (perhaps mistakenly) invokes the doctor on a node that should not be touched: the `pocketnet-core` process is running (or `main.sqlite3` is locked by a non-`pocketnet-core` OS-level lock); the local pocketnet-core binary version does not match the canonical's; the volume holding `pocketdb/` lacks free space for the staging area; the volume lacks write permission for the doctor's user account or is mounted read-only; or the local pocketdb is in a state strictly newer than the canonical's pinned block height. The doctor refuses without modifying anything and prints a diagnostic naming which predicate failed. Each predicate produces a distinct exit code so wrappers can branch without parsing stderr.

**Why this priority**: The doctor's safety contract is "refuse loudly, mutate carefully" — pre-flight predicates that would make diagnose or apply destructive must hard-refuse before any byte is read or written. Without all five predicates wired correctly, the doctor's destructive-by-default risk profile is unbounded.

**Independent Test**: Five separate fixture rigs, each violating exactly one predicate. Running the doctor against each rig produces the predicate's distinct exit code, prints a diagnostic naming the predicate, and leaves the fixture pocketdb bitwise unchanged. A sixth rig where every predicate passes (the rig from US-001) confirms predicates do not over-trigger.

**Acceptance Scenarios**:

1. **Given** `pocketnet-core` is running against the local pocketdb, **When** the operator invokes diagnose or apply, **Then** the tool refuses with a diagnostic naming the running-node predicate and exits with the running-node code; no bytes read against `pocketdb/`, no bytes written.
2. **Given** a stopped node whose `main.sqlite3` is held under an OS-level file lock not owned by `pocketnet-core`, **When** the operator invokes the doctor, **Then** the tool refuses on the running-node predicate (treating the foreign lock as the running-node refusal case per pre-spec EC-004); no bytes read against `pocketdb/`, no bytes written.
3. **Given** a stopped node whose `main.sqlite3` SQLite header `change_counter` strictly exceeds the canonical manifest's recorded `change_counter`, **When** the operator invokes apply (or diagnose at the same predicate stage), **Then** the tool refuses with a diagnostic naming the ahead-of-canonical predicate and exits with the ahead-of-canonical code.
4. **Given** a canonical manifest pinned to pocketnet-core vX.Y and a local install of vX.Z, **When** the operator invokes diagnose, **Then** the tool refuses with a diagnostic naming the version-mismatch predicate and exits with the version-mismatch code.
5. **Given** insufficient free space on the volume holding `pocketdb/` for the staging area, **When** the operator invokes apply (or diagnose at the same predicate stage), **Then** the tool refuses up front, names the shortfall in bytes, and exits with the capacity code.
6. **Given** the volume holding `pocketdb/` lacks write permission for the doctor's user account or is mounted read-only at pre-flight, **When** the operator invokes the doctor, **Then** the tool refuses with a diagnostic naming the permission/read-only predicate and exits with the permission/read-only code (per pre-spec EC-011, the permissions counterpart to the capacity check).
7. **Given** any pre-flight refusal fires, **When** the run aborts, **Then** no byte under `pocketdb/` has been read by the doctor — predicates short-circuit before any pocketdb byte is opened — no byte under `pocketdb/` has been written, and no `plan.json` file is emitted at the `--plan-out` path (plan emission is downstream of diagnose's read-only phase and does not occur on pre-flight refusal).
8. **Given** the five predicates are evaluated, **When** any predicate could fire, **Then** they are evaluated in the canonical order: running-node → version-mismatch → volume-capacity → permission/read-only → ahead-of-canonical (so the cheapest and least-invasive checks fire first; the ahead-of-canonical check parses the SQLite header and runs last). Evaluation short-circuits at the first refusing predicate: only that predicate's distinct exit code and naming diagnostic are emitted, and subsequent predicates are not evaluated.

---

### User Story 3 — Refuse an Inauthentic or Forward-Versioned Manifest (Priority: P1)

The operator runs diagnose against a `--canonical <url>`. The doctor fetches the canonical's manifest, computes SHA-256 over its canonical-form payload, and compares the result to the trust-root constant compiled into the binary at build time. If the comparison fails, the doctor refuses without ever fetching a chunk-store byte. If the manifest's `format_version` is a value the doctor does not recognize, the doctor refuses with a diagnostic naming the version mismatch — a future canonical can extend the schema without breaking v1 binaries' refusal posture. The reserved `trust_anchors` block is parsed but its contents are ignored in v1; an unrecognized non-empty block does not cause refusal.

**Why this priority**: The doctor's trust contract is the load-bearing property that distinguishes "fetched bytes are canonical" from "fetched bytes are whatever the network handed us." A doctor that fetches and applies bytes from an inauthentic manifest is worse than no doctor at all. This story also pins FR-018's forward-compatibility surface: future canonicals can carry chain-anchored or healthy-peer trust evidence in `trust_anchors` without breaking v1 parsers, and a future schema bump (`format_version` ≥ 2) is signalled at the v1 doctor's refusal boundary rather than producing silent misbehavior.

**Independent Test**: Three fixture rigs, all serving the same canonical block height via the same `--canonical <url>`. Rig A serves the manifest the trust-root was minted from; Rig B serves a tampered manifest whose canonical-form-hash differs from the trust-root; Rig C serves a manifest with `format_version` set to a value the doctor does not recognize. Running diagnose against Rig A succeeds; against Rig B refuses with the trust-root mismatch diagnostic and no chunk-store bytes are fetched; against Rig C refuses with a distinct exit code naming the format-version mismatch. A fourth rig serves a manifest carrying a non-empty unrecognized `trust_anchors` block; diagnose against it succeeds, confirming the reserved block is parsed but its contents are ignored.

**Acceptance Scenarios**:

1. **Given** a doctor binary built with trust-root constant T, **When** the doctor fetches a manifest whose canonical-form payload SHA-256 equals T, **Then** the doctor proceeds with diagnose against the verified manifest.
2. **Given** a doctor binary built with trust-root constant T, **When** the doctor fetches a manifest whose canonical-form payload SHA-256 differs from T, **Then** the doctor refuses with the manifest-hash-verification-failure diagnostic, exits non-zero, and has fetched zero bytes from the chunk store (this is pre-spec EC-008).
3. **Given** a doctor binary recognizing `format_version` 1, **When** the doctor fetches a manifest whose `format_version` is a value the doctor does not recognize (e.g., 2), **Then** the doctor refuses with a distinct exit code (the manifest-format-version-unrecognized code) and a diagnostic naming the version mismatch; this is the testable surface for FR-018.
4. **Given** a doctor binary recognizing `format_version` 1, **When** the doctor fetches a manifest whose `trust_anchors` block is non-empty with contents the doctor does not recognize, **Then** the doctor parses the block's presence, ignores its contents, and proceeds normally — preserving architectural openness for chain-anchored or healthy-peer cross-check trust evidence per pre-spec Out-of-Scope.

---

### Edge Cases

The chunking doc assigns this chunk five edge cases from the pre-spec EC list, each owned by one of the user stories above. They are surfaced here so the requirements checklist enumerates them explicitly.

- **EC-001 (US-001)**: Local pocketdb is missing entirely. Diagnose treats every canonical file as "not present locally" and emits a plan equivalent to a full fetch. (Apply-side handling is owned by Chunk 003.)
- **EC-002 (US-001)**: Local pocketdb is partially present (e.g., `main.sqlite3` exists, `chainstate/` is missing). Diagnose handles missing files as full-file divergences without conflating "missing locally" with "needs replacement." (Apply-side handling is owned by Chunk 003.)
- **EC-004 (US-002)**: Local `main.sqlite3` is locked by an OS-level file lock that's not from `pocketnet-core`. Treated as the running-node refusal case (FR-010).
- **EC-008 (US-003)**: Manifest SHA-256 verification fails (computed canonical-form-hash does not equal the project-pinned trust-root constant). Doctor refuses without consuming any chunk-store bytes.
- **EC-011 (US-002)**: Volume holding `pocketdb/` lacks write permission for the doctor's user account, or is mounted read-only at pre-flight. Refused before any chunk-store fetch begins; the permissions counterpart to FR-013's capacity check.

## Requirements *(mandatory)*

### Functional Requirements

These are the pre-spec FRs that §Chunk 002 of the chunking doc assigns to this chunk. Each is reproduced in pre-spec form (outcome-focused; mechanism details belong in Implementation Context).

**Diagnose surface (backs US-001):**

- **FR-001**: Doctor MUST compute per-page hashes of `pocketdb/main.sqlite3` matching the canonical manifest's page-grid, suitable for offset-aligned comparison against manifest entries.
- **FR-002**: Doctor MUST read non-SQLite artifacts under `pocketdb/` (`blocks/`, `chainstate/`, `indexes/`, any other files in the canonical) at whole-file granularity and compute a whole-file hash that can be compared against manifest entries.
- **FR-003**: Doctor MUST produce a machine-readable plan listing every divergence — page offsets for `main.sqlite3`, file paths for the rest — with the canonical hash each item must equal after apply. The plan MUST carry the canonical identity (block height, manifest hash, pocketnet-core version) it was computed against.
- **FR-004**: Doctor MUST emit a human-readable summary alongside the plan: total entries, total bytes-to-fetch, breakdown by artifact class, ETA estimate. The summary, all progress messages, and any predicate diagnostics are emitted on stderr (per the chunking doc's logging-surface Speckit Stop Resolution); stdout is unused by diagnose in v1 and reserved for future machine-readable output.
- **FR-005**: Doctor's diagnose phase MUST perform zero writes to `pocketdb/` or any descendant; diagnose MUST be observably read-only.

**Refusal predicates (back US-002):**

- **FR-010**: Doctor MUST refuse to run if a `pocketnet-core` process is currently using `pocketdb/` (lockfile or process check); EC-004 — a non-`pocketnet-core` OS-level lock on `main.sqlite3` — is handled under this same predicate.
- **FR-011**: Doctor MUST refuse to run apply if the local pocketdb is in a state strictly newer than the canonical's pinned block height. (At this chunk's pre-flight stage, the predicate fires when the local `main.sqlite3` SQLite header `change_counter` strictly exceeds the canonical manifest's recorded `change_counter`.)
- **FR-012**: Doctor MUST refuse to run if the local `pocketnet-core` binary version differs from the version recorded in the canonical manifest.
- **FR-013**: Doctor MUST refuse to run apply if the volume holding `pocketdb/` lacks sufficient free space for the staging area; the shortfall MUST be reported in bytes. (Free-space requirement is bounded above by 2× the size of files in the plan per pre-spec Implementation Context's per-file shadow-copy rollback mechanism.)
- **EC-011 (refusal predicate, fifth)**: Doctor MUST refuse before any chunk-store fetch begins if the volume holding `pocketdb/` lacks write permission for the doctor's user account or is mounted read-only — the permissions counterpart to FR-013's capacity check.

**Trust-root authentication (backs US-003):**

- **FR-017**: Doctor MUST verify the canonical manifest's integrity by comparing its computed SHA-256 (over the canonical-form payload per the pre-spec Implementation Context rule) against the project-pinned trust-root hash before consuming any of its entries. A manifest whose computed hash does not equal the trust-root hash MUST be rejected; no chunk-store bytes MUST be fetched against an unverified manifest.
- **FR-018**: The manifest format MUST NOT foreclose adding chain-anchored manifest verification or healthy-peer cross-check verification in a future version. Concretely: the manifest schema declares a `format_version` field (current value 1) and a reserved `trust_anchors` block (empty in v1); the doctor MUST refuse with a distinct exit code naming the version mismatch when `format_version` is a value the doctor does not recognize, and MUST parse a non-empty `trust_anchors` block's presence while ignoring its contents in v1.

### Key Entities

- **Plan**: A machine-readable JSON artifact produced by diagnose. Lists divergences (page offsets for `main.sqlite3`; whole files for other artifacts) and the canonical hashes apply will verify against. Carries `format_version` (integer; current value 1), `canonical_identity` (block height, manifest hash, pocketnet-core version), `divergences` array, and a `self_hash` field. The `self_hash` is SHA-256 over the plan's canonical-form payload with `self_hash` removed (sorted JSON keys, no insignificant whitespace, UTF-8 — pre-spec Implementation Context canonical-form rule). Read-only after diagnose emits it; consumed without mutation by Chunk 003's apply.
- **Manifest (consumed)**: The frozen-schema JSON manifest published by Chunk 001 for a canonical at a given block height. Fields the doctor consumes: `format_version`, `canonical_identity` (block height, pocketnet-core version, created_at), per-file entries (page-level for `main.sqlite3`, whole-file for non-SQLite artifacts), `main.sqlite3` SQLite header `change_counter`, reserved `trust_anchors` block.
- **Trust-root constant**: SHA-256 hex string compiled into the doctor binary at build time per the One-Time Setup Checklist. The doctor authenticates a fetched manifest by computing the SHA-256 of the manifest's canonical-form payload and comparing it to this constant.
- **Refusal predicate**: A pre-flight check that, on a positive trigger, emits a diagnostic and exits with a distinct exit code, having performed zero writes against `pocketdb/`. The five v1-enumerated predicates are running-node, ahead-of-canonical, pocketnet-core-version-mismatch, volume-capacity, and permission/read-only.
- **Pre-flight ordering**: The fixed order in which predicates are evaluated within a single doctor invocation: running-node → version-mismatch → volume-capacity → permission/read-only → ahead-of-canonical.

## Success Criteria *(mandatory)*

### Measurable Outcomes

These are the testable success criteria §Chunk 002 of the chunking doc assigns to this chunk. Pre-spec SCs trace to user stories above; chunk-internal SCs (CSC002-*) supplement the pre-spec SCs with chunk-specific verifications the pre-spec does not enumerate.

- **SC-001 (timing half)**: On a fixture pocketdb 30 days behind a fixture canonical, diagnose completes within 5 minutes on the reference rig (8 vCPU x86_64 host, NVMe-class disk, 16 GB RAM). The 5-minute budget is end-to-end wall-clock from doctor process invocation to clean exit (process exited 0, `plan.json` fully written, all stderr output flushed) and includes manifest fetch, page-hashing, file-hashing, and plan emission. (Backs US-001. The fetch-size half of pre-spec SC-001 — total fetch size ≤ 25% of full-snapshot size — is verified at Gate 003 → 004 against a real canonical and is out of scope for this chunk.)
- **SC-002**: On a node identical to canonical, diagnose emits a zero-entry plan and exits cleanly within 5 minutes (same end-to-end wall-clock measurement as SC-001). (Backs US-001.)
- **SC-006**: Each of the five refusal predicates (running-node, ahead-of-canonical, version-mismatch, volume-capacity, permission/read-only) blocks the operation with a distinct exit code and a diagnostic naming the predicate; no bytes are modified. (Backs US-002.)
- **CSC002-001**: Plan self-hash round-trip — for any plan emitted by diagnose, computing SHA-256 over the plan's canonical-form payload (with `self_hash` removed; sorted JSON keys, no insignificant whitespace, UTF-8 per the pre-spec Implementation Context rule) yields a value equal to the plan's `self_hash` field. (Backs US-001; chunk-internal verification of FR-003's tamper-detection contract.)
- **CSC002-002**: Manifest-format-version refusal — a manifest with a `format_version` value the doctor does not recognize (e.g., 2 against a v1-recognizing doctor) causes diagnose to refuse with a distinct exit code naming the version mismatch. (Backs US-003; chunk-internal verification of FR-018's forward-compatibility surface.)

## What this chunk unblocks

- **Chunk 003 (Client Apply)** may begin once this chunk's plan format is stable — apply consumes the plan emitted by diagnose without modification.
- Operators can run `pocketnet-node-doctor diagnose` against a published canonical and see what their recovery would entail — including the bytes-to-fetch summary — without any mutation risk to their pocketdb.

## Speckit Stop Resolutions inherited from the chunking doc

These resolutions are pinned by §Chunk 002 of the chunking doc and are **not** re-decided in this spec. They are surfaced here so the downstream pipeline (`/speckit.plan`, `/speckit.tasks`, `/speckit.implement`) does not stop on them.

- **Plan-stage / language and runtime**: Go, single static binary across Linux, macOS, and Windows, no runtime dependencies. (Inherits the pre-spec Implementation Context language pin.)
- **Plan-stage / CLI surface**: Subcommands `diagnose` and `apply`. Reserves namespace for a future `apply --full` subsumption mode per pre-spec Stage 4 hand-off note. No subcommand-collapsed-into-flags structure.
- **Plan-stage / HTTP client library**: Go's standard-library `net/http` client. No bespoke HTTP framework. Connection re-use is enabled at the worker-pool level when Chunk 003 implements parallel chunk fetches; the same library inherits to Chunk 003.
- **Plan-stage / SQLite library bindings**: A single Go SQLite binding chosen at plan-stage from the Go ecosystem (e.g., `mattn/go-sqlite3` or `modernc.org/sqlite` — the choice itself is plan-layer; see Plan-layer deferrals). Used by Chunk 002 for the `change_counter` ahead-of-canonical check (where possible via direct file-header parsing without invoking the engine) and inherits to Chunk 003 for the post-apply `integrity_check`. Same binding inherits to Chunk 003 to avoid linking two SQLite engines into one binary.
- **Plan-stage / logging surface**: Plain-text to stderr at info level by default; `--verbose` flag enables debug. No structured logging in v1; no log-file output. Diagnose progress reporting reuses the same stderr surface.
- **Plan-stage / progress reporting on long diagnose runs**: Diagnose emits progress to stderr at file-class boundaries (`main.sqlite3` page-hashing milestones, `blocks/` file-by-file). Format is human-readable; not a structured machine protocol.
- **Plan-stage / configuration storage**: No user-config file in v1. Behavior is controlled by CLI flags only. Trust-root is compiled in.
- **Plan-stage / FR-018 forward-compat surface**: The manifest schema declares a `format_version` field (current value 1) and a reserved `trust_anchors` block (empty in v1). Future canonicals can populate `trust_anchors` with chain-anchored verification fields, healthy-peer cross-check fields, or other trust evidence without breaking v1 parsers. v1 parsers ignore unknown contents of `trust_anchors` but parse and validate the field's presence. CSC002-002 covers the version-mismatch path.
- **Clarify-stage / plan filename and location**: `plan.json` written alongside the operator's pocketdb-parent directory by default, overrideable with `--plan-out <path>`.
- **Tasks-stage / pre-flight predicate ordering**: running-node → version-mismatch → volume-capacity → permission/read-only → ahead-of-canonical.
- **Tasks-stage / exit-code allocation**: `0` success. `1` generic error. `2..7` pre-flight refusals (per condition; fired in either diagnose or apply, whichever encounters the condition first): `2` running-node, `3` ahead-of-canonical, `4` pocketnet-core-version mismatch, `5` capacity, `6` permission/read-only, `7` manifest-format-version unrecognized. `10..19` reserved for **mid-run** apply-time failures (Chunk 003 inherits and allocates: `10` rollback completed, `11` rollback failed, `12` network retry budget exhausted, `13` reserved for future apply-time errors, `14` EC-005 superseded-canonical refusal, `15` plan tamper detected). Categorization rule: `2..7` pre-flight (refuse before mutating anything), `10..19` mid-run (refuse after pre-flight, may have staging artifacts to clean up). Codes MUST be documented in `--help` output and the Chunk 005 troubleshooting guide.

## Plan-layer deferrals

The following decisions belong to `/speckit.plan` (HOW), not to this spec (WHAT). They are recorded here so they are not silently absorbed at spec time.

- **Plan-layer decision**: Concrete Go SQLite binding selection from the Go ecosystem (`mattn/go-sqlite3`, `modernc.org/sqlite`, or another stable binding). The chunking doc pins "a single binding inherits across Chunks 002 and 003"; the specific binding is plan-layer.
- **Plan-layer decision**: Concrete CLI flag grammar within the pinned subcommand structure — flag names beyond the spec-pinned `--canonical`, `--pocketdb`, `--plan-out`, `--verbose` (e.g., short forms, environment-variable overrides, `--help` text grammar) are plan-layer.
- **Plan-layer decision**: Concrete grammar of the diagnose human-readable summary on stdout/stderr (the spec pins fields per FR-004 — total entries, total bytes-to-fetch, breakdown by artifact class, ETA estimate — but the rendered text format, ETA computation method, and column layout are plan-layer).
- **Plan-layer decision**: Concrete grammar of the diagnose progress messages on stderr (the spec pins "human-readable, at file-class boundaries"; the exact message templates and milestone cadence within a file class are plan-layer).
- **Plan-layer decision**: Concrete mechanism for the `change_counter` ahead-of-canonical pre-flight check — direct SQLite file-header byte parsing (preferred per the chunking doc when feasible) versus opening the file via the chosen Go SQLite binding. The spec pins "where possible via direct file-header parsing without invoking the engine"; the fallback pathway choice is plan-layer.
- **Plan-layer decision**: Concrete mechanism for the running-node pre-flight predicate (FR-010) — process-table scan, lockfile inspection, advisory-lock probe, or combination. The spec pins "lockfile or process check" per pre-spec FR-010 wording; the specific implementation mix is plan-layer.
- **Plan-layer decision D6**: Timing of `--plan-out` writability verification — up-front (probe writability before any diagnose work) versus at plan-write time (probe at the end of the diagnose phase, after all read-only work completes). The spec pins that the five v1 pre-flight predicates are scoped to the volume holding `pocketdb/` (FR-013, EC-011), not the volume holding `--plan-out`; either timing is consistent with that contract. The choice — including whether to add a non-predicate up-front writability check — is plan-layer.

## Assumptions

- The Chunk 001 manifest schema is frozen at Gate 001-Schema → 002 before this chunk begins (`/speckit.plan` and beyond). Schema evolution after freeze is governed by FR-018's `format_version` mechanism.
- The Chunk 001 trust-root constant is published before this chunk's binaries are built; the One-Time Setup Checklist captures the constant's value at build time. (The pre-spec Implementation Context names a development trust-root constant for chunk 002 / chunk 003 development builds; re-pinning to a `delt.3`-published live canonical happens at Chunk 005 release.)
- The pre-spec's Implementation Context is the single authoritative source for the canonical-form serialization rule (sorted JSON keys, no insignificant whitespace, UTF-8); this chunk inherits it for both manifest-trust-root verification (FR-017) and plan self-hash (FR-003 / CSC002-001).
- Pre-spec FR-014 (pre-rename hash verification of fetched chunks), FR-015 / FR-016 (post-apply `PRAGMA integrity_check` and rollback), FR-019 / FR-020 (network resilience and resumability), and FR-006 / FR-007 / FR-008 / FR-009 (apply-phase fetching, atomicity, resumability, pre-apply snapshot) are owned by Chunk 003 (apply) and are out of scope for this chunk.
- Pre-spec edge cases EC-003, EC-005, EC-006, EC-007, EC-009, EC-010 are not assigned to this chunk by the chunking doc and are out of scope for this spec; they are owned by Chunk 003 or Chunk 004 per the chunking doc's edge-case ownership table.
- The doctor binary is invoked by an operator who has already stopped `pocketnet-core` per pre-spec Out-of-Scope ("Driving `pocketnet-core` (start/stop/configure)"). The running-node predicate's job is to refuse if that has not been done — not to drive the daemon.
- The reference rig for SC-001 (timing half) and SC-002 — 8 vCPU x86_64 host, NVMe-class disk, 16 GB RAM — is available to the implementation team and is the same rig the pre-spec names. The fetch-size half of pre-spec SC-001 (≤ 25% of full-snapshot size) is verified at Gate 003 → 004 against a real canonical, not in this chunk.
