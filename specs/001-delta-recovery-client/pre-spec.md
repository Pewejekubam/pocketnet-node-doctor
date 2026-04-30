---
version: 0.2.1
status: draft
created: 2026-04-29
last_modified: 2026-04-29
authors: [david, claude]
related: ../../docs/pre-spec-build/process.md
changelog:
  - version: 0.2.1
    date: 2026-04-29
    summary: Public-consumption scrub — remove server-internal absolute paths, internal hostnames, and a stale US reference
    changes:
      - "Implementation Context sibling-project references reduced to bare repo names; absolute filesystem paths removed"
      - "Test target node generalized to 'a project-internal test node'; specific hostname removed"
      - "Operator name in narrative replaced with role-neutral 'project maintainer'"
      - "Fixed stale US-006 reference in Test target paragraph (drill is US-005 after the v0.2.0 renumber)"
  - version: 0.2.0
    date: 2026-04-29
    summary: Remove plan-sharing user story and supporting FRs/SCs; reframe canonical-publisher trust hardening as post-v1
    changes:
      - "Removed US-004 (community plan-sharing); plan remains a durable, self-describing artifact for diagnose↔apply, but cross-operator sharing is no longer a v1 user story"
      - "Removed FR-017, FR-018 (plan portability / plan comparison); renumbered downstream FRs accordingly"
      - "Removed SC-007, SC-008, SC-009 (plan-comparison success criteria); renumbered downstream SCs"
      - "Stripped 'shareable' / 'portability' / 'community' framing from Vision, Design Principles, Key Entities, EC-005"
      - "Strengthened Design Principle 6: names chain-anchored verification AND healthy-peer cross-check as known post-v1 paths to harden canonical-publisher trust"
      - "Added Out-of-Scope entry: canonical-publisher trust verification via healthy-peer cross-check (deferred feature, captured so it does not get lost)"
      - "Disambiguated 'block height' → 'pocketnet block height' in Vision and Design Principles"
  - version: 0.1.0
    date: 2026-04-29
    summary: Initial pre-spec — delta recovery client for pocketnet operators recovering dead/corrupted nodes
    changes:
      - "Persona pinned to recovery-driven (panic-mode) operator"
      - "v1 surface = full pocketdb/ tree; main.sqlite3 via 4 KB page diff, other artifacts via whole-file hash"
      - "Frozen-canonical diff rule: any bitwise mismatch → fetch (no drift-vs-corrupt discrimination)"
      - "Diagnose emits machine-readable plan; apply consumes the plan; plans are shareable across operator community"
      - "Trust root: project-pinned canonical publisher; cryptographic derivation to public blockchain as Design Principle"
      - "Hard refusals: node running, ahead-of-canonical, version mismatch, insufficient volume capacity"
      - "Atomicity: staging + atomic rename; partial runs resumable; post-apply integrity_check + SHA-256 gate; failure → rollback"
      - "Canonical checkpoint freshness invariant ≤ 30 days (operational policy doctor relies on)"
---

# Pre-Spec: Delta Recovery Client for Pocketnet Operators

## Purpose

Pocketnet operators today recover from local data corruption or storage loss by downloading a full ~60 GB blockchain snapshot. This pre-spec scopes a CLI tool — `pocketnet-node-doctor` — that lets an operator restore a dead or corrupted node by downloading only the byte-level differences between their local `pocketdb/` and a canonical checkpoint. Empirical validation on a March → April interval shows 85.83% page-level reuse on `main.sqlite3` at SQLite's 4 KB page boundary, projecting an operator wire cost of ~13–15 GB compressed against a ~60 GB full-snapshot baseline (4–5× bandwidth reduction).

The feature ships as two operator-invoked modes — **diagnose** (read-only health check, emits a machine-readable plan) and **apply** (consumes the plan, atomically swaps differing chunks into place, verifies integrity, refuses-and-rolls-back on failure). The plan artifact is durable and self-describing so that diagnose and apply are independently invocable, partial apply runs are resumable against the same plan, and the plan provides an audit trail of what was changed during recovery.

## Vision

A pocketnet operator with a node that won't start runs `pocketnet-node-doctor diagnose`, gets a plan in seconds, runs `pocketnet-node-doctor apply`, and is back online within one or two hours of wire time instead of overnight. The operator does not learn SQLite internals. The operator does not edit a config file. The operator does not need to coordinate with a publisher. The tool's contract is that any deviation from the canonical bytes — drift, corruption, partial write, bit rot — is treated identically: the operator's local bytes must match canonical bitwise after a successful apply, or the run rolls back and the local node is left in its pre-apply state.

## Fire-and-Forget Execution: Intent Is Pre-Ratified

This pre-spec is the input to the speckit pipeline. Every clarification the speckit pipeline could raise (clarify-stage ambiguity, plan-stage technology choice, tasks-stage decomposition, analyze-stage coverage gap) must be resolvable from text in this document or in the chunking document derived from it. Native decision points covered here include the trust model, the diff rule, the refusal set, atomicity guarantees, version-skew handling, and the boundary between in-scope and out-of-scope concerns. Decision points that depend on chunk-level framing (e.g., what verification instrument confirms apply correctness for `chainstate/` vs. `main.sqlite3`) are deferred to the chunking document's per-chunk Speckit Stop Resolutions.

---

## Design Principles

These constrain every functional requirement and inform every plan-stage decision.

1. **Frozen canonical, no relativism.** The canonical checkpoint is a point-in-time artifact. There is no "stale" or "fresh." Any local byte that differs from canonical is overwritten with canonical. Drift, corruption, and partial writes are one bucket.
2. **Recovery, not reconciliation.** The doctor restores a dead or corrupted node toward a canonical baseline. It does not roll a healthy node backward, does not merge competing chains, does not arbitrate divergence. The contract is one-way: canonical → local.
3. **Diagnose is read-only; apply is atomic.** Diagnose touches no bytes. Apply stages downloads, fsyncs, then renames into place. A partial apply leaves the node in its pre-apply state — never a mixed-version intermediate.
4. **Refuse loudly, mutate carefully.** Pre-flight predicates that would make the operation destructive are hard refusals with diagnostic exit codes — not warnings, not prompts. Once predicates pass, mutation is committed.
5. **Plan is durable and self-describing.** The plan emitted by diagnose is a self-contained artifact. It carries the canonical identity it was computed against, can be archived for audit, and is the durable state that makes apply phases resumable across interruptions.
6. **Trust derives from the chain, eventually.** v1 trusts a project-pinned canonical publisher (HTTPS + SHA-256 manifest). The Design Principle is that trust must over time be hardened against a bad-actor publisher impersonating the canonical mirror. Two known paths exist for that hardening: (a) cryptographic derivation of manifest hashes from on-chain pocketnet state, and (b) cross-checking a candidate canonical against the local pocketdb of a trusted healthy peer at a known pocketnet block height. v1 implements neither; the architecture must not foreclose either.
7. **Pocketnet-only scope.** The tool inspects pocketnet artifacts. It does not perform disk diagnostics, filesystem repair, or OS health checks. Volume capacity is the only OS-level surface.
8. **Bandwidth proportional to damage.** A node behind by a small interval pulls a small delta. A node with widespread corruption pulls a large delta. A node identical to canonical pulls zero bytes and exits cleanly.

---

## Key Entities

These domain objects are referenced by multiple FRs.

- **Canonical Checkpoint** — A point-in-time snapshot of `pocketdb/` published by a trusted authority, frozen at a specific pocketnet block height, built against a specific `pocketnet-core` version, and ≤ 30 days old by operational policy. Comprises (a) the full `pocketdb/` tree, (b) a manifest, (c) a chunk store.
- **Manifest** — A signed (or hash-rooted) document that describes the canonical checkpoint. Carries: pocketnet block height, pocketnet-core version, per-file metadata, and per-page hashes for `main.sqlite3` plus whole-file hashes for `blocks/`/`chainstate/`/`indexes/`/other artifacts.
- **Chunk Store** — The HTTP-addressable byte source from which the doctor fetches differing chunks. Pages of `main.sqlite3` are addressable at 4 KB granularity; non-SQLite files are addressable at file granularity.
- **Plan** — A machine-readable artifact produced by diagnose. Lists the set of byte ranges (page offsets for `main.sqlite3`; whole files for the rest) that diverge between local and canonical, plus the canonical hashes the apply phase will verify against. Carries the canonical identity it was computed against and is the durable state that makes apply phases resumable across interruptions.
- **Local Node State** — The contents of `pocketdb/` on the operator's disk plus the running/stopped status of the `pocketnet-core` process. Read-only during diagnose; mutated only during apply, only via staging + atomic rename.
- **Run Artifact** — Output of an apply run. Contains: plan id, start/end times, bytes fetched, post-apply verification result (pass/fail), rollback status if applicable.

---

## User Stories

User stories are priority-ordered (P1 = ships v1 critical path; P2 = ships v1 if time permits; P3 = follow-on).

### US-001: Diagnose a Dead Node (P1)

**Narrative.** An operator's pocketnet node has crashed or refuses to start. The operator runs `pocketnet-node-doctor diagnose --canonical <url> --pocketdb <path>`. Within minutes the operator receives (a) a human-readable summary on stdout naming what differs, what would be fetched, and how many bytes that represents; (b) a machine-readable `plan.json` written alongside the pocketdb path. The operator has not modified any byte on disk.

**Acceptance scenarios:**

- **Given** a stopped node with `pocketdb/main.sqlite3` 60 days behind the canonical checkpoint, **When** the operator runs diagnose, **Then** the tool produces a plan listing the differing pages, summarizes total bytes to fetch, and exits with code 0. No bytes in `pocketdb/` are modified.
- **Given** a stopped node identical to canonical, **When** the operator runs diagnose, **Then** the tool produces a plan with zero entries, prints "no recovery needed," and exits with code 0.
- **Given** a stopped node with corrupted `main.sqlite3`, **When** the operator runs diagnose, **Then** the tool produces a plan covering the corrupt pages without distinguishing them from drifted pages.

### US-002: Apply a Plan to Restore the Node (P1)

**Narrative.** The operator has a plan from US-001. They run `pocketnet-node-doctor apply --plan plan.json`. The tool fetches the differing chunks from the canonical chunk store, stages them, atomically swaps them into place, runs post-apply verification (SHA-256 against manifest, `PRAGMA integrity_check` on `main.sqlite3`), and reports success or rolls back.

**Acceptance scenarios:**

- **Given** a valid plan against an unchanged local pocketdb, **When** the operator runs apply, **Then** all differing bytes are fetched, swapped in atomically, post-apply verification passes, and the node starts cleanly.
- **Given** a valid plan and the apply phase is interrupted (power loss, kill -9) mid-fetch, **When** the operator re-runs apply with the same plan, **Then** the run resumes and completes; the local pocketdb is never in a mixed-version state at any observable instant.
- **Given** a valid plan and post-apply `PRAGMA integrity_check` fails, **When** apply detects the failure, **Then** the operator's pre-apply pocketdb state is restored, no partial write is left visible, and the tool exits with a diagnostic non-zero code.

### US-003: Refuse to Damage a Healthy or Running Node (P1)

**Narrative.** The operator (perhaps mistakenly) runs the doctor on a node that should not be touched: the `pocketnet-core` process is running, or the local block height is ahead of canonical, or the local pocketnet-core binary version does not match the canonical's, or the volume lacks free space for the staging area. The doctor refuses without modifying anything and prints a diagnostic explaining which predicate failed.

**Acceptance scenarios:**

- **Given** `pocketnet-core` is running, **When** the operator invokes diagnose or apply, **Then** the tool refuses, prints "node is running; stop it before recovery," and exits non-zero. No bytes read, no bytes written.
- **Given** a stopped node whose `main.sqlite3` header `change_counter` exceeds the canonical's, **When** the operator invokes apply, **Then** the tool refuses, prints "local node is ahead of canonical; doctor only restores dead or behind nodes," and exits non-zero.
- **Given** a canonical manifest pinned to pocketnet-core vX.Y and a local install of vX.Z, **When** the operator invokes diagnose, **Then** the tool refuses, prints the version mismatch, and exits non-zero.
- **Given** insufficient free space on the volume holding `pocketdb/`, **When** the operator invokes apply, **Then** the tool refuses up front, names the shortfall in bytes, and exits non-zero.

### US-004: Verify Apply Outcome Against Canonical (P1)

**Narrative.** After apply, the operator wants definitive evidence the local pocketdb now matches canonical bitwise. The doctor's post-apply verification — SHA-256 of every file (or per-page hash for `main.sqlite3`) against the manifest, plus `PRAGMA integrity_check` on `main.sqlite3` — is the authoritative gate. If verification fails, apply is treated as failed and rolled back.

**Acceptance scenarios:**

- **Given** apply completes, **When** post-apply verification runs, **Then** every file's hash matches the manifest and `PRAGMA integrity_check` returns "ok"; the run is reported successful.
- **Given** apply completes but a file hash diverges from manifest, **When** post-apply verification fails, **Then** the pre-apply state is restored, the failure is logged with the diverging file/offset, and the tool exits non-zero.
- **Given** apply completes but `PRAGMA integrity_check` returns a non-"ok" result, **When** post-apply verification fails, **Then** the same rollback path executes and the SQLite-reported issue is included in the diagnostic.

### US-005: Run an End-to-End Recovery Drill (P2)

**Narrative.** A node operator (or the project maintainer) wants to validate the doctor against a real-world scenario before relying on it. They take a known-good node, deliberately damage `pocketdb/main.sqlite3` (e.g., zero out a range of pages, truncate a `blocks/` file), then run diagnose + apply against a known canonical and verify recovery.

**Acceptance scenarios:**

- **Given** a damaged node, **When** the drill runs diagnose then apply against a known canonical, **Then** the recovered pocketdb is bitwise-identical to the canonical at the recovered block height.
- **Given** a node that lost 1 GB of `chainstate/` files, **When** the drill runs, **Then** all missing files are restored at file granularity and integrity check passes.
- **Given** a damaged drill node, **When** the drill is run twice in succession (after first recovery), **Then** the second diagnose reports zero pending changes.

### US-006: Operate Behind Slow or Intermittent Networks (P3)

**Narrative.** Operators on residential or constrained connections need apply to survive transient network failures, slow links, and resumed sessions without re-fetching what they already have.

**Acceptance scenarios:**

- **Given** apply is fetching a 4 GB delta on a 10 Mbps link, **When** the connection drops mid-fetch, **Then** re-running apply with the same plan resumes from the last completed chunk without re-fetching.
- **Given** the chunk store returns 5xx for a fetch, **When** apply encounters the error, **Then** the tool retries with backoff and ultimately either succeeds or exits cleanly with the network error preserved in the run artifact.

---

## Functional Requirements

Each FR backs one or more US. FRs describe outcomes; concrete technologies live in Implementation Context.

### Diagnose (read-only health check)

- **FR-001** Doctor reads `pocketdb/main.sqlite3` at canonical 4 KB page boundaries and computes a per-page hash that can be compared against manifest entries. (Backs US-001.)
- **FR-002** Doctor reads non-SQLite artifacts under `pocketdb/` (`blocks/`, `chainstate/`, `indexes/`, any other files in the canonical) at whole-file granularity and computes a whole-file hash that can be compared against manifest entries. (Backs US-001.)
- **FR-003** Doctor produces a machine-readable plan listing every divergence — page offsets for `main.sqlite3`, file paths for the rest — with the canonical hash each item must equal after apply. The plan carries the canonical identity (block height, manifest hash, pocketnet-core version) it was computed against. (Backs US-001, US-002, US-004.)
- **FR-004** Doctor emits a human-readable summary alongside the plan: total entries, total bytes-to-fetch, breakdown by artifact class, ETA estimate. (Backs US-001.)
- **FR-005** Doctor's diagnose phase performs zero writes to `pocketdb/` or any descendant; diagnose is observably read-only. (Backs US-001.)

### Apply (mutating recovery)

- **FR-006** Doctor consumes a plan and fetches each listed chunk from the canonical chunk store via HTTP. (Backs US-002.)
- **FR-007** Doctor stages every fetched chunk in a separate location, fsyncs it, and only promotes it into place via an atomic rename. (Backs US-002.)
- **FR-008** Doctor's apply phase is resumable: re-running with the same plan against a partially-applied pocketdb continues from where the prior run stopped without redundant fetches. (Backs US-002, US-006.)
- **FR-009** Doctor's apply phase preserves a snapshot of pre-apply state sufficient to restore on failure; on any verification failure or unrecoverable apply error, the pre-apply state is restored before exit. (Backs US-002, US-004.)

### Refusal predicates (pre-flight)

- **FR-010** Doctor refuses to run if a `pocketnet-core` process is currently using `pocketdb/` (lockfile or process check). (Backs US-003.)
- **FR-011** Doctor refuses to run apply if the local `main.sqlite3` header `change_counter` exceeds the canonical's. (Backs US-003.)
- **FR-012** Doctor refuses to run if the local `pocketnet-core` binary version differs from the version recorded in the canonical manifest. (Backs US-003.)
- **FR-013** Doctor refuses to run apply if the volume holding `pocketdb/` lacks sufficient free space for the staging area; the shortfall is reported in bytes. (Backs US-003.)

### Verification (post-apply gate)

- **FR-014** Doctor verifies every file written during apply matches the canonical manifest hash bitwise. (Backs US-004.)
- **FR-015** Doctor runs `PRAGMA integrity_check` on `main.sqlite3` after apply and treats any non-"ok" result as a verification failure. (Backs US-004.)
- **FR-016** A verification failure triggers automatic rollback to pre-apply state and a non-zero exit. (Backs US-002, US-004.)

### Trust and integrity

- **FR-017** Doctor verifies the canonical manifest's authenticity against a project-pinned trust root before consuming any of its hashes. (Backs US-002, US-004.)
- **FR-018** The manifest format does not foreclose adding chain-anchored manifest verification or healthy-peer cross-check verification in a future version. (Backs US-002.)

### Network resilience

- **FR-019** Apply retries transient HTTP failures (5xx, connection reset, timeout) with bounded exponential backoff before treating the run as failed. (Backs US-006.)
- **FR-020** Apply preserves enough state across runs that a re-invocation skips already-fetched-and-verified chunks. (Backs US-006, US-002.)

---

## Success Criteria

Each SC traces to at least one US. SCs are observable and binary (pass/fail) at the pre-spec level; concrete numeric thresholds may be tightened in the spec.

- **SC-001** On a node 30 days behind canonical, diagnose completes within 5 minutes on commodity hardware and emits a plan whose total fetch size is ≤ 25% of full-snapshot size. (US-001.)
- **SC-002** On a node identical to canonical, diagnose emits a zero-entry plan and exits cleanly within 5 minutes. (US-001.)
- **SC-003** Apply against a valid plan results in a `pocketdb/` whose every file's hash matches the canonical manifest, and `PRAGMA integrity_check` returns "ok." (US-002, US-004.)
- **SC-004** A simulated mid-apply interruption (process killed during fetch) followed by re-invocation completes successfully without re-fetching previously-fetched chunks. (US-002, US-006.)
- **SC-005** A simulated post-apply verification failure (e.g., chunk store served a wrong byte) results in observable rollback: every file's hash matches the *pre-apply* state, and the tool exits non-zero. (US-002, US-004.)
- **SC-006** Each refusal predicate (running-node, ahead-of-canonical, version-mismatch, insufficient-space) blocks the operation with a distinct exit code and a diagnostic naming the predicate; no bytes are modified. (US-003.)
- **SC-007** An end-to-end recovery drill on a deliberately damaged node restores the node to a state where `pocketnet-core` starts cleanly and reports the canonical pocketnet block height as ancestor. (US-005.)
- **SC-008** Apply over an intermittent network connection (simulated drops every N MB) completes the recovery without operator intervention beyond re-invocation. (US-006.)

---

## Edge Cases

- **EC-001** Local pocketdb is missing entirely. Diagnose treats every canonical file as "not present locally," emits a plan equivalent to a full fetch. Apply restores from scratch. (Affects US-001, US-002.)
- **EC-002** Local pocketdb is partially present (e.g., `main.sqlite3` exists, `chainstate/` is missing). Diagnose handles missing files as full-file diffs. (US-001.)
- **EC-003** Canonical chunk store is unreachable at apply time. Apply exits cleanly with a network-error diagnostic, no partial writes. (US-002.)
- **EC-004** Local `main.sqlite3` is locked by an OS-level file lock that's not from `pocketnet-core`. Treat as the running-node refusal case (FR-010). (US-003.)
- **EC-005** Plan was generated against a canonical that has since been superseded by a newer canonical from the same publisher. Apply is still safe to run — the plan is bound to a specific canonical via manifest hash (FR-003) — but the operator should be informed. The doctor warns and offers to re-diagnose against the latest canonical. (US-002.)
- **EC-006** Two consecutive apply runs against the same plan on a successfully recovered node. The second run finds zero divergences and exits cleanly. (US-002, US-005.)
- **EC-007** Disk I/O error during staging (read-only filesystem, hardware failure). Apply treats it as a fatal error, attempts rollback, exits non-zero. The tool does not perform OS-level diagnostics. (US-002, US-003.)
- **EC-008** Manifest signature/hash verification fails. Apply refuses without consuming any chunk-store bytes. (US-002, US-004.)
- **EC-009** Plan file has been tampered with (hash mismatch against embedded self-hash). Apply refuses. (US-002.)
- **EC-010** Apply succeeds but `pocketnet-core` still won't start (some condition outside the doctor's scope, e.g., missing config). The doctor's exit code reports apply success; further diagnosis is the operator's responsibility. (US-002.)

---

## Implementation Context

This section is construction material for `speckit.plan`, not requirements for `speckit.specify`.

### Empirical baselines

- **Page-level reuse, March 3,745,867 → April 3,806,626 on `pocketdb/main.sqlite3`:** 32.86M of 38.29M 4 KB pages byte-identical at same offset (85.83%). Source: [`experiments/01-page-alignment-baseline/compare-output.log`](../../experiments/01-page-alignment-baseline/compare-output.log).
- **Projected operator wire bytes:** ~13–15 GB compressed against ~60 GB full-snapshot baseline (4–5× reduction).
- **Worst-case bracket (Feb → April) reuse rate:** to be measured (epic child `delt.5`); plan-stage technology choices should remain valid down to ~50% reuse without redesign.

### Sibling project context

- **`pocketnet_create_checkpoint`** — the existing checkpoint publisher. The doctor's server-side counterpart (manifest + chunk store generation) will extend or wrap this; see epic child `delt.3`.
- **`pocketnet_recover_checkpoint`** — the current full-snapshot recovery path. The doctor is the delta-mode replacement for the panic-recovery scenario.
- **Test target node:** a project-internal test node participating on the public pocketnet network. Used for end-to-end drill (US-005) under the project maintainer's close supervision, with virtual-machine snapshots taken before any invasive run.

### Technology defaults (not requirements)

- **Chunk addressing for `main.sqlite3`:** 4 KB SQLite page boundary. Validated; do not deviate without re-running the experiment.
- **Hash function:** SHA-256 across all artifacts (manifest entries, plan self-hash, post-apply verification). Single algorithm reduces surface area.
- **Transport:** HTTPS GET against the canonical chunk store. Range requests acceptable but per-page chunks are addressable as discrete URLs to keep server-side caching simple.
- **Compression:** Gzip or Zstandard for chunk-store payloads. Not prescribed at pre-spec level; plan-stage decision based on cache hit ratio and CPU vs. bandwidth trade-off.
- **Trust root:** v1 pins the project's canonical publisher (the project maintainer, hosting on the same channel as today's full-snapshot distribution). Verification is HTTPS + manifest SHA-256. Out of v1 scope: independent third-party canonical publishers, web-of-trust models. In Design Principle scope: not foreclosing chain-anchored manifest verification.
- **Concurrency:** apply may parallelize chunk fetches; staging + atomic rename happens per-file (not per-chunk) to preserve atomicity at the artifact boundary.

### Operational invariants the doctor relies on

- **Canonical checkpoint freshness:** ≤ 30 days old. The publisher's release cadence guarantees this; the doctor does not need to handle arbitrarily-old canonicals.
- **Single canonical, single block height:** All distributed copies of a given canonical checkpoint are at the same pocketnet block height. Repository mirroring is replication, not divergence.
- **`pocketnet-core` version pinning:** The manifest names the exact `pocketnet-core` version it was built against; doctor refuses on local mismatch (FR-012).

### Out of scope for v1

- OS-level disk diagnostics (SMART, fsck, sector remapping). If the doctor encounters disk errors, the operator's response is to replace the disk and full-snapshot recover.
- Reconciliation between divergent local chains. The doctor restores toward canonical; it does not arbitrate.
- Driving `pocketnet-core` (start/stop/configure). The operator stops the node before invoking the doctor.
- Chain-anchored manifest verification. Architecture must not foreclose it (FR-018); implementation is post-v1.
- Canonical-publisher trust verification via healthy-peer cross-check. The bad-actor publisher problem (a malicious mirror serving a poisoned canonical) is real and acknowledged. v1 mitigates it only via project-pinned trust root; the longer-term path — comparing a candidate canonical against a trusted healthy peer's local pocketdb at a known pocketnet block height — is a deferred feature. Architecture must not foreclose it (FR-018).
- Independent third-party canonical publishers. v1 trust root is project-pinned.

---

## Companion Document

The next stage produces `pre-spec-audit.md` per [`docs/pre-spec-build/process.md`](../../docs/pre-spec-build/process.md) Stage 2. Audit criteria are defined in [`docs/pre-spec-build/audit-criteria.md`](../../docs/pre-spec-build/audit-criteria.md), with PSA-11 (SpecKit Stop Coverage) as the criterion that operationalizes the fire-and-forget commitment.
