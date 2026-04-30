---
version: 0.2.0
status: draft
created: 2026-04-30
last_modified: 2026-04-30
authors: [claude]
related: pre-spec-strategic-chunking.md
changelog:
  - version: 0.2.0
    date: 2026-04-30
    summary: Delta audit on chunking v0.2.0's net-new content + pre-spec v0.3.2 write-back
    changes:
      - "Spot-check confirmed every v0.1.0 finding has a closure citation in the v0.2.0 changelog"
      - "CSA-11 / XDC finding: exit code 13 is allocated under Chunk 2's '10..19 apply-time' block but CSC2-002 tests it as a diagnose-time refusal — internal categorization contradiction"
      - "CSA-10 finding: Chunk 5 introduces release deliverables (GitHub Releases mirror, multi-platform enumeration, troubleshooting guide, README) beyond what pre-spec Design Principle 9 commits to — partial recurrence of CSA-10-F01 after the write-back"
      - "PSA-08 finding: pre-spec Design Principle 9 contains a temporal/process-history clause referencing the Stage-5 audit — belongs in changelog, not document body"
      - "CSA-05 finding: Gate 1-Schema → 2 predicate 1 contains a 'JSON schema or equivalent' disjunction — same anti-pattern class as the closed CSA-05-F01"
      - "CSA-11 finding: Chunk 5 signing-scheme SSR pairs Authenticode (X.509) with GPG and claims 'same key family where possible' — incoherent across cryptographic systems; signing-key custody is also unpinned"
      - "CSA-09 finding: Chunk 5 behavioral criterion 'reproducibly built from a tagged source revision' has no CSC verifying reproducibility (CSC5-001 covers signature only)"
      - "Pass list: Chunk 5 § Speckit Stop Resolutions; Gate 4 → 5 predicates; Chunk 2/3 exit-code 10..19 boundary (modulo the code-13 issue); EC-005 + EC-002 mechanism pins; canonical-form serialization rule write-back; cross-document trust_anchors / format_version alignment"
  - version: 0.1.0
    date: 2026-04-30
    summary: Initial adversarial audit of pre-spec-strategic-chunking.md v0.1.0 against audit-criteria.md Part 2 (CSA-*)
    changes:
      - "CSA-01 finding: Chunk 4 bundles three distinct concerns (drill, network resilience, release) with different failure modes"
      - "CSA-02 finding: parallel-against-mock claim for Chunks 1+2 elides hard plan-format dependency on Chunk 1's manifest schema"
      - "CSA-03 finding: EC-005 ownership and EC-002 split reasoning need explicit doctor-side coverage rationale"
      - "CSA-05 finding: Gate 1 → 2 zstd-or-error predicate is ambiguous; Gate 2 → 3 SC-001 fetch-size predicate is unmeasurable on a stubbed environment"
      - "CSA-08 finding: Chunk 2 SC-001 cannot be tested in isolation (depends on Chunk 1's chunk store size)"
      - "CSA-09 finding: FR-018 (forward-compat for chain-anchored verification) has no testable success criterion in any chunk"
      - "CSA-11 finding: several inventoried plan-stage stops in Chunks 2 and 3 (transport library, HTTP client choice, SQLite library bindings, logging surface, error-mapping to exit codes) lack explicit Speckit Stop Resolutions and are not pinned in pre-spec Implementation Context"
---

# Pre-Spec Strategic Chunking Audit: Delta Recovery Client for Pocketnet Operators

## Summary

The chunking is structurally well-formed: four chunks with non-trivial seams, complete Progress Tracker, concrete infrastructure-gate predicates for the most part, and explicit Speckit Stop Resolutions per chunk that pick up the two pre-spec-deferred items (PSA-11-F06 drill canonical source in Chunk 1; CLI surface preservation for `--full` mode in Chunk 2). The dominant risk is twofold: (a) Chunk 4 bundles drill, network resilience, and release polish — three concerns with materially different failure modes — into one chunk that is likely too large for a single `speckit.specify` pass; (b) several plan-stage stops the pipeline will predictably raise (HTTP client library, SQLite bindings, logging surface, exit-code-to-error mapping, network-drop simulation harness's relationship to apply's real network code) lack explicit resolutions in either the chunking doc or pre-spec Implementation Context — mid-severity CSA-11 fall-throughs that will surface as clarify-stage questions or plan-stage drift. Overall: ready for Stage 6 refinement, not ready as-is for Stage 7 launch.

## Severity legend

- **CRITICAL** — blocks fire-and-forget. Pipeline will halt at superb.review or silently drift in a chunk. Must fix before Stage 6 exits.
- **HIGH** — degrades pipeline output quality at chunk granularity, or makes a gate's pass/fail ambiguous. Should fix.
- **MEDIUM** — quality issue. Pipeline will probably produce correct output but with avoidable clarify-stage friction or test-environment ambiguity.
- **LOW** — stylistic, terminology, or organizational.

## Findings by criterion

### CSA-01: Trojan Horse Detection

#### CSA-01-F01

**ID:** CSA-01-F01
**Severity:** HIGH
**Locus:** Chunk 4 § Scope (the three sub-areas: drill / intermittent-network / release polish)
**Finding:** Chunk 4 explicitly bundles three distinct concerns. The drill exercises an integration scenario across the prior chunks. Network resilience is exercised by `tc`-injected packet loss against the live HTTP code path — that is functional verification of FR-019 / FR-020 primitives that already shipped in Chunk 3. Release polish covers signed binaries, multi-platform builds, troubleshooting docs, and a download channel — none of which share a code path or test harness with the drill or the network-drop test. The chunk's stated rationale ("all post-MVP hardening on top of a working diagnose+apply") is a temporal grouping ("after Chunk 3 merges") rather than a functional one.
**Why it matters:** A single `speckit.specify` pass on Chunk 4 will produce a spec that conflates three test plans, three artifact sets (drill instrumentation in `experiments/02-recovery-drill/`, network-drop harness, release-build pipeline), and three failure modes (drill: damage injection / observation; network: simulated drops; release: signing + distribution). Per CSA-01's test ("if component A fails, can component B be debugged independently?"): a release-signing failure does not block the drill scenario from being validated, and a `tc` harness mis-configuration does not block release artifacts from being signed. Three independent failure modes is the canonical CSA-01 split signal.
**Recommendation:** Stage 6 should split Chunk 4 into Chunk 4a (drill, scoped to US-005 / SC-007), Chunk 4b (network-resilience exercise, scoped to US-006 / SC-008 — pure verification of Chunk 3's FR-019 / FR-020 under realistic packet-loss), and Chunk 4c (release polish — multi-platform binaries, signing, docs, download channel). The split adds two infrastructure gates (4a → 4b can probably be omitted; 4b → 4c is meaningful: don't ship release artifacts until network-resilience is actually exercised).

### CSA-02: Dependency Accuracy

#### CSA-02-F01

**ID:** CSA-02-F01
**Severity:** HIGH
**Locus:** Critical Path § "Parallel work" claim; Chunk 2 § Prior artifact boundaries
**Finding:** The chunking claims Chunks 1 and 2 may develop in parallel against a mock chunk store, with convergence at Chunk 3 entry. This understates Chunk 2's real dependency on Chunk 1's manifest schema. Chunk 2's plan-format library, manifest verifier, and per-page diff machinery all encode Chunk 1's manifest shape. The mock chunk store cannot stub a manifest schema that has not been authored — the schema is part of Chunk 1's deliverable (CR1-001 through CR1-007). If Chunk 1's manifest is authored in a way that Chunk 2 did not anticipate (different field names, different page-entry structure, different hash encoding), Chunk 2's mock-fed code rewrites at Gate 1 → 2.
**Why it matters:** False parallelism claims cause work that fails at integration. Chunk 2's manifest verifier is not "consume any manifest"; it is "consume Chunk 1's manifest." The realistic ordering is: Chunk 1 ships the manifest schema first (a contract document, not the full chunk store) → Chunk 2 begins with a real schema and a mock chunk store (data, not contract) → Chunk 1 finishes the chunk store while Chunk 2 finishes diagnose. The schema is the gating artifact, not the chunk store.
**Recommendation:** Stage 6 should either (a) re-state the parallelism claim as "Chunk 2 may begin once Chunk 1's manifest schema is frozen (a sub-deliverable of Chunk 1, well in advance of the full chunk store)" and add a Gate 1 schema-freeze sub-checklist, or (b) drop the parallelism claim and serialize Chunk 1 → Chunk 2. Option (a) preserves the time savings; option (b) is honest about the dependency.

#### CSA-02-F02

**ID:** CSA-02-F02
**Severity:** MEDIUM
**Locus:** Chunk 3 § Prior artifact boundaries (relies on "Chunk 2's plan-format library, manifest verifier, hash utilities")
**Finding:** Chunk 3's apply phase re-uses Chunk 2's plan-format library and hash utilities. The dependency is correctly declared, but Chunk 3 also implicitly depends on a stable trust-root constant compiled into the binary. Chunk 2 declares "Chunk 1's published trust-root constant — compiled into the doctor binary at build time" as a prior artifact, but Chunk 3 does not. If Chunk 1 publishes a new canonical between Chunk 2 merge and Chunk 3 merge, the trust-root compiled into the Chunk 3 build differs from the trust-root tested at Chunk 2 merge.
**Why it matters:** Subtle build-time drift. Both chunks need to agree on which canonical the binary is pinned to. Without an explicit "trust-root constant is frozen at value X for Chunks 2-3 development" rule, the Chunk 3 build can silently shift away from Chunk 2's tested configuration.
**Recommendation:** Add a One-Time Setup Checklist item or Gate 1 → 2 predicate: "trust-root constant value X is published and pinned in the build configuration for Chunks 2 and 3 development." Re-pin only when Chunk 4 release-polish chooses the v1 release canonical.

### CSA-03: Edge Case Distribution

#### CSA-03-F01

**ID:** CSA-03-F01
**Severity:** MEDIUM
**Locus:** Chunk 3 § Edge cases owned (EC-005)
**Finding:** EC-005 is "Plan generated against a superseded canonical — apply warns and offers re-diagnose." The pre-spec assigns it to US-002. Chunk 3 owns it. But the resolution Chunk 3 owes is not just "warn" — it requires comparing the plan's `canonical_identity.manifest_hash` against the currently-served manifest hash. That comparison logic spans the manifest-fetch (Chunk 2's verifier) and the plan-load (Chunk 2's plan library). Chunk 3 cannot implement the warn-and-offer behavior without either re-using Chunk 2 components or re-fetching the manifest in Chunk 3 — and Chunk 3 has no Speckit Stop Resolution stating which.
**Why it matters:** Clarify-stage stop. `/speckit.clarify` will surface "How does apply detect that the plan's canonical is superseded?" If neither the pre-spec nor the chunking doc names the mechanism, the resolution falls through to defensive default. The defensive default that is most likely in this case (silent warn without re-fetching the manifest) breaks the EC-005 contract.
**Recommendation:** Add a Chunk 3 Speckit Stop Resolution: "Apply re-fetches the manifest at start (using Chunk 2's verifier) and compares the served manifest hash against the plan's `canonical_identity.manifest_hash`. Mismatch triggers the EC-005 warn-and-offer path; match proceeds with apply." This pins the integration point.

#### CSA-03-F02

**ID:** CSA-03-F02
**Severity:** LOW
**Locus:** Chunk 2 § Edge cases owned (EC-002 split)
**Finding:** EC-002 is split: Chunk 2 owns the diagnose-side handling, Chunk 3 owns the apply-side handling. The split is fine, but no chunk explicitly states the contract between them — what does the diagnose-side plan look like for a partially-present pocketdb, and what does the apply-side full-fetch sub-plan consume? The split implies a shared schema but does not name it.
**Why it matters:** Minor — likely resolved by the plan-format library Chunk 2 ships. But a clarify-stage question ("how does apply distinguish a missing-file plan entry from a divergent-file plan entry?") could surface if the JSON schema does not encode the distinction.
**Recommendation:** Either consolidate EC-002 ownership in Chunk 2 (define both sides of the contract; Chunk 3 just consumes the plan format), or add a one-line Speckit Stop Resolution in Chunk 3 confirming "missing-file divergences in the plan are encoded as full-file entries with a special expected-source marker, consumed identically to whole-file divergences."

### CSA-05: Infrastructure Gate Completeness

#### CSA-05-F01

**ID:** CSA-05-F01
**Severity:** HIGH
**Locus:** Gate 1 → 2 § "Content-Encoding negotiation works" predicate
**Finding:** The predicate reads: "absence of either returns a clear error or unencoded bytes per server policy." This is the canonical CSA-05 anti-pattern — "or" disjunctions in a verification predicate. Either response is acceptable, so the gate cannot fail this check, so the check verifies nothing. Worse: the chunking doc's pre-spec ancestor (Implementation Context § "Compression") states "if neither encoding matches, apply refuses with a diagnostic naming the unsupported encoding." The server-side and client-side contracts may not match.
**Why it matters:** A gate that cannot fail is not a gate. If the server's behavior diverges from the client's expectation, the integration breaks at the apply phase, not at Gate 1 → 2 where it should be caught.
**Recommendation:** Pin one server-side behavior and predicate against it. Suggested: "absence of either supported encoding in `Accept-Encoding` returns HTTP 406 Not Acceptable with a body naming supported encodings." Then the doctor's apply phase has a definite signal to refuse against, and the gate has a binary check (HTTP 406, body matches expected shape).

#### CSA-05-F02

**ID:** CSA-05-F02
**Severity:** HIGH
**Locus:** Gate 2 → 3 § "Diagnose against a known-divergent local pocketdb produces a plan ... total fetch size is within 25% of the full snapshot size (per SC-001)"
**Finding:** This predicate cannot pass at Gate 2 → 3 unless Chunk 1's published canonical exists at a real block height matching the operator's local pocketdb. The whole point of Chunk 2's mock-chunk-store parallel-development pathway (per the Critical Path) is that a real canonical does not exist yet. So either the Gate 2 → 3 predicate forces Chunk 2 to integrate against the real Chunk 1 chunk store before Chunk 2 merges (collapsing the parallelism claim), or the predicate is verified against a synthetic mock that may or may not reflect reality.
**Why it matters:** The 25%-fetch-size check is the only Gate 2 → 3 predicate that ties diagnose output to operationally-meaningful semantics. If it can be satisfied by a mock, it is meaningless; if it cannot, the parallelism claim falls apart.
**Recommendation:** Either (a) move SC-001 verification to Gate 3 → 4 where a real canonical is present (and explicitly mark Gate 2 → 3 as "plan format and refusal predicates only; size-bound SC validated post-Chunk-3 integration"), or (b) make Gate 2 → 3 conditional on Chunk 1 already having merged with at least one published canonical, and drop the parallelism claim. This finding is paired with CSA-02-F01.

#### CSA-05-F03

**ID:** CSA-05-F03
**Severity:** MEDIUM
**Locus:** Gate 3 → 4 § "EC-011 permission refusal fires"
**Finding:** EC-011 (volume permission refusal) is owned by Chunk 2, not Chunk 3. Verifying it at Gate 3 → 4 is reasonable as a regression check, but EC-011 should already be part of Gate 2 → 3 (it is the fifth pre-flight predicate Chunk 2 implements). The Gate 2 → 3 § "all four pre-flight refusal predicates fire correctly" predicate names exactly four — running, ahead, version, capacity — and omits EC-011. This is inconsistent with Chunk 2's documented five-predicate ordering.
**Why it matters:** Gate 2 → 3 lets a five-predicate Chunk 2 pass if only four are tested, masking a regression. Gate 3 → 4 catches it eventually, but the gating chunk is mis-located.
**Recommendation:** Update Gate 2 → 3 to "all five pre-flight refusal predicates fire correctly" enumerating EC-011 alongside the FR-010..013 set. Remove or downgrade the EC-011 entry at Gate 3 → 4 to a smoke-test continuation rather than a primary predicate.

### CSA-08: Per-Chunk Testability

#### CSA-08-F01

**ID:** CSA-08-F01
**Severity:** HIGH
**Locus:** Chunk 2 § Testable success criteria (SC-001 specifically)
**Finding:** SC-001 is "diagnose completes within 5 minutes ... emits a plan whose total fetch size is ≤ 25% of full-snapshot size." The fetch-size component requires a real canonical to compute against — a mock chunk store cannot give a meaningful "≤ 25% of full-snapshot size" measurement because the full-snapshot size is a property of Chunk 1's published canonical. Per CSA-08's test ("after completing just this chunk and nothing else, can you run its success criteria and get a pass/fail result?"): no, not for the fetch-size half of SC-001.
**Why it matters:** Untestable chunks accumulate validation debt. Chunk 2 ships claiming SC-001 is met, but the verification cannot occur until Chunk 1's chunk store is real. This is tied to CSA-05-F02 — same root cause, different manifestation.
**Recommendation:** Either split SC-001 into SC-001a (timing on the reference rig — Chunk 2 testable) and SC-001b (fetch-size ratio — Chunk 3 or later testable), or move the entire SC-001 ownership to Chunk 3 / Chunk 4a (drill). Consistency with CSA-05-F02 favors the second option.

#### CSA-08-F02

**ID:** CSA-08-F02
**Severity:** MEDIUM
**Locus:** Chunk 4 § Testable success criteria (CSC4-001, CSC4-002)
**Finding:** CSC4-001 ("released binaries match a documented checksum and are signed by a published key") and CSC4-002 ("troubleshooting guide covers each refusal exit code with operator's correct response") are both testable, but they have no acceptance scenario for failure. What does pass/fail look like on CSC4-002 specifically? An audit reads the troubleshooting doc and finds it covers all five exit codes — that is a binary check, but the chunking doc does not name it. CSC4-001's "documented checksum" is fine; CSC4-002 is more aspirational than testable.
**Why it matters:** Mild — CSC4-002 will be resolved at clarify-stage by a defensive default (probably "the doc lists each code"), which is correct, so the runtime impact is small.
**Recommendation:** Reword CSC4-002 to "Troubleshooting guide enumerates every doctor exit code (one per refusal predicate plus apply-failure codes) with at least one diagnostic message and one operator action per code." Binary check.

### CSA-09: Pre-Spec Coverage

#### CSA-09-F01

**ID:** CSA-09-F01
**Severity:** MEDIUM
**Locus:** Chunk 2 § Functional requirements owned (FR-018)
**Finding:** FR-018 is "the manifest format does not foreclose adding chain-anchored manifest verification or healthy-peer cross-check verification in a future version." This is a forward-compatibility constraint. It is assigned to Chunk 2 (which authors the manifest verifier), but no chunk has a testable success criterion for it. CSA-09 requires every FR to map to a chunk's test surface; FR-018 maps to Chunk 2's ownership but not to any of Chunk 2's behavioral criteria, success criteria, or addenda items.
**Why it matters:** FR-018 is an architectural-non-foreclosure requirement, which is hard to test directly. But "the manifest format declares a `format_version` field and reserves namespace for future trust-anchor fields" is testable. As written, FR-018 will fall through at speckit.tasks (no obvious task decomposition), surface as a clarify-stage question, and likely defensive-default to a no-op.
**Recommendation:** Add a Chunk 2 behavioral criterion or addendum: "Manifest schema includes a `format_version` field and reserves a `trust_anchors` block (empty in v1) so future canonical formats can add chain-anchored or healthy-peer verification fields without breaking parsers." Equivalent forward-compat language for the plan format if appropriate.

#### CSA-09-F02

**ID:** CSA-09-F02
**Severity:** LOW
**Locus:** Progress Tracker (Chunk 1's FR column says "(integration contracts; see chunk body)")
**Finding:** Chunk 1's row in the Progress Tracker has no pre-spec FRs, only "integration contracts." This is correct — the pre-spec is doctor-side and Chunk 1 is server-side. But the runner pre-flight parses the FR column expecting a parseable list. A free-text "integration contracts; see chunk body" entry may or may not parse.
**Why it matters:** Pre-flight parser robustness only; the runner stage prompts read the chunk body, not the FR column.
**Recommendation:** Verify the auto-chunk-runner pre-flight regex tolerates non-FR text in the FR column. If not, replace with `—` or `(none; see chunk body)` or `CR1-001..008` to make the column non-empty and parseable.

### CSA-10: Scope Discipline

#### CSA-10-F01

**ID:** CSA-10-F01
**Severity:** LOW
**Locus:** Chunk 4 § Scope (item 3 "Release polish") — "signed releases ... public download channel ... version-pinning for the trust-root constant"
**Finding:** Release polish includes signed binaries and a public download channel. The pre-spec discusses trust-root pinning and the canonical publisher's HTTPS endpoint, but does not list "release artifact signing," "GitHub Releases mirroring," or "publisher key publication" as in-scope deliverables. These are introduced by the chunking doc. They are reasonable v1 deliverables (the operator needs to verify the binary is genuine), but they are scope additions per CSA-10.
**Why it matters:** Mild scope creep in the chunking doc. Per the process, the right move is to amend the pre-spec (Stage 6 may write back) so the pre-spec captures release-signing as a v1 deliverable. As-is, the chunking doc is the source for these requirements, which violates the "pre-spec is source of truth" rule.
**Recommendation:** Stage 6 should write a small pre-spec amendment to add a Design Principle or FR for "operator-verifiable release artifacts" (signed binaries + published key), then re-derive Chunk 4c from the amended pre-spec.

### CSA-11: Per-Chunk SpecKit Stop Coverage

#### CSA-11-F01

**ID:** CSA-11-F01
**Severity:** HIGH
**Locus:** Chunk 2 § Speckit Stop Resolutions (missing: HTTP client library / transport)
**Finding:** Chunk 2 fetches the manifest over HTTPS (FR-017 + Implementation Context). The plan-stage stop "which HTTP client library / transport implementation?" is not resolved in pre-spec Implementation Context (which only says "HTTPS GET") and is not in Chunk 2's Speckit Stop Resolutions. This is a verification-instrument-class plan-stage stop — the kind that drove Chunk 3b drift in 051.
**Why it matters:** `/speckit.plan` will pick a library in context (Go's `net/http`, Rust's `reqwest`, etc.). The choice is probably fine, but it should not be a default-resolved decision; it should be a pre-declared one. The same library will be used in Chunk 3 for chunk fetches, so the choice has cross-chunk implications.
**Recommendation:** Add a Chunk 2 Speckit Stop Resolution: "HTTP client library is the language-default standard library client (e.g., Go `net/http`, Rust standard `hyper` / `reqwest`). No bespoke HTTP framework. Connection re-use is enabled at the worker-pool level in Chunk 3."

#### CSA-11-F02

**ID:** CSA-11-F02
**Severity:** HIGH
**Locus:** Chunk 2 § Speckit Stop Resolutions (missing: SQLite library bindings)
**Finding:** Chunk 2 reads `main.sqlite3` headers (for the change_counter ahead-of-canonical check, FR-011) and computes per-page hashes (FR-001). The plan-stage stop "which SQLite library / bindings?" is not resolved anywhere — pre-spec names `PRAGMA integrity_check` (Chunk 3 verification) but does not pin the library. Page reading does not require the SQLite engine (a 4 KB-aligned read is sufficient), but the change_counter read and the post-apply integrity_check do.
**Why it matters:** Plan-stage decision with cross-chunk implications. If Chunk 2 chooses one binding (e.g., Go's `mattn/go-sqlite3`) and Chunk 3 chooses another, the binary either statically links two SQLite engines or has a build-time conflict.
**Recommendation:** Add a pre-spec Implementation Context line OR a Chunk 2 Speckit Stop Resolution: "SQLite access uses [library]. Change_counter is read by parsing the file header directly without invoking the engine; integrity_check (Chunk 3) uses the same bound library." Promotes the choice to a single-decision point.

#### CSA-11-F03

**ID:** CSA-11-F03
**Severity:** MEDIUM
**Locus:** Chunk 2 § Speckit Stop Resolutions (missing: exit-code allocation / mapping)
**Finding:** Chunk 2's scope includes "exit-code allocation," and Chunk 2 has five distinct refusal predicates each with a distinct exit code (per Implementation Context "Pre-flight predicates"). But the actual exit-code numbering, the structure (POSIX 0/non-zero only? sysexits-style? errno mapping?), and the doctor-specific code allocation are not pinned. SC-006 names "distinct exit codes" but not the values.
**Why it matters:** Tasks-stage stop. `/speckit.tasks` may produce tasks for "implement exit-code 1 for running-node refusal" without the doctor having a numbering convention. Operators wrapping the doctor in scripts need stable codes.
**Recommendation:** Add a Chunk 2 Speckit Stop Resolution: "Exit codes: 0 success, 1 generic error, 2..6 the five refusal predicates (running-node 2, ahead 3, version 4, capacity 5, permission 6), 10..19 apply-time failures (rollback completed 10, rollback failed 11, network 12, etc.). The codes are documented in `--help` and the troubleshooting guide."

#### CSA-11-F04

**ID:** CSA-11-F04
**Severity:** MEDIUM
**Locus:** Chunk 2 § Speckit Stop Resolutions (missing: logging surface / format)
**Finding:** Chunk 2's scope includes "logging surface" but no Speckit Stop Resolution names what that logging looks like. Pre-spec Implementation Context is silent on logging. Plan-stage will choose: structured JSON logs to stderr? Plain text? Levels (debug/info/warn/error)? Verbose flag? Log to a file alongside the staging directory?
**Why it matters:** Clarify-stage and plan-stage stop. Will probably defensive-default to plain stderr with `--verbose` flag, which is fine, but the contract is unstated.
**Recommendation:** Add a Chunk 2 Speckit Stop Resolution: "Logging is plain-text to stderr at info level by default; `--verbose` flag enables debug. No structured logging in v1; no log-file output. Diagnose progress (per existing Speckit Stop Resolution) is a special case that uses the same stderr surface."

#### CSA-11-F05

**ID:** CSA-11-F05
**Severity:** MEDIUM
**Locus:** Chunk 4 § Speckit Stop Resolutions ("network-drop simulation tooling")
**Finding:** Chunk 4 specifies `tc` (Linux Traffic Control) for network-drop simulation. This is correct and sensible, but: SC-008 says "simulated drops every 256 MB on a 4 GB total fetch." Drops "every 256 MB" is a transferred-bytes condition; `tc` operates on time and packet drops, not on transferred bytes. The mapping between SC-008's specification ("every 256 MB") and the `tc` tooling's semantics is not pinned.
**Why it matters:** Tasks-stage stop. The drill author has to translate "every 256 MB" into a `tc` rate / drop-percentage configuration that approximates the SC-008 behavior. Without a pre-declared rule, the translation could shift the SC's meaning (e.g., "drops every 256 MB" interpreted as "drop one packet per 256 MB transferred" vs. "kill the connection at every 256 MB boundary").
**Recommendation:** Add a Chunk 4 Speckit Stop Resolution: "SC-008's '256 MB drops' is realized as: kill the TCP connection (`tc` policy + iptables connection reset) once per 256 MB of cumulative bytes transferred to the doctor's HTTP client. The doctor's retry-and-resume path is the unit under test." Or similar concrete mapping.

#### CSA-11-F06

**ID:** CSA-11-F06
**Severity:** LOW
**Locus:** Chunk 4 § Speckit Stop Resolutions (Windows installer)
**Finding:** "Out of v1: installer / MSI / store distribution. v1 ships a signed `.exe` for Windows that runs from `cmd` or PowerShell." Fine declaration, but the Windows-specific build / signing tool (signtool? sigstore?) is not pinned, and Windows code-signing certificates are non-trivial.
**Why it matters:** Plan-stage stop in Chunk 4c (release polish). Could surface as a clarify-stage question.
**Recommendation:** Either pin the Windows code-signing path (e.g., "Authenticode signature using project's existing publisher cert / sigstore self-signing — same key as macOS / Linux") or explicitly defer to delt.7 follow-up alongside the installer.

#### CSA-11-F07

**ID:** CSA-11-F07
**Severity:** MEDIUM
**Locus:** Chunk 1 § Speckit Stop Resolutions (canonical-form serialization)
**Finding:** Chunk 1 declares "Sort manifest JSON keys, no insignificant whitespace, UTF-8. Same canonical-form rule as the plan artifact's self-hash." This points at the plan-format library's canonical-form rule. But the plan-format library is owned by Chunk 2; Chunk 1 ships before Chunk 2. Either the canonical-form rule is authored in Chunk 1 (and Chunk 2 inherits), or it is co-authored. The chunking doc is silent.
**Why it matters:** Cross-chunk artifact. If Chunk 1 freezes a canonical-form spec and Chunk 2 implements it differently, the trust-root hash mismatch is a non-recoverable failure at integration.
**Recommendation:** Pin the canonical-form rule in pre-spec Implementation Context (so both chunks inherit) or add a Speckit Stop Resolution to Chunk 1 declaring the spec authoritatively, with Chunk 2's implementation cited as the consumer of that spec.

## CSA-11 Chunk-Level SpecKit Stop Coverage matrix

For each chunk, evaluate inventoried pipeline-stage stops. **PS** = pre-spec inheritance. **CR** = chunk Speckit Stop Resolution. **U** = unanswered (finding).

### Chunk 1 — Server-Side Manifest + Chunk Store

| Stop class | Coverage | Citation |
|---|---|---|
| Specify / ambiguous FR term | n/a | Chunk uses CR1-* contract terms; defined inline |
| Clarify / scope boundary | CR | Chunk § Scope explicit on what's in vs. out |
| Plan / language and runtime | CR | Speckit Stop Resolutions § "language and runtime for the manifest generator" |
| Plan / hosting topology | CR | Speckit Stop Resolutions § "chunk-store hosting topology" |
| Plan / compression choice | CR | Speckit Stop Resolutions § "compression choice on the server side" |
| Plan / drill canonical source (PSA-11-F06 deferral) | CR | Speckit Stop Resolutions § explicit |
| Plan / canonical-form serialization | **U** | CSA-11-F07 — claims same rule as Chunk 2 but Chunk 2 ships later |
| Tasks / manifest schema documentation | PS | Chunk 1 addendum |

### Chunk 2 — Client Foundation + Diagnose

| Stop class | Coverage | Citation |
|---|---|---|
| Clarify / FR term ambiguity | PS | Pre-spec Implementation Context covers most terms |
| Clarify / plan filename | CR | Speckit Stop Resolutions § "plan filename and location" |
| Plan / language and runtime | CR | Speckit Stop Resolutions § "language and runtime" — single static binary, three platforms |
| Plan / CLI surface (`--full` mode preservation, hand-off note) | CR | Speckit Stop Resolutions § "CLI surface" — explicit reservation for `apply --full` |
| Plan / progress reporting | CR | Speckit Stop Resolutions § "progress reporting on long diagnose runs" |
| Plan / configuration storage | CR | Speckit Stop Resolutions § "configuration storage" |
| Plan / HTTP client library | **U** | CSA-11-F01 — not in pre-spec, not in Chunk 2 resolutions |
| Plan / SQLite library bindings | **U** | CSA-11-F02 — not in pre-spec, not in Chunk 2 resolutions |
| Plan / logging surface | **U** | CSA-11-F04 — not pinned anywhere |
| Plan / verification instrument (manifest auth, FR-017) | PS | Pre-spec Implementation Context § "Trust root" pins SHA-256 compare |
| Tasks / pre-flight predicate ordering | CR | Speckit Stop Resolutions § "pre-flight predicate ordering" |
| Tasks / exit-code allocation | **U** | CSA-11-F03 — distinct codes promised by SC-006, values unpinned |
| Tasks / FR-018 forward-compat surface | **U** | CSA-09-F01 — no testable surface for FR-018 |

### Chunk 3 — Client Apply

| Stop class | Coverage | Citation |
|---|---|---|
| Plan / staging directory location | CR | Speckit Stop Resolutions § "staging directory location" |
| Plan / shadow-copy strategy | CR | Speckit Stop Resolutions § "shadow-copy strategy" (and pre-spec Implementation Context) |
| Plan / completion-marker format | CR | Speckit Stop Resolutions § "completion-marker format" |
| Plan / retry budget shape | CR | Speckit Stop Resolutions § "retry budget shape" |
| Plan / parallelism implementation | CR | Speckit Stop Resolutions § "parallelism implementation" |
| Plan / Content-Encoding negotiation | CR | Speckit Stop Resolutions § "Content-Encoding negotiation" |
| Plan / verification instrument (pre-rename hash) | PS / CR | Pre-spec Implementation Context § "Verification timing" + Chunk 3 resolution |
| Plan / `pocketnet-core` start verification scope | CR | Speckit Stop Resolutions § explicit; matches pre-spec EC-010 |
| Clarify / EC-005 superseded-canonical detection | **U** | CSA-03-F01 — mechanism unpinned |
| Plan / HTTP client library (inherited from Chunk 2) | **U** | CSA-11-F01 — same gap as Chunk 2 |
| Tasks / exit-code allocation for apply-time failures | **U** | CSA-11-F03 — same gap, applies here too |

### Chunk 4 — Drill + Network + Release

| Stop class | Coverage | Citation |
|---|---|---|
| Plan / drill node provisioning | CR | Speckit Stop Resolutions § "drill node provisioning" |
| Plan / network-drop simulation tooling | CR | Speckit Stop Resolutions § "network-drop simulation tooling" |
| Plan / SC-008 256 MB drop semantics mapping to `tc` | **U** | CSA-11-F05 — `tc` named, mapping unpinned |
| Plan / release artifact hosting | CR | Speckit Stop Resolutions § "release artifact hosting" |
| Plan / signing scheme | CR | Speckit Stop Resolutions § "signing scheme" |
| Plan / Windows installer | CR (defer) | Speckit Stop Resolutions § "Windows installer" |
| Plan / Windows code-signing tool | **U** | CSA-11-F06 — signed `.exe` claimed, tool unpinned |
| Tasks / drill canonical provenance | CR | Speckit Stop Resolutions § "drill canonical provenance" |

**Summary of unanswered stops:** Chunk 1: 1 (canonical-form ownership). Chunk 2: 5 (HTTP client, SQLite library, logging, exit codes, FR-018 surface). Chunk 3: 3 (EC-005 mechanism, HTTP client inherit, exit codes for apply). Chunk 4: 2 (`tc`-to-256MB mapping, Windows signing tool). None CRITICAL; all HIGH or MEDIUM. The Chunk 2 cluster is the bulk of the risk.

## Chunk-boundary defensibility analysis

**Chunk 1 (server-side, sibling repo).** The seam is defensible *as a contract chunk* but the framing has a soft edge: the contract is enumerated (CR1-001..008) but the realization lives in `pocketnet_create_checkpoint` (delt.3). For chunking-purposes — feeding the chunking-doc blob to `speckit.specify` for the doctor repo — this is fine because the doctor repo is the spec target and Chunk 1's "implementation" is consumption-of-an-external-deliverable. The chunking doc could equally have absorbed Chunk 1 into a pre-spec Implementation Context note ("the chunk store and manifest are produced externally by delt.3; doctor's contract is X, Y, Z") and dropped Chunk 1 from the chunking. Keeping it as a chunk is a reasonable choice because it surfaces the contract dependencies for audit and gating; the same content as an Implementation Context note would be less visible. Verdict: keep, but tighten the canonical-form ownership (CSA-11-F07) and accept that the Chunk 1 "merge" is really "delt.3 ships and Gate 1 → 2 passes."

**Chunk 2 (client foundation + diagnose).** The largest chunk by FR count (11 FRs) and EC count (5 ECs). The bundling — project skeleton + plan-format library + manifest verifier + diagnose phase + five refusal predicates — is justifiable because every component is read-only and there is no observable side-effect. A split would be artificial: "skeleton + plan format" alone produces nothing the operator can run, and "diagnose" alone needs the skeleton and plan format. The strongest split-candidate would be "skeleton + plan format + manifest verifier" (a tooling foundation chunk) vs. "diagnose phase + refusal predicates" (the user-facing read-only chunk). The split would not be wrong, but it adds an internal gate without a clear boundary benefit. Verdict: keep as-is, but address the unanswered stops cluster (CSA-11-F01..F04).

**Chunk 3 (apply).** A coherent unit: every component participates in the mutating recovery code path. The seam is defensible — apply is observably distinct from diagnose in side effects. The remaining concern is its dependency on Chunk 2's components being stable (CSA-02-F02 trust-root pinning); the fix is an integration discipline note, not a re-chunking. Verdict: keep as-is.

**Chunk 4 (drill + network + release).** As discussed in CSA-01-F01, the bundling is temporal not functional. Three independent failure modes, three artifact sets, three test harnesses. This is the chunking's biggest defect. The drill alone is its own chunk (US-005 + SC-007 + drill instrumentation in `experiments/02-recovery-drill/`). Network-resilience exercise alone is its own chunk (US-006 + SC-008 + `tc` harness). Release polish alone is its own chunk (multi-platform builds, signing, docs, download channel). Verdict: split into 4a / 4b / 4c.

## EC / FR / SC distribution audit

### Edge Case ownership

| EC | Pre-spec assigned US | Chunk(s) | Status |
|----|---|---|---|
| EC-001 (pocketdb missing) | US-001, US-002 | Chunk 2 | Covered (diagnose side); apply-side not explicitly cited |
| EC-002 (partial pocketdb) | US-001, US-002 | Chunk 2 (diag) + Chunk 3 (apply) | Covered, contract underspecified (CSA-03-F02) |
| EC-003 (chunk store unreachable) | US-002 | Chunk 3 | Covered |
| EC-004 (non-pocketnet OS lock) | US-003 | Chunk 2 | Covered |
| EC-005 (superseded canonical) | US-002 | Chunk 3 | Covered, mechanism unpinned (CSA-03-F01) |
| EC-006 (double-apply) | US-002, US-005 | Chunk 3 | Covered |
| EC-007 (disk I/O fault) | US-002 | Chunk 3 | Covered |
| EC-008 (manifest hash fail) | US-002, US-004 | Chunk 2 | Covered |
| EC-009 (plan tampered) | US-002 | Chunk 3 | Covered |
| EC-010 (apply succeeds, core won't start) | US-002 | Chunk 3 | Covered |
| EC-011 (volume permission) | US-003 | Chunk 2 | Covered (gate misalignment per CSA-05-F03) |

EC ownership is complete. EC-001 apply-side coverage is implied by Chunk 3 owning all of US-002 but not explicitly cited under Chunk 3's edge cases — minor.

### Functional Requirement ownership

All 20 FRs (FR-001..020) are explicitly assigned in the Progress Tracker and chunk bodies. Verified via cross-referencing:

- FR-001..005 → Chunk 2 (diagnose).
- FR-006..009 → Chunk 3 (apply).
- FR-010..013 → Chunk 2 (refusals).
- FR-014..016 → Chunk 3 (verification).
- FR-017..018 → Chunk 2 (trust). FR-018 lacks a testable surface (CSA-09-F01).
- FR-019..020 → Chunk 3 (network resilience).

FR distribution is complete. FR-018 is the lone weak spot (architectural-non-foreclosure).

### Success Criterion ownership

| SC | Owning chunk | Status |
|----|---|---|
| SC-001 (diagnose timing + ratio) | Chunk 2 | Partially testable in isolation (CSA-08-F01) |
| SC-002 (zero-entry plan) | Chunk 2 | Covered |
| SC-003 (apply matches canonical) | Chunk 3 | Covered |
| SC-004 (resume after kill) | Chunk 3 | Covered |
| SC-005 (rollback on verify fail) | Chunk 3 | Covered |
| SC-006 (refusal exit codes) | Chunk 2 | Covered, codes unpinned (CSA-11-F03) |
| SC-007 (drill recovery) | Chunk 1 (prereq) + Chunk 4 | Covered |
| SC-008 (intermittent network) | Chunk 4 | Covered, `tc` mapping unpinned (CSA-11-F05) |

SC-007 appears in both Chunk 1 (drill-prerequisite SC) and Chunk 4 (drill-execution SC). This is intentional — Chunk 1 owes the canonical, Chunk 4 owes the recovery — but the Progress Tracker double-listing (Chunk 1's SC column says "SC-007 (drill prerequisite)", Chunk 4's says "SC-007, SC-008") may confuse the runner pre-flight if it counts SCs. Minor.

## Infrastructure gate evaluation

**Gate 1 → 2 (Chunk Store Available).** Four predicates. Predicate 1 (manifest URL + sha256sum hash equals trust-root): concrete and verifiable. Predicate 2 (manifest fields parse): concrete (assuming a JSON schema is published). Predicate 3 (3 sampled chunks verified): concrete. Predicate 4 (Content-Encoding negotiation): **not verifiable as written** (CSA-05-F01) — the "or unencoded bytes per server policy" disjunction makes the predicate vacuous. The gate could pass with the integration broken. Fix per CSA-05-F01.

**Gate 2 → 3 (Plan Format Round-Trips).** Five predicates. Predicate 1 (diagnose produces plan, ≤25% fetch size): **not verifiable in Chunk 2 isolation** (CSA-05-F02 / CSA-08-F01) — depends on real Chunk 1 chunk store. Predicate 2 (plan self-hash): concrete. Predicate 3 (canonical identity binding): concrete. Predicate 4 (zero-entry plan): concrete. Predicate 5 (four refusal predicates fire): concrete but **enumerates four when Chunk 2 implements five** (CSA-05-F03) — EC-011 is missed. Net: gate is mostly verifiable but has two integrity issues.

**Gate 3 → 4 (Apply Round-Trips Against Real Canonical).** Four predicates. All concrete and verifiable in their stated form. EC-011 placement is awkward (CSA-05-F03) — should be owned by Gate 2 → 3. Net: gate is sound; minor cleanup around EC-011.

Overall: Gate 1 → 2 has one unverifiable predicate; Gate 2 → 3 has one unverifiable predicate and one mis-enumerated predicate; Gate 3 → 4 is clean modulo the misplaced EC-011 check. Stage 6 should fix Gate 1 → 2 and Gate 2 → 3 before runner launch.

## Pass list

- **CSA-04 (behavioral criteria distribution).** Cross-cutting behavioral rules (atomicity, read-only diagnose, deterministic plan emission) are validated in the earliest chunks where they apply. No deferred-validation pattern.
- **CSA-06 (prior artifact boundaries).** Each chunk explicitly names what exists, what's new, what's updated. Chunk 2 cites Chunk 1's manifest contract and trust-root constant; Chunk 3 cites Chunk 1 and Chunk 2; Chunk 4 cites all three.
- **CSA-07 (critical path accuracy).** The dependency graph is correctly drawn with one defensible parallelism note (CSA-02-F01 challenges the parallelism *claim* but does not invalidate the dependency graph itself).
- **CSA-09 partial (pre-spec coverage).** Every US, FR, SC, EC has at least one chunk owner. FR-018's testable surface and a couple of EC ownership clarifications are the only gaps, both at MEDIUM or below.
- **Speckit Stop Resolutions presence.** Every chunk has the section, populated with non-trivial content. The deferred items (PSA-11-F06 drill canonical, CLI surface for `--full` mode) are picked up explicitly in Chunk 1 and Chunk 2 respectively.
- **Progress Tracker convention.** Column order (Chunk | Title | FRs | SCs | Status), Status capitalization, no merged cells. Compliant with process.md v0.3.2.
- **One-Time Setup Checklist.** Empirical experiments (delt.1, delt.2, delt.5) are correctly relegated to setup work, not chunks. Test-rig conformance to SC-001 reference rig is a checklist item.

## Recommended Stage 6 priorities

1. **Split Chunk 4 into 4a (drill), 4b (network resilience), 4c (release polish).** CSA-01-F01. Three independent failure modes do not belong in one chunk. Add a Gate 4b → 4c.
2. **Resolve the parallelism claim for Chunks 1+2.** CSA-02-F01 + CSA-05-F02 + CSA-08-F01. Either reframe the parallel work as "schema-freeze gates Chunk 2; full chunk store gates Gate 2 → 3 fetch-size verification" or drop the parallelism. Move SC-001's fetch-size predicate to a later chunk if Chunk 2 cannot test it in isolation.
3. **Fix the unverifiable gate predicates.** CSA-05-F01 (Gate 1 → 2 Content-Encoding disjunction), CSA-05-F03 (Gate 2 → 3 enumerates four predicates when Chunk 2 implements five).
4. **Pin the Chunk 2 plan-stage stop cluster.** CSA-11-F01..F04 (HTTP client, SQLite library, logging, exit codes). Five-line additions to Speckit Stop Resolutions; high leverage.
5. **Pin EC-005's superseded-canonical detection mechanism.** CSA-03-F01. One Chunk 3 Speckit Stop Resolution.
6. **Pin canonical-form serialization ownership.** CSA-11-F07. Either elevate to pre-spec Implementation Context (preferred — both chunks inherit) or add a Chunk 1 Speckit Stop Resolution authoritative for the rule.
7. **Add a testable surface for FR-018.** CSA-09-F01. One Chunk 2 behavioral criterion or addendum.
8. **Pin Chunk 4b's `tc`-to-256-MB mapping.** CSA-11-F05. Concrete network-drop semantics for SC-008 verifiability.
9. **Write back release-signing and download-channel deliverables to the pre-spec.** CSA-10-F01. Pre-spec amendment, then re-derive Chunk 4c.
10. **Optional cleanup:** Chunk 1's FR-column entry in Progress Tracker (CSA-09-F02); EC-001 apply-side citation in Chunk 3 (CSA-03 minor); CSC4-002 wording (CSA-08-F02); Windows code-signing tool pin (CSA-11-F06).

---

## Delta Audit — v0.2.0 Findings

This audit examines only the net-new content introduced by chunking v0.1.0 → v0.2.0 (Stage 6 refinement) plus the pre-spec v0.3.2 write-back (Design Principle 9 + canonical-form serialization rule). Every v0.1.0 finding has a closure citation in the v0.2.0 changelog and a corresponding edit in the chunking body; spot-checks against CSA-01-F01 (Chunk 4 split into 4+5), CSA-05-F01 (Gate 1 → 2 HTTP 406 pin), CSA-11-F03 (exit-code allocation 0..6 + 10..19), and CSA-11-F07 (canonical-form rule write-back) all hold. The delta surface is mostly clean. The dominant residual is one cross-document allocation contradiction (exit code 13) and a recurrence of CSA-10's scope-discipline pattern in Chunk 5 — the chunking has expanded the release-engineering surface beyond what the DP9 write-back ratifies.

### CSA-05: Infrastructure Gate Completeness

#### CSA-05-F01-D

**ID:** CSA-05-F01-D
**Severity:** LOW
**Locus:** Gate 1-Schema → 2 § predicate 1 ("JSON schema or equivalent that enumerates every required field")
**Finding:** The new schema-freeze gate's first predicate reads "Manifest schema document published … JSON schema or equivalent." This is the same disjunction-in-a-predicate pattern v0.1.0 caught at Gate 1 → 2 (CSA-05-F01, since closed). "Or equivalent" is unverifiable: a schema published as a hand-typed prose specification arguably qualifies, as does a TypeScript interface, as does a published `.json` schema — the gate cannot fail any of those.
**Why it matters:** This is the gate Chunk 2 launches against. If the form of the published schema is ambiguous, Chunk 2's manifest-verifier author cannot mechanically validate the schema is complete; clarify-stage may surface "what does the schema look like?" The defensive default is probably benign, but the gate is not doing the work it claims.
**Recommendation:** Pin one form. Either "a published JSON Schema document (Draft 2020-12 or current at time of authoring) at a stable URL" or "a markdown table enumerating every field with type, presence, and example." Both are concrete. The current wording is not.

### CSA-09: Pre-Spec Coverage

#### CSA-09-F01-D

**ID:** CSA-09-F01-D
**Severity:** LOW
**Locus:** Chunk 5 § Behavioral criteria ("Released binaries are reproducibly built from a tagged source revision")
**Finding:** Chunk 5 lists "Released binaries are reproducibly built from a tagged source revision" as a behavioral criterion, but no CSC verifies reproducibility. CSC5-001 verifies signature + checksum, CSC5-002 verifies troubleshooting-guide coverage, CSC5-003 verifies README discoverability. None of them tests that two independent builds from the same tag produce the same binary bytes (or even the same checksum modulo signing).
**Why it matters:** Reproducibility is a non-trivial release-engineering property — it requires a hermetic build, deterministic compiler flags, stripped timestamps, etc. If it's a behavioral commitment but not gated, plan-stage will likely defensive-default to "build it once, ship it" without the reproducibility property. The gap is small (operators can verify a single binary against the published checksum even without reproducibility), but the chunking doc claims a property it doesn't test.
**Recommendation:** Either drop "reproducibly built" from the behavioral criteria (the operator-verifiability commitment is preserved by signature verification alone), or add CSC5-004: "an out-of-band rebuild from the tagged source revision produces a binary with the same SHA-256 as the released artifact (modulo platform-signing differences)."

### CSA-10: Scope Discipline

#### CSA-10-F01-D

**ID:** CSA-10-F01-D
**Severity:** LOW
**Locus:** Chunk 5 § Scope (multi-platform enumeration, GitHub Releases mirror, troubleshooting guide, README updates)
**Finding:** The CSA-10-F01 closure (write-back of release-signing as Design Principle 9) ratifies "signed binaries with a published verification key." Chunk 5's scope, however, expands meaningfully past that: (a) explicit Linux + macOS + Windows enumeration (DP9 silent on platforms; pre-spec Implementation Context names "three platforms" only via Chunk 2 inheritance); (b) GitHub Releases as a mirror (DP9 names only "the canonical publisher's distribution channel"); (c) troubleshooting guide covering every doctor exit code (no pre-spec FR or DP commits to a troubleshooting-guide deliverable); (d) README updated to "v1 released" (no pre-spec FR commits to README content). These are reasonable v1 deliverables, but they are chunking-doc-originated and not traceable to pre-spec text.
**Why it matters:** Same class as the original CSA-10-F01 — "the chunking is the source for these requirements, which violates the 'pre-spec is source of truth' rule." The write-back fixed the largest case (release-signing) but did not enumerate all the secondary deliverables the chunking adds. If a future Stage 6 iteration wants to challenge "do we need a troubleshooting guide as a v1 deliverable?" the answer is currently authored only in chunking, not in pre-spec.
**Recommendation:** A small second write-back: either expand DP9 to cover "supported platforms, distribution mirrors, operator-facing reference documentation (troubleshooting + release notes)," or add a single FR ("Doctor v1 ships with operator-facing reference documentation enumerating every exit code, the diagnostic, and the operator action"). The README and GitHub Releases mirror are arguably out-of-scope-of-pre-spec (release-engineering plumbing) and need not migrate. Optionally accept the residual scope-creep as too low-leverage to fix and move on; the finding is recorded for completeness.

### CSA-11: Per-Chunk SpecKit Stop Coverage

#### CSA-11-F01-D

**ID:** CSA-11-F01-D
**Severity:** MEDIUM
**Locus:** Chunk 5 § Speckit Stop Resolutions ("signing scheme") + ("Windows code-signing path")
**Finding:** Two related defects in Chunk 5's signing SSRs.

(a) The signing-scheme SSR says "Authenticode signature for Windows binaries; GPG-signed sha256sums file for Linux/macOS binaries" and the Windows code-signing SSR says "Same key family as macOS/Linux GPG signing where possible (or a Windows-specific certificate of the same provenance)." Authenticode requires X.509 certificates; GPG uses OpenPGP keys. There is no mechanism to share a "key family" across these systems — the cryptographic primitives are different and the cert chains are different. The "(or a Windows-specific certificate of the same provenance)" alternative recovers the position, but the primary phrasing will read as a contradiction at plan-stage and surface a clarify-question.

(b) Signing-key custody is unpinned. The build-pipeline SSR says "no manual key handling on a developer laptop in steady state" — a constraint, not a placement. Where does the GPG signing key live? Where does the Authenticode signing cert live? CI provider HSM? KMS? Hardware token? This is a non-trivial release-engineering decision and a real plan-stage stop.
**Why it matters:** Both feed clarify-stage and plan-stage. (a) is mostly cosmetic — plan-stage will resolve the contradiction by reading the alternative clause. (b) is consequential: signing-key custody choice has security implications that vary by provider and are difficult to revisit after v1 ships.
**Recommendation:** Reword the Windows code-signing SSR to: "Authenticode signature using the project's existing publisher cert (X.509). The GPG key used for Linux/macOS sha256sums is administratively maintained by the same publisher but is a distinct cryptographic artifact." For (b), add a Speckit Stop Resolution: "Signing keys are held in [pin choice — e.g., the CI provider's secret store, a dedicated HSM, a hardware token under the project maintainer's custody]; the build pipeline retrieves them at sign-time only and never persists them on a runner."

#### CSA-11-F02-D

**ID:** CSA-11-F02-D
**Severity:** LOW
**Locus:** Chunk 4 § Speckit Stop Resolutions ("SC-008 256 MB drop semantics" + "network-drop simulation tooling")
**Finding:** The new SSR maps "drops every 256 MB" to "kill the active TCP connection (via `tc` egress policy combined with iptables `REJECT --reject-with tcp-reset` rules) once per 256 MB of cumulative bytes transferred." The cited tooling does not match the cited mechanism: `tc` (Linux Traffic Control) shapes traffic — bandwidth limits, latency injection, loss probability — but does not kill connections. The connection-kill semantics are entirely the iptables `REJECT --reject-with tcp-reset` rule. Naming `tc` alongside iptables in a "kill TCP connection" claim is technically muddled.
**Why it matters:** Tasks-stage will surface this. The drill-instrumentation author has to choose: do I need `tc` at all? What is `tc` doing here? The finding does not block SC-008 verification (iptables alone is enough), but the tooling list is over-specified.
**Recommendation:** Trim `tc` from the connection-kill claim. If `tc` is needed for an orthogonal purpose (e.g., enforcing a 10 Mbps rate cap during the drop scenario), name that purpose separately: "iptables `REJECT --reject-with tcp-reset` rule kills the TCP connection at 256 MB cumulative-bytes boundaries; optionally `tc` may shape transfer rate to mimic a constrained operator link."

### XDC: Cross-Document Consistency

#### XDC-F01-D

**ID:** XDC-F01-D
**Severity:** MEDIUM
**Locus:** Chunk 2 § Speckit Stop Resolutions ("exit-code allocation") vs. Chunk 2 § Testable success criteria (CSC2-002) vs. Chunk 3 § Speckit Stop Resolutions ("apply-time exit codes")
**Finding:** Exit code 13 is double-allocated across diagnose-time and apply-time without acknowledgement.

- Chunk 2 SSR: "10..19 reserved for apply-time failures (Chunk 3 inherits and allocates: e.g., 10 rollback completed, 11 rollback failed, 12 network exhausted, **13 manifest-format-version unrecognized**, others as Chunk 3 needs)."
- Chunk 2 CSC2-002 (also Chunk 2): "a manifest with an unrecognized future `format_version` causes diagnose to refuse with a distinct exit code naming the version mismatch." This refusal happens at diagnose, not apply.
- Chunk 3 SSR: "10..19 range reserved by Chunk 2: ... **13 manifest-format-version unrecognized at apply time** ..."

The same exit code is claimed by a diagnose-time refusal (CSC2-002, in Chunk 2) and an apply-time refusal (Chunk 3 SSR). The condition is the same (unrecognized `format_version` on manifest), but the exit code's home in the "10..19 apply-time" block contradicts its diagnose-time use. Either the categorization rule "10..19 = apply-time" is wrong, or the diagnose-time CSC2-002 should claim an exit code in the 2..6 refusal block (e.g., a new code 7), or both phases should explicitly share code 13 with a one-line note.
**Why it matters:** Tasks-stage stop with downstream operator impact. Wrappers parsing exit codes will see code 13 and not know whether to interpret it as "diagnose refused — fix the canonical pin" or "apply refused mid-run — fix the pinned manifest version." The internal contradiction also reads at plan-stage as a thin-intent signal — `/speckit.plan` may surface a clarify question.
**Recommendation:** Pick one. Option (a): redefine the categorization rule as "2..6 = pre-flight refusals (diagnose or apply); 10..19 = apply-time failures specifically caused by mid-run conditions" and reassign manifest-format-version-unrecognized to a code in the 2..6 block. Option (b): explicitly state that code 13 covers both diagnose-time and apply-time manifest-format-version refusals, and amend the categorization to "10..19 = manifest- or canonical-derived failures, regardless of phase." Option (a) is cleaner; option (b) preserves the existing allocation.

### Pre-Spec v0.3.2 Write-Back Findings

#### PSA-08-F01-D

**ID:** PSA-08-F01-D
**Severity:** LOW
**Locus:** pre-spec.md § Design Principles, Principle 9 (final clause)
**Finding:** Design Principle 9's body reads: "v1 doctor binaries are signed; the verification key is published on the canonical publisher's distribution channel. Operators can confirm a downloaded binary is the genuine artifact before running it. **The signing scheme is part of v1 — the chunking-doc Stage-5 audit promoted release artifact verifiability from 'release polish' to a first-class Design Principle.**" The bolded final clause is a process-history reference: it explains *why* the principle was added, citing the audit that surfaced it. Per PSA-08, the document body must contain no temporal references to prior versions or process events; version history belongs in the changelog (where this is, in fact, also recorded).
**Why it matters:** `speckit.specify` reads the pre-spec as a statement of current requirements. A clause that says "the audit promoted X" reads as version meta-commentary in the middle of a Design Principle; a literal-minded reader (or a future maintainer) may treat it as part of the principle's content. Low impact in this case because the principle's substantive commitment (signed binaries + published key) is clearly before the offending clause.
**Recommendation:** Strike the last sentence of DP9. The principle stands on "v1 doctor binaries are signed; the verification key is published on the canonical publisher's distribution channel. Operators can confirm a downloaded binary is the genuine artifact before running it." The audit-promotion provenance is already recorded in the changelog entry for v0.3.2.

### Pass list (delta)

What audited cleanly in the v0.2.0 net-new surface:

- **Chunk 5 SSR coverage of inventoried plan-stage stops.** Hosting topology, signing scheme (modulo CSA-11-F01-D), Windows installer deferral, build-pipeline framing, on-doctor self-update deferral, and v1 release trust-root pinning all carry explicit resolutions.
- **Gate 4 → 5 predicates.** Three concrete predicates (drill passes, network-drop completes, drill runbook reproduces) — no disjunctions, no aspirational language, all binary.
- **Chunk 2 / Chunk 3 exit-code allocation boundary.** The 0..6 / 10..19 split itself is sound; only the code-13 placement (XDC-F01-D) breaks it.
- **EC-005 superseded-canonical detection mechanism (Chunk 3 SSR).** Concrete: "re-fetch manifest, compare hash against plan's `canonical_identity.manifest_hash`, mismatch → warn-and-offer-re-diagnose." Tied to a specific exit code (14) and a Chunk 3 addendum unit test.
- **EC-002 partial-pocketdb plan contract (Chunk 3 SSR).** Concrete: `expected_source: "fetch_full"` marker; symmetric handling at apply consumed identically to whole-file divergences. Round-trip tested via Chunk 3 addendum.
- **Canonical-form serialization rule write-back.** Pre-spec Implementation Context v0.3.2 owns the rule; Chunk 1 SSR ("canonical-form serialization ownership") and Chunk 2 § Scope both cite it. Cross-document inheritance is clean.
- **trust_anchors / format_version cross-doc alignment.** Chunk 1 CR1-001 reserves the block (empty in v1); Chunk 2 SSR + behavioral criteria parse and ignore unknown contents per FR-018; CSC2-002 covers the future-format-version refusal path. The forward-compat surface FR-018 was missing in v0.1.0 (CSA-09-F01) is now testable.
- **Gate 1-Schema → 2 predicate 2 (canonical-form rule citation).** Concrete and binary modulo CSA-05-F01-D's affecting predicate 1.
- **Cross-document scope flow for DP9.** Chunk 5's behavioral criteria ("released binaries are signed by publisher key; verification key is published on canonical publisher's distribution channel; operators can verify with standard tools") faithfully carries forward DP9's commitments; substantive secondary additions are flagged in CSA-10-F01-D, but the principle itself rides through cleanly.

### Recommended Stage 6.5 priorities

Six findings; none CRITICAL; one MEDIUM (XDC-F01-D), one MEDIUM (CSA-11-F01-D), four LOW. The chunking is close enough to ready that a single small refinement pass can absorb them without re-auditing. Ordered list:

1. **XDC-F01-D — exit code 13 categorization.** Decide between option (a) move manifest-format-version refusal out of 10..19 to a new pre-flight code, or option (b) redefine 10..19 as phase-agnostic manifest/canonical failures and document the override. Edit Chunk 2 SSR + Chunk 3 SSR consistently.
2. **CSA-11-F01-D — Chunk 5 signing-scheme SSR.** Reword the "same key family" claim to acknowledge Authenticode and GPG are distinct cryptographic systems; add a separate Speckit Stop Resolution pinning signing-key custody.
3. **PSA-08-F01-D — DP9 process-history clause.** One-sentence strike from pre-spec body; provenance survives in the v0.3.2 changelog.
4. **CSA-10-F01-D — Chunk 5 secondary scope additions.** Either a small DP9 expansion (preferred — covers troubleshooting guide + supported platforms) or accept the residual creep with a note. Lowest leverage of the six but highest doctrinal cleanliness.
5. **CSA-05-F01-D — Gate 1-Schema → 2 predicate 1.** One-word edit: replace "JSON schema or equivalent" with a pinned form.
6. **CSA-11-F02-D — Chunk 4 `tc` claim.** Trim `tc` from the connection-kill mechanism or name its orthogonal purpose. Five-word fix.
7. **CSA-09-F01-D — Chunk 5 reproducibility claim.** Either drop the behavioral criterion or add CSC5-004. Author preference; either is acceptable.

After these are applied, chunking v0.2.1 should be ready for Stage 7 launch without further audit. The XDC and CSA-11-F01-D items are the only ones with non-trivial downstream impact; the rest are cleanliness.
