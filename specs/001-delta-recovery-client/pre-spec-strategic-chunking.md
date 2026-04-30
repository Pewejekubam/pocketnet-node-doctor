---
version: 0.1.0
status: draft
created: 2026-04-30
last_modified: 2026-04-30
authors: [pewejekubam, claude]
related: pre-spec.md
changelog:
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

This document decomposes the implementation of `pocketnet-node-doctor` (specified by [`pre-spec.md`](pre-spec.md) v0.3.1) into four dependency-ordered implementation chunks. Each chunk is a self-contained, testable, debuggable unit fed independently to the speckit pipeline (`speckit.specify` → `speckit.implement`). Monolithic specs produce monolithic code; the chunking thesis is that bounded chunks produce bounded, mergeable implementations.

The pre-spec is the source of truth. This document is derived from it and must remain consistent with it. If a chunking-stage audit reveals a pre-spec gap, the gap is fixed in the pre-spec first and the change flows forward into this chunking document.

---

## Critical Path

```
Setup (empirical baselines, prereq experiments)
   │
   ▼
Chunk 1 — Server-Side: Manifest + Chunk Store Generation
   │
   ├──────────────────────────────────────────┐
   ▼                                          │
Chunk 2 — Client Foundation + Diagnose        │ (Chunk 2 may develop in
   │                                          │  parallel against a mock
   │  ┌───────────────────────────────────────┘  chunk store; convergence
   │  │                                          on real chunk store occurs
   ▼  ▼                                          at Chunk 3 entry)
Chunk 3 — Client Apply
   │
   ▼
Chunk 4 — End-to-End Drill + Network Resilience + Release Polish
```

**Serial dependencies.** Chunk 3 cannot ship until Chunk 1 (real chunk store) and Chunk 2 (real plan format) are merged. Chunk 4's drill scenario requires all three prior chunks.

**Parallel work.** Chunks 1 and 2 may develop in parallel if Chunk 2 stubs the chunk store with a mock that returns canned manifests and chunks. Convergence happens at the entry to Chunk 3 — apply must work against a real chunk store.

**Convergence point.** End of Chunk 3 — at this point a recovering operator can complete a real diagnose-and-apply cycle against a real canonical published by the server-side counterpart. Chunk 4 hardens that capability into a community-ready release.

---

## Progress Tracker

| Chunk | Title | FRs | SCs | Status |
|-------|-------|-----|-----|--------|
| 1 | Server-Side: Manifest + Chunk Store Generation | (integration contracts; see chunk body) | SC-007 (drill prerequisite) | Pending |
| 2 | Client Foundation + Diagnose | FR-001, FR-002, FR-003, FR-004, FR-005, FR-010, FR-011, FR-012, FR-013, FR-017, FR-018 | SC-001, SC-002, SC-006 | Pending |
| 3 | Client Apply | FR-006, FR-007, FR-008, FR-009, FR-014, FR-015, FR-016, FR-019, FR-020 | SC-003, SC-004, SC-005 | Pending |
| 4 | End-to-End Drill + Network Resilience + Release Polish | (no new FRs; integration of all prior) | SC-007, SC-008 | Pending |

---

## One-Time Setup Checklist

Pre-implementation prerequisites. None of these are implementation chunks; they are environment, data, or measurement work that must complete before or alongside the chunks.

- [ ] **Pre-spec is at `status: approved`** in frontmatter (Stage 6 exit; chunking is currently `draft`, see hand-off requirement)
- [ ] **Empirical baseline reuse measurement on `main.sqlite3` March → April** is captured (delt.1 follow-up; delt.1 already done — original 85.83% measurement validates the pre-spec's bandwidth claim; this checkbox is the audit-trail confirmation that the experiment artifact lives at `experiments/01-page-alignment-baseline/`)
- [ ] **Cross-DB reuse pattern measured on `web.sqlite3`** to confirm the page-level reuse pattern is not unique to `main.sqlite3` (delt.1)
- [ ] **March → April chunk store materialization** to validate compressed delta size against the projected ~13–15 GB target (delt.2)
- [ ] **Worst-case bracket reuse rate measured (Feb → April)** to confirm the design holds across longer-than-30-day intervals; expected reuse rate floor ≥ 50% (delt.5)
- [ ] **Project test rig matches SC-001 reference rig** (8 vCPU x86_64 host, NVMe-class disk, 16 GB RAM) or alternative reference is documented and SC-001 is amended
- [ ] **Project-internal test node** stopped, snapshotted (virtual-machine snapshot), and confirmed dead-state reproducible before Chunk 4 drill commences

---

## Infrastructure Gate Checklists

Each gate is a concrete, verifiable predicate that must hold before the next chunk can begin. Failures block the next chunk; gates are not advisory.

### Gate 1 → 2: Chunk Store Available

After Chunk 1 merges, before Chunk 2 begins integration testing (Chunk 2 dev work may proceed against a mock chunk store before this gate; integration testing requires the gate).

- [ ] **Manifest URL serves a manifest for a pinned canonical block height** — `curl -s <manifest-url> | sha256sum` returns a known hash that matches the project-pinned trust-root constant
- [ ] **Manifest fields parse cleanly** — manifest contains `block_height`, `pocketnet_core_version`, per-file metadata for `main.sqlite3` (page-level entries), and per-file metadata for `blocks/`, `chainstate/`, `indexes/` (whole-file entries)
- [ ] **Chunk URLs serve verified chunks** — for at least three sampled chunks (one `main.sqlite3` page, one `blocks/` file, one `chainstate/` file), `curl -s <chunk-url> | sha256sum` matches the manifest's recorded hash for that chunk
- [ ] **Content-Encoding negotiation works** — chunk requests with `Accept-Encoding: zstd` return zstd-encoded payloads; with `Accept-Encoding: gzip` return gzip-encoded payloads; absence of either returns a clear error or unencoded bytes per server policy

### Gate 2 → 3: Plan Format Round-Trips

After Chunk 2 merges, before Chunk 3 begins.

- [ ] **Diagnose against a known-divergent local pocketdb produces a plan** — running `pocketnet-node-doctor diagnose` on a local pocketdb that is N days behind the canonical produces a `plan.json` whose divergence count is non-zero and whose total fetch size is within 25% of the full snapshot size (per SC-001)
- [ ] **Plan self-hash verifies** — recomputing the SHA-256 over the plan's canonical-form payload (sorted keys, no insignificant whitespace, with `self_hash` field removed) equals the plan's declared `self_hash`
- [ ] **Plan canonical identity is bound** — the plan's `canonical_identity` block carries the manifest hash that the trust-root pin authenticated; a second diagnose against a different canonical produces a plan with a different `canonical_identity`
- [ ] **Diagnose on a node identical to canonical produces a zero-entry plan** (per SC-002)
- [ ] **All four pre-flight refusal predicates fire correctly** — running diagnose with (a) `pocketnet-core` running, (b) ahead-of-canonical local node, (c) version mismatch, (d) insufficient volume capacity each refuses with a distinct exit code (per SC-006)

### Gate 3 → 4: Apply Round-Trips Against Real Canonical

After Chunk 3 merges, before Chunk 4 begins.

- [ ] **Apply against a real plan results in canonical-matching pocketdb** — every file's hash matches the canonical manifest after apply; `PRAGMA integrity_check` returns "ok" (per SC-003)
- [ ] **Mid-apply interruption resumes cleanly** — killing the apply process during fetch and re-running with the same plan completes without re-fetching previously-fetched chunks (per SC-004)
- [ ] **Verification failure rolls back** — simulating a chunk-store byte error (e.g., chunk store serves a wrong-length payload that fails hash verification) results in observable rollback to pre-apply state (per SC-005)
- [ ] **EC-011 permission refusal fires** — apply on a read-only mount or unwritable volume refuses at pre-flight without staging any bytes

---

## Chunk 1: Server-Side Manifest + Chunk Store Generation

### Scope

Extend the existing `pocketnet_create_checkpoint` workflow so that, alongside the full-snapshot artifact it already publishes, it produces:

1. A **manifest** describing the canonical pocketdb at the published block height (per-page hashes for `main.sqlite3`, whole-file hashes for `blocks/`, `chainstate/`, `indexes/`, and any other artifacts).
2. A **chunk store** — an HTTPS-addressable byte source from which differing chunks can be fetched at the granularities the manifest declares.
3. A published **trust-root SHA-256** of the manifest, suitable for the doctor binary to compile in.

The implementation lives in the `pocketnet_create_checkpoint` repo (epic child delt.3). This chunking document treats Chunk 1 as a contract: the doctor depends on the chunk store conforming to the pre-spec's Implementation Context. The contract is enumerated below; the realization is in the sibling repo.

### Prior artifact boundaries

- Pre-spec v0.3.1 — source of truth for what the doctor expects from the manifest and chunk store.
- Existing `pocketnet_create_checkpoint` workflow — produces full-snapshot tarballs today; this chunk extends, not replaces.

### Functional contract (chunk-specific FRs)

These are not pre-spec FRs (the pre-spec is doctor-side). They are integration contracts derived from doctor expectations.

- **CR1-001** Chunk-store HTTPS endpoint serves a JSON manifest at a stable URL for each published canonical block height. Manifest carries `block_height`, `pocketnet_core_version`, `created_at`, and a list of per-file entries.
- **CR1-002** Per-file entries for `main.sqlite3` enumerate page-level hashes at the 4 KB SQLite page boundary, addressable by `(path, offset)`.
- **CR1-003** Per-file entries for non-SQLite artifacts (`blocks/`, `chainstate/`, `indexes/`, any others) carry whole-file SHA-256 hashes.
- **CR1-004** Chunk URLs are addressable as discrete HTTPS GETs; per-page chunks for `main.sqlite3` and per-file chunks for everything else.
- **CR1-005** Server honors `Accept-Encoding: zstd` and `Accept-Encoding: gzip`; payloads are pre-compressed and cached server-side.
- **CR1-006** SHA-256 of the canonical-form manifest is published alongside the manifest as the trust-root constant. Doctor builds compile this constant in.
- **CR1-007** Manifest declares the `change_counter` SQLite header value for `main.sqlite3` so doctor's pre-flight ahead-of-canonical check (FR-011) has a reference.
- **CR1-008** Server publishes manifests no older than 30 days (operational invariant the doctor relies on).

### Edge cases owned

None directly from pre-spec EC list. Server-side EC behavior (e.g., mid-publish failures, partial uploads, mirror divergence) is addressed in delt.3 itself, not here.

### Behavioral criteria

- A doctor binary built against the trust-root for canonical at block height H can authenticate that exact manifest and only that manifest. A swapped or tampered manifest fails authentication.
- Two doctor binaries built against the same trust-root see the same canonical when both fetch the manifest URL.
- The chunk store survives concurrent fetches at typical operator scale (dozens of simultaneous recoverers).

### Testable success criteria

The pre-spec's SCs are doctor-side. This chunk's success criteria are integration-level and feed Gate 1 → 2:

- **CSC1-001** All four Gate 1 → 2 predicates pass for a canonical published by the server-side workflow.
- **CSC1-002** Drill prerequisite: at least one canonical is published whose block height is suitable for the Chunk 4 drill (PSA-11-F06 deferral lands here).

### Speckit Stop Resolutions

- **Plan-stage / language and runtime for the manifest generator.** Use the existing `pocketnet_create_checkpoint` workflow's language and runtime (whatever shell/Python/Go it currently runs in). Do not introduce a new language for this chunk; extend the existing tooling.
- **Plan-stage / chunk-store hosting topology.** Use the same hosting channel as today's full-snapshot distribution (project-pinned publisher's HTTPS endpoint). Out of v1 scope: CDN, mirror network, third-party hosting.
- **Plan-stage / compression choice on the server side.** Pre-compress chunks with both Zstandard and gzip; serve per `Accept-Encoding`. This aligns with the pre-spec Implementation Context's client-side decoder selection.
- **Tasks-stage / canonical-form serialization for trust-root hash.** Sort manifest JSON keys, no insignificant whitespace, UTF-8. Same canonical-form rule as the plan artifact's self-hash to keep the doctor's hash machinery uniform.
- **Plan-stage / drill canonical source (PSA-11-F06).** A canonical published by this chunk is the drill canonical for Chunk 4. The drill rig's doctor binary is built against this canonical's trust-root. No private-fixture canonical is needed.

### What this chunk unblocks

- Chunk 2 may begin diagnose-side dev against a mock chunk store immediately and pivot to the real chunk store at Gate 1 → 2.
- Chunk 3 cannot begin until this chunk merges (apply must verify against real manifest hashes, not mock).
- Chunk 4 drill scenario requires this chunk's published canonical.

---

## Chunk 2: Client Foundation + Diagnose

### Scope

The doctor's read-only pathway plus the foundational scaffolding both phases share:

- Project skeleton (binary entry point, CLI argument parsing, exit-code allocation, logging surface).
- Plan-format library (JSON serialization, canonical-form hashing, self-hash verification, format-version handling).
- Manifest verifier (fetches manifest, computes SHA-256, compares to compiled-in trust-root, parses verified manifest).
- Hash utilities (SHA-256 for chunks, files, manifests; consistent canonical-form rule).
- Diagnose phase (US-001): page-level diff for `main.sqlite3`, whole-file diff for the rest, plan emission, human-readable summary.
- All four pre-flight refusal predicates (US-003): running-node check, ahead-of-canonical check, version mismatch, volume capacity check (FR-010..013) plus the new permission/read-only check (EC-011).
- Trust-root authentication (FR-017, FR-018).

### Prior artifact boundaries

- Pre-spec v0.3.1 — source of truth.
- Chunk 1's published trust-root constant — compiled into the doctor binary at build time.
- Chunk 1's manifest contract — diagnose consumes manifests that conform to it.

### Functional requirements owned

- **FR-001** through **FR-005** (diagnose surface).
- **FR-010** through **FR-013** (refusal predicates).
- **FR-017** and **FR-018** (trust-root authentication and forward-compatibility).

### Edge cases owned

- **EC-001** Local pocketdb missing entirely.
- **EC-002** Local pocketdb partially present (diagnose side; apply side flows into Chunk 3).
- **EC-004** Local `main.sqlite3` locked by non-`pocketnet-core` process — treat as running-node refusal.
- **EC-008** Manifest hash verification fails.
- **EC-011** Volume permission refusal.

### Behavioral criteria

- Diagnose performs zero writes to `pocketdb/`; the diagnose phase is observably read-only by an external process monitor.
- Pre-flight predicates run before any pocketdb byte is read; a refusal short-circuits with no I/O against the pocketdb.
- Plan emission is deterministic given identical inputs (same local pocketdb + same canonical manifest produces byte-identical `plan.json`).
- Trust-root mismatch refuses without any chunk-store byte fetch.

### Testable success criteria

- **SC-001** On a node 30 days behind canonical, diagnose completes within 5 minutes on the reference rig and emits a plan whose total fetch size is ≤ 25% of full-snapshot size.
- **SC-002** On a node identical to canonical, diagnose emits a zero-entry plan and exits cleanly within 5 minutes.
- **SC-006** Each refusal predicate blocks with a distinct exit code and a diagnostic naming the predicate; no bytes are modified.
- **CSC2-001** Plan self-hash round-trip: emitted plan's `self_hash` field equals the SHA-256 over its canonical-form payload (with `self_hash` removed).
- **CSC2-002** Plan canonical identity round-trip: a manifest hash mismatch between two diagnoses produces plans with different `canonical_identity` blocks.

### Speckit Stop Resolutions

- **Plan-stage / language and runtime.** The doctor binary is implemented in a language that produces a single static binary suitable for distribution to operators on Linux, macOS, and Windows without runtime dependencies. Specific language choice (Go, Rust, Zig) is a plan-stage decision; the constraint is "single static binary, three platforms." Pre-spec Implementation Context permits this latitude.
- **Plan-stage / CLI surface.** The CLI surface uses subcommands (`diagnose`, `apply`) and reserves namespace for a future `apply --full` mode that subsumes full-checkpoint download (per pre-spec Stage 4 hand-off note). Do not collapse subcommands into flags-on-a-single-command; subcommand structure is the extensibility surface.
- **Clarify-stage / plan filename and location.** `plan.json` written alongside the operator's pocketdb-parent directory by default, overrideable with `--plan-out <path>`. The plan is the output artifact; the pocketdb directory is the input.
- **Plan-stage / progress reporting on long diagnose runs.** Diagnose emits progress to stderr at file-class boundaries (`main.sqlite3` page hashing, `blocks/` file hashing, etc.) so operators on long pocketdbs see liveness. Format is human-readable; not a structured machine protocol.
- **Plan-stage / configuration storage.** No user-config file in v1. Behavior controlled by CLI flags only. Trust-root is compiled in, not configurable. Defers configuration-file design until a real need surfaces.
- **Tasks-stage / pre-flight predicate ordering.** Predicates execute in the order: running-node check → version-mismatch check → volume-capacity check → permission/read-only check → ahead-of-canonical check. The ahead-of-canonical check requires reading `main.sqlite3` headers, so it runs last among pre-flights. This ordering minimizes work-before-refusal.

### What this chunk unblocks

- Chunk 3 (apply) can begin once the plan format is stable.
- Operators can run `pocketnet-node-doctor diagnose` and see what their recovery would entail without any mutation risk.
- Stage 4 drill setup can pre-validate the canonical's diagnose output before the apply phase exists.

---

## Chunk 3: Client Apply

### Scope

The doctor's mutating pathway:

- Apply phase (US-002): consume plan, fetch chunks, stage with shadow copies, verify pre-rename, atomic rename into live tree, post-apply verification, rollback on failure.
- Verification (US-004): pre-rename per-chunk SHA-256 against manifest; post-apply whole-file SHA-256 + SQLite native consistency check.
- Network resilience primitives (FR-019, FR-020): bounded retry with jittered exponential backoff; resumability via per-chunk completion markers in staging.

### Prior artifact boundaries

- Chunk 1's chunk store and manifest contract.
- Chunk 2's plan format, plan-format library, manifest verifier, hash utilities, pre-flight refusal predicates.
- Pre-spec v0.3.1 Implementation Context — the rollback-shadow-copy mechanism, atomic-rename mechanism, retry algorithm, parallelism cap.

### Functional requirements owned

- **FR-006** through **FR-009** (apply mutating).
- **FR-014** through **FR-016** (verification + rollback).
- **FR-019** and **FR-020** (network resilience).

### Edge cases owned

- **EC-002** Apply-side handling for partially-present pocketdb (full-fetch sub-plan).
- **EC-003** Canonical chunk store unreachable at apply time.
- **EC-005** Plan generated against a superseded canonical — warn and offer re-diagnose.
- **EC-006** Two consecutive apply runs against the same plan on a recovered node.
- **EC-007** Disk I/O fault during apply — fatal, attempt rollback, exit non-zero.
- **EC-009** Plan file tampered (self-hash mismatch).
- **EC-010** Apply succeeds but `pocketnet-core` fails to start (out of doctor scope; reported as apply success).

### Behavioral criteria

- At any observable instant during apply, every byte of `pocketdb/` either matches canonical bitwise or matches the pre-apply state. No mixed-version intermediate is observable from outside the staging area.
- Promotion of an unverified chunk into the live tree is impossible by construction (verification is a precondition for the atomic rename, not a post-hoc check).
- Rollback restores the pocketdb's pre-apply state from per-file shadow copies via reverse rename.
- Disk-cost ceiling for apply: pre-apply plan-listed-files-size × 2 (worst case all listed files exist locally and shadow copies are needed) plus the staging area for fetched chunks.
- Apply is idempotent on a recovered node: running apply twice with the same plan yields the same final state and the second run finds zero residual work.

### Testable success criteria

- **SC-003** Apply against a valid plan results in a `pocketdb/` whose every file's hash matches the canonical manifest, and `PRAGMA integrity_check` returns "ok".
- **SC-004** Mid-apply interruption (process killed during fetch) followed by re-invocation completes successfully without re-fetching previously-fetched chunks.
- **SC-005** Post-apply verification failure (chunk store served wrong byte) results in observable rollback: every file's hash matches the pre-apply state, tool exits non-zero.

### Speckit Stop Resolutions

- **Plan-stage / staging directory location.** A subdirectory `pocketnet-node-doctor-staging/` adjacent to `pocketdb/` (same parent), deleted on success, retained on failure for forensics. The same volume holds staging and live tree so atomic `rename(2)` is permissible.
- **Plan-stage / shadow-copy strategy.** Per-file shadow taken at staging time before the file is touched. Shadow lives in the staging directory under a deterministic subpath. On failure, shadows are renamed back into place (reverse atomic rename); on success, shadows are deleted with the staging directory.
- **Plan-stage / completion-marker format.** One zero-byte file per fetched-and-verified chunk, named after the chunk's canonical identifier (path + offset for page entries; path for file entries) in a `markers/` subdirectory of staging. Re-running apply reads the marker set first and skips already-completed chunks.
- **Plan-stage / retry budget shape.** Per-chunk retry budget: 5 attempts with exponential backoff (250 ms → 500 ms → 1 s → 2 s → 4 s) with ±25% jitter. Per-chunk failure becomes run-level failure when the budget is exhausted; no run-level retry budget separately.
- **Plan-stage / parallelism implementation.** A worker pool of size 4 (configurable via `--parallel <N>`) consuming a queue of chunks-to-fetch. Verification + atomic-rename promotion happens on the main thread to preserve ordering and atomicity at file boundary.
- **Plan-stage / `pocketnet-core` start verification scope.** Apply does not invoke `pocketnet-core` directly. Apply success is `pocketdb/` matches canonical bitwise + integrity_check passes. Whether `pocketnet-core` subsequently starts is the operator's responsibility (per pre-spec Out of Scope and EC-010).
- **Tasks-stage / staged-chunk verification mechanism.** SHA-256 of the staged chunk's bytes equals the manifest's recorded hash for that chunk, computed before the rename system call is issued. Failure → discard the staged chunk, retry per the budget. Budget exhaustion → run-level failure → rollback.
- **Plan-stage / Content-Encoding negotiation.** Apply's HTTP client sends `Accept-Encoding: zstd, gzip`. Server returns the preferred encoding; client decompresses transparently before hashing. Hash is over the uncompressed payload (matches what the manifest records).

### What this chunk unblocks

- Operators can complete a real recovery against a real canonical.
- Chunk 4's drill scenario: a deliberately damaged node restored to canonical-matching state.
- `pocketnet_recover_checkpoint` users have a delta-mode alternative for recovery.

---

## Chunk 4: End-to-End Drill + Network Resilience + Release Polish

### Scope

Three sub-areas combined into one chunk because they are all post-MVP hardening on top of a working diagnose+apply:

1. **End-to-end recovery drill (US-005).** A deliberately damaged node, recovered to a known-good state, validated by `pocketnet-core`'s `getbestblockhash` RPC.
2. **Intermittent-network hardening (US-006).** Apply over connections that drop, with the resilience primitives from Chunk 3 actually exercised under simulated failures.
3. **Release polish.** Signed releases, multi-platform binaries (Linux, macOS, Windows), troubleshooting documentation, public download channel, version-pinning for the trust-root constant.

### Prior artifact boundaries

- Working doctor from Chunks 2 and 3.
- A real published canonical from Chunk 1 at a block height suitable for the drill.
- A project-internal test node available for the drill (per One-Time Setup Checklist).

### Functional requirements owned

No new FRs. This chunk validates and packages the FRs from prior chunks.

### Edge cases owned

None new. All ECs are owned by Chunks 2 or 3.

### Behavioral criteria

- A deliberately damaged node (zeroed pages in `main.sqlite3`, truncated `blocks/` file, etc.) recovers to a state where `pocketnet-core` starts and reports a block at or descended from the canonical's pinned block height.
- Apply on a 4 GB total-fetch with simulated 256 MB-spaced network drops completes via re-invocation without operator intervention beyond running the doctor again.
- Released binaries are reproducibly built from a tagged source revision and signed by the project-pinned publisher's release key.
- Release artifacts are downloadable via the same channel as today's full-snapshot distribution (consistency with `pocketnet_recover_checkpoint`).

### Testable success criteria

- **SC-007** End-to-end recovery drill restores the node so `pocketnet-core`'s `getbestblockhash` RPC returns a block at or descended from the canonical's pinned block height.
- **SC-008** Apply over an intermittent network connection (simulated drops every 256 MB on a 4 GB total fetch) completes the recovery without operator intervention beyond re-invocation.
- **CSC4-001** Released binaries match a documented checksum and are signed by a published key.
- **CSC4-002** Troubleshooting guide covers each refusal exit code (per FR-010..013, EC-011) with the operator's correct response.

### Speckit Stop Resolutions

- **Plan-stage / drill node provisioning.** The drill runs on a project-internal test node managed under virtual-machine-snapshot discipline. Pre-drill snapshot captured; post-drill the snapshot is restored if the drill is re-run. Drill instrumentation (damage-injection script, observation of `getbestblockhash`) is committed to `experiments/02-recovery-drill/` for reproducibility.
- **Plan-stage / network-drop simulation tooling.** Use `tc` (Linux Traffic Control) or equivalent to inject packet loss / connection resets at the OS level on the drill host. Avoid in-binary instrumentation that bypasses the doctor's real network code path.
- **Plan-stage / release artifact hosting.** Hosted on the project-pinned publisher's HTTPS endpoint, same channel as full-snapshot distribution. GitHub Releases mirrors the artifacts for community discoverability.
- **Plan-stage / signing scheme.** Release binaries signed with a long-lived publisher key whose public component is published in the project README and the pinned-trust-root location. Operators verify the binary signature before running. v1 does not implement on-doctor self-update; that is a post-v1 concern.
- **Plan-stage / Windows installer.** Out of v1: installer / MSI / store distribution. v1 ships a signed `.exe` for Windows that runs from `cmd` or PowerShell. Installer is a delt.7 follow-up.
- **Tasks-stage / drill canonical provenance.** The drill canonical is produced by Chunk 1's server-side workflow. Block height is pinned in the drill instrumentation. Re-running the drill against a different block height requires updating the drill instrumentation; this is intentional friction to preserve drill reproducibility.

### What this chunk unblocks

- Public release of `pocketnet-node-doctor` v1 to operators.
- Community contributions begin in earnest (the codebase is at a state worth reading).
- Roadmap discussion: doctor `apply --full` mode subsuming the full-checkpoint download path; chain-anchored manifest verification; healthy-peer cross-check.

---

## Per-Chunk Addenda

Per-chunk validation items beyond the integration-gate checklists above. These are quality gates that apply within or after each chunk's implementation; they do not block the next chunk's start (gates do that), but they must clear before the chunk itself is considered merged.

### Chunk 1 addenda

- [ ] **Manifest schema documented** in `pocketnet_create_checkpoint` repo so future canonical formats can preserve compatibility intentionally.
- [ ] **Trust-root constant publication channel documented** so doctor builds can pin the right value at build time.
- [ ] **Smoke test:** at least one published canonical's manifest fetched and trust-root-verified by an out-of-band consumer (curl + sha256sum) before any doctor build consumes it.

### Chunk 2 addenda

- [ ] **Plan-format library has unit tests** covering canonical-form serialization, self-hash round-trip, format-version field handling, and tampering detection (mutate a single byte of the divergence list and confirm self-hash mismatch).
- [ ] **Manifest-verifier unit tests** include the trust-root mismatch case (correct refusal, no chunk-store fetch attempted).
- [ ] **Pre-flight predicate unit tests** cover each of the five conditions in isolation; integration test confirms the documented ordering.
- [ ] **Diagnose progress output** is human-readable on a real terminal; a 5-minute run on the reference rig does not produce silent stretches > 30 seconds.
- [ ] **CLI exit codes** documented in `--help` output and in the troubleshooting guide (lands at Chunk 4 but contract pinned here).

### Chunk 3 addenda

- [ ] **Apply unit tests** cover the rollback path on simulated mid-rename failure, on simulated post-rename verification failure, and on simulated mid-fetch failure.
- [ ] **Resumability test** kills the apply process at three points (first chunk fetched, half chunks fetched, all chunks fetched but pre-rename) and confirms re-run completes without redundant fetches in each case.
- [ ] **Integrity-check failure injection** (e.g., synthetic SQLite corruption introduced post-rename) confirms `PRAGMA integrity_check` failure triggers rollback even if all per-chunk hashes verified.
- [ ] **Disk-cost measurement** on a representative apply run records observed peak (`pocketdb` size + staging size + shadow size) for the troubleshooting guide.
- [ ] **Concurrency stress test** at `--parallel 4` (default) and `--parallel 16` confirms no chunk-promotion ordering anomaly under load.

### Chunk 4 addenda

- [ ] **Drill runbook authored** at `experiments/02-recovery-drill/RUNBOOK.md` covering damage injection, doctor invocation, observation, and snapshot restore.
- [ ] **Drill executed** on the project-internal test node under virtual-machine snapshot discipline; pass/fail recorded.
- [ ] **Network-drop test** executed and recorded; SC-008 confirmed.
- [ ] **Release artifacts published and signature-verified** by an out-of-band party (sanity check that operators can verify too).
- [ ] **README updated** to "v1 released" and points operators at the download channel.
- [ ] **Troubleshooting guide complete** covering each refusal exit code, common operator errors, and recovery steps from a failed apply.
- [ ] **Open issues filed** for known v1 limitations (Windows installer, on-binary self-update, chain-anchored verification) with explicit roadmap commitments.

---

## Companion Document

Stage 5 audits this chunking against [`audit-criteria.md`](../../docs/pre-spec-build/audit-criteria.md) — particularly **CSA-11 (Chunking-level SpecKit Stop Coverage)**, the chunking-level analogue of PSA-11. The audit verifies every chunk's inventoried stops are answered either by pre-spec inheritance or by the chunk's `### Speckit Stop Resolutions`.
