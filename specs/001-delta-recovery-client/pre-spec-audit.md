---
version: 0.1.0
status: draft
created: 2026-04-30
last_modified: 2026-04-30
authors: [claude]
related: pre-spec.md
changelog:
  - version: 0.1.0
    date: 2026-04-30
    summary: Initial adversarial audit of pre-spec.md v0.2.1 against audit-criteria.md
    changes:
      - "PSA-11: rollback-instrument and plan-format are unanswered plan-stage stops (3b-class)"
      - "PSA-04: HTTP, fsync+rename, PRAGMA integrity_check, exponential backoff prescribed in FR bodies"
      - "PSA-01: FR-007 prescribes staging mechanism; FR-015 names a specific SQLite pragma"
      - "PSA-03: SC-001 'commodity hardware' and SC-008 'every N MB' are unmeasurable as written"
      - "PSA-06: trust-root authentication mechanism (signature vs. hash compare) is left implicit"
      - "PSA-07: EC-002 and EC-007 ownership across diagnose/apply is incomplete"
---

# Pre-Spec Audit: Delta Recovery Client for Pocketnet Operators

## Summary

The pre-spec is structurally well-formed: traceability is intact, scope is bounded, the trust-hardening deferral is explicit, and the empirical baseline (85.83% page reuse) is loaded into Implementation Context where it belongs. The dominant risk is concentrated in PSA-11: at least two plan-stage stops in the Chunk-3b class are unanswered (the rollback instrument behind FR-009; the plan-artifact format and self-hash schema behind FR-003 / EC-009), and several FRs leak prescription that should live in Implementation Context (HTTP transport, fsync+rename mechanism, `PRAGMA integrity_check`, exponential backoff). Net assessment: not yet ready for `speckit.specify` fire-and-forget — Stage 3 must close the rollback-instrument gap and scrub three to four prescription leaks before the chunking pass.

## Severity legend

- **CRITICAL** — blocks fire-and-forget. Pipeline will halt at superb.review or drift silently. Must fix before Stage 3 exits.
- **HIGH** — degrades pipeline output quality or forces defensive-default fallback at clarify/plan time. Should fix.
- **MEDIUM** — quality issue. Pipeline will likely produce correct output but with avoidable friction. Consider fixing.
- **LOW** — stylistic, terminology, or organizational. Optional.

## Findings by criterion

### PSA-01: Outcome Focus

#### PSA-01-F01

**ID:** PSA-01-F01
**Severity:** HIGH
**Locus:** FR-007
**Finding:** FR-007 prescribes the atomicity mechanism: "stages every fetched chunk in a separate location, fsyncs it, and only promotes it into place via an atomic rename." Staging + fsync + rename is one valid implementation of atomic-promotion; it is not the requirement. The requirement is "no observer ever sees a mixed-version pocketdb." The mechanism belongs in Implementation Context.
**Why it matters:** `speckit.specify` will treat "fsync" and "atomic rename" as named capabilities to spec and test for. `speckit.plan` then loses the freedom to evaluate equivalent atomicity strategies (e.g., overlay filesystem, btrfs snapshot, alternative crash-safety primitives) and `speckit.tasks` generates fsync-specific tasks. The outcome — atomicity at artifact boundary — is already covered in Design Principle 3 and the US-002 acceptance scenarios.
**Recommendation:** Reword FR-007 to outcome form ("Apply phase guarantees that no concurrent observer ever reads a partially-promoted file") and move fsync+rename into the Implementation Context "Technology defaults" subsection.

#### PSA-01-F02

**ID:** PSA-01-F02
**Severity:** HIGH
**Locus:** FR-015
**Finding:** FR-015 names a specific SQLite primitive: "Doctor runs `PRAGMA integrity_check` on `main.sqlite3` after apply." This binds the requirement to one verification instrument that happens to be the right choice for SQLite, but it should be expressed as the outcome ("verifies that the post-apply `main.sqlite3` is structurally valid by SQLite's own consistency checker") with the pragma name in Implementation Context.
**Why it matters:** If a future SQLite version changes pragma semantics or another instrument becomes preferred, an outcome-form FR survives the change. More immediately: pinning the pragma in the FR removes plan-stage room to discuss the choice (no big deal here, but it's the same shape as the Chunk-3b instrument-pinning leak).
**Recommendation:** Reframe FR-015 as "Apply verifies post-apply structural validity of `main.sqlite3` using SQLite's native consistency checker" and document the pragma name in Implementation Context.

#### PSA-01-F03

**ID:** PSA-01-F03
**Severity:** MEDIUM
**Locus:** FR-019
**Finding:** "Bounded exponential backoff" is a specific retry strategy. The outcome-form requirement is "tolerates transient network failures and bounds total retry budget." Exponential backoff is one strategy; jittered, capped, or deadline-bounded variants are equivalent.
**Why it matters:** Mild prescription leak. Locks `speckit.plan` to a specific algorithm where the operational requirement is "doesn't get stuck retrying forever and doesn't give up on first transient failure."
**Recommendation:** Replace "bounded exponential backoff" in FR-019 with outcome language; move the algorithm choice into Implementation Context.

### PSA-03: Testability

#### PSA-03-F01

**ID:** PSA-03-F01
**Severity:** HIGH
**Locus:** SC-001
**Finding:** "within 5 minutes on commodity hardware" — "commodity hardware" is undefined. Two reasonable readings (a 2018 Intel NUC vs. a current Ryzen workstation) differ by 4-5x in I/O and hash-throughput. The threshold is therefore not a binary pass/fail criterion in practice.
**Why it matters:** SC-001 will be carried into `spec.md` as an acceptance test. Without a hardware floor (CPU model class, disk type, memory floor), implementers and reviewers cannot agree whether a measured timing run passes. `speckit.tasks` may generate a benchmark task with no reference rig.
**Recommendation:** Either (a) name a reference rig (e.g., "8 vCPU x86_64 host, NVMe-class disk, 16 GB RAM") in SC-001 or Implementation Context, or (b) drop the absolute timing and re-cast the SC as a throughput ratio against a published baseline.

#### PSA-03-F02

**ID:** PSA-03-F02
**Severity:** MEDIUM
**Locus:** SC-008
**Finding:** "intermittent network connection (simulated drops every N MB)" — N is undefined. The acceptance test cannot be executed without picking N, and different N values exercise different code paths (frequent drops stress retry/resume; rare drops stress nothing).
**Why it matters:** Clarify-stage will surface this as a question; plan-stage will pick a value defensively. Pre-answering it costs one sentence.
**Recommendation:** Pin N (e.g., "drops every 256 MB on a 4 GB total fetch") or convert to a count of drops per run.

#### PSA-03-F03

**ID:** PSA-03-F03
**Severity:** MEDIUM
**Locus:** SC-007
**Finding:** "reports the canonical pocketnet block height as ancestor" — "ancestor" is technically correct but underdefined for a pass/fail check. Does the test inspect a specific RPC, a log line, a chain database read? Without naming the observation point, the SC is ambiguous to operationalize.
**Why it matters:** A reviewer cannot know whether the drill passed without inspecting plan-stage choices. This is the kind of ambiguity that lands in spec.md as `[NEEDS CLARIFICATION]` and forwards to clarify-stage.
**Recommendation:** Name the observation surface ("`pocketnet-core` `getbestblockhash` returns a block at or descended from the canonical's pinned height") in SC-007 or in a glossary entry pinning "ancestor" for this domain.

### PSA-04: Prescription Leaks

#### PSA-04-F01

**ID:** PSA-04-F01
**Severity:** HIGH
**Locus:** FR-006
**Finding:** FR-006 prescribes the transport: "fetches each listed chunk from the canonical chunk store via HTTP." HTTP is the chosen transport, but pre-spec FRs should say "via the canonical chunk store's published transport" and route HTTP to Implementation Context.
**Why it matters:** Same shape as PSA-01-F01 — the FR is a vehicle for design rather than outcome. `speckit.plan` is already constrained by Implementation Context's "HTTPS GET" entry; the FR doesn't need to repeat the constraint.
**Recommendation:** Outcome-form FR-006: "Apply fetches each plan-listed chunk from the canonical chunk store." Move HTTP/HTTPS to Implementation Context (already partially there).

#### PSA-04-F02

**ID:** PSA-04-F02
**Severity:** MEDIUM
**Locus:** FR-011
**Finding:** "`main.sqlite3` header `change_counter`" names a specific SQLite header field as the ahead-of-canonical signal. This is the right field for the right reason, but the requirement is "ahead-of-canonical detection," not "read this exact field."
**Why it matters:** If the manifest later carries a redundant block-height field that's faster to compare, the FR's wording locks the implementation. Mild leak; the scope-pin lives in the requirement rather than in Implementation Context.
**Recommendation:** Outcome-form FR-011 ("if the local node's pocketdb is at a state strictly newer than the canonical, refuse"), with the change_counter mechanism documented in Implementation Context.

### PSA-06: Scope Clarity

#### PSA-06-F01

**ID:** PSA-06-F01
**Severity:** HIGH
**Locus:** FR-017, Implementation Context > Technology defaults > Trust root, EC-008
**Finding:** The trust-root authentication mechanism is implicitly two different things in two places. FR-017 says "verifies the canonical manifest's authenticity against a project-pinned trust root" (suggestive of signature verification with a public key). Implementation Context says "HTTPS + manifest SHA-256" (a hash compare against a pinned constant, no public-key signature). EC-008 says "Manifest signature/hash verification fails" (compounds the ambiguity by listing both).
**Why it matters:** Plan-stage stop. `speckit.plan` will need to choose between (a) ship a public key with the binary and verify a detached signature against the manifest, or (b) ship a pinned manifest hash and compare. These are materially different implementations with different threat models, different update procedures, and different bootstrap surfaces. The pre-spec must pin one — not because the choice is irreversible (FR-018 explicitly preserves chain-anchoring optionality) but because plan-stage will otherwise resolve in context.
**Recommendation:** In Stage 3, decide v1's mechanism (almost certainly pinned-hash given the "HTTPS + manifest SHA-256" Implementation Context note) and amend FR-017 + EC-008 to use a single consistent term ("trust-root hash" or "trust-root signature"). Treat any continued ambiguity as a 3b-class plan-stage risk.

#### PSA-06-F02

**ID:** PSA-06-F02
**Severity:** MEDIUM
**Locus:** Vision, FR-001, FR-002, Implementation Context > Technology defaults
**Finding:** "Whole file" applies to "non-SQLite artifacts" but the canonical pocketdb tree (`blocks/`, `chainstate/`, `indexes/`, "any other files") is not enumerated definitively. The phrase "any other files in the canonical" in FR-002 leaves the surface open-ended. If a future canonical drops a new top-level file, does diagnose recognize it or skip it?
**Why it matters:** Edge-case omission for pocketdb evolution. Clarify-stage may surface "what if pocketdb gains a new artifact class?" with no top-rung answer. Defensive-default will be "manifest is authoritative; fetch what manifest lists" — which is fine as a default, but should be the explicit pre-spec answer.
**Recommendation:** Add a one-sentence pre-spec answer pinning "manifest is authoritative for the artifact set; doctor fetches what manifest lists and ignores local files not in manifest" — or amend with the inverse (any local file not in manifest is a divergence to be removed). Pick one, declare it.

### PSA-07: Edge Case Distribution

#### PSA-07-F01

**ID:** PSA-07-F01
**Severity:** MEDIUM
**Locus:** EC-002
**Finding:** EC-002 ("Local pocketdb is partially present") is assigned only to US-001 (diagnose). Apply on a partially-present pocketdb is also a real path — diagnose produces a plan that's nearly equivalent to a full fetch, then apply must execute it without conflating "missing" with "needs replacement."
**Why it matters:** During chunking (Stage 4), the edge case will follow US-001 into a diagnose chunk. The apply chunk may not see it, and `speckit.specify` won't generate apply-side handling for the partial-present case.
**Recommendation:** Add US-002 to the EC-002 assignment list.

#### PSA-07-F02

**ID:** PSA-07-F02
**Severity:** LOW
**Locus:** EC-007
**Finding:** EC-007 (disk I/O error during staging) is assigned to US-002 and US-003. US-003 is the refusal-set story; an I/O error during staging is not a pre-flight refusal — it's a mid-apply fatal. The assignment to US-003 is questionable.
**Why it matters:** Chunking will distribute EC-007 to two chunks based on this assignment, including the refusal-predicate chunk where it doesn't belong.
**Recommendation:** Drop US-003 from EC-007's assignment, or split the edge case into pre-flight (insufficient permissions; goes to US-003) vs. mid-run (I/O fault; stays with US-002).

### PSA-10: Implementation Context Separation

#### PSA-10-F01

**ID:** PSA-10-F01
**Severity:** MEDIUM
**Locus:** FR-001
**Finding:** FR-001 names "canonical 4 KB page boundaries" inside the FR body. The 4 KB granularity is an empirical Implementation Context decision (validated in `experiments/01-page-alignment-baseline/`), not a requirement of the system.
**Why it matters:** Same prescription-leak shape: the FR's outcome is "page-level diff for `main.sqlite3` against manifest hashes;" the granularity is an Implementation Context default. As written, `speckit.plan` is denied space to discuss whether 4 KB is right (it is, but the discussion belongs at plan stage).
**Recommendation:** Outcome-form FR-001 ("Doctor computes per-page hashes of `main.sqlite3` matching the manifest's page-grid"), keep the 4 KB pin in Implementation Context (already there).

### PSA-11: SpecKit Stop Coverage

#### PSA-11-F01

**ID:** PSA-11-F01
**Severity:** CRITICAL
**Locus:** FR-009 (rollback instrument)
**Finding:** FR-009 says apply "preserves a snapshot of pre-apply state sufficient to restore on failure" — the WHAT is pinned, the HOW is not. The rollback instrument is unanswered: hardlink shadow tree, file-by-file backup copy, filesystem-level snapshot (btrfs/zfs), reverse-diff log? Each has materially different disk-space cost, recovery semantics, and crash-safety profile. The pre-spec is silent on the mechanism.
**Why it matters:** This is the Chunk-3b class plan-stage stop. `speckit.plan`'s autonomous resolution ladder has no top-rung answer. Plan will pick one in context — likely a defensive "double the disk requirement and copy every targeted file before overwrite," which (a) inflates FR-013's free-space refusal threshold, (b) materially changes the apply-time wire-cost-vs-disk-cost trade-off, and (c) propagates into FR-008's resumability state model. None of these are intentional design decisions — they're plan-stage drift.
**Recommendation:** Stage 3 must add a pre-spec answer naming the rollback instrument. Implementation Context > Technology defaults is the correct home. A one-sentence pin ("Rollback uses a per-file shadow copy taken at staging time; on failure the shadow is renamed back into place" or equivalent) closes the stop. Cross-reference from FR-009 and FR-013 is enough.

#### PSA-11-F02

**ID:** PSA-11-F02
**Severity:** CRITICAL
**Locus:** FR-003, EC-009, Key Entities > Plan
**Finding:** The plan artifact's wire format is unpinned. FR-003 says "machine-readable plan listing every divergence." US-001 narrates `plan.json` casually. EC-009 references "embedded self-hash" — but the Plan entity description in Key Entities does not declare a self-hash field, and the format (JSON / msgpack / sqlite / signed envelope) is silent. The schema is a plan-stage stop.
**Why it matters:** Plan-stage will pick a format. Tasks-stage will generate tasks against that format. Diagnose and apply are coupled through this artifact (Design Principle 5 — "plan is durable and self-describing"), so any format change later requires lock-step amendment of both phases. Without a pre-spec pin, the chunking doc's diagnose chunk and apply chunk can land on different mental models of the artifact and the integration path fails late.
**Recommendation:** Pin the plan artifact in Implementation Context: format (JSON is fine), required top-level fields (canonical identity, divergence list, self-hash, format version), and the self-hash mechanism (HMAC over canonical identity + divergence list, or simple SHA-256 of canonical-form payload). Roll into the Key Entities > Plan description.

#### PSA-11-F03

**ID:** PSA-11-F03
**Severity:** HIGH
**Locus:** FR-008, Key Entities > Plan
**Finding:** Resumability state location is unanswered. FR-008 says re-running with the same plan continues from where the prior run stopped — but where is "where it stopped" persisted? Inside the plan file? In a sidecar progress file? In the staging directory's filesystem state? Three reasonable answers; pre-spec is silent.
**Why it matters:** Plan-stage stop, immediately downstream of PSA-11-F02. Without a pre-declared answer, plan will choose, and the choice ripples into FR-007 (staging mechanism), FR-009 (rollback semantics on a partially-resumed run), and FR-020 (skip-already-fetched).
**Recommendation:** Pin the resumability-state location alongside PSA-11-F02's plan-format pin. Most natural: per-chunk completion markers in the staging directory; plan file is read-only progress-wise.

#### PSA-11-F04

**ID:** PSA-11-F04
**Severity:** HIGH
**Locus:** FR-014, FR-007 (interaction)
**Finding:** Verification timing relative to atomic rename is unspecified. Does the doctor verify each fetched chunk's hash against the manifest BEFORE atomic rename (preventing a corrupt chunk from ever entering the live tree) or AFTER (verifying the in-place result)? FR-014 ("verifies every file written during apply matches the canonical manifest hash bitwise") admits both readings.
**Why it matters:** Chunk-3b class plan-stage stop. Pre-rename verification means the staging area is the policy boundary; post-rename verification means the live tree may transiently hold unverified bytes (rolled back if verification fails). The two have different rollback complexities and different concurrency-safety properties for the running-pocketnet-core-restart case.
**Recommendation:** Pin pre-rename verification (the safer choice and the natural reading of Design Principle 3 "stages, fsyncs, then renames"). Add a one-sentence note in FR-014 or Implementation Context.

#### PSA-11-F05

**ID:** PSA-11-F05
**Severity:** HIGH
**Locus:** Implementation Context > Technology defaults > Compression
**Finding:** Compression choice is explicitly deferred: "Gzip or Zstandard for chunk-store payloads. Not prescribed at pre-spec level; plan-stage decision based on cache hit ratio and CPU vs. bandwidth trade-off." This is a legitimate plan-stage deferral, BUT the doctor is the client; it must accept whichever the chunk store ships. The deferral leaves open: does the doctor support both? Does it negotiate? Is there a fallback?
**Why it matters:** Lower-priority than F01-F04, but it's a plan-stage stop with a defensive default ("support both; prefer Zstandard") that may or may not match the chunk-store side's choice. If the server-side `pocketnet_create_checkpoint` extension picks one and the doctor picks the other, integration fails.
**Recommendation:** Either (a) pin one (Zstandard is the conventional choice for new infrastructure) and remove the deferral, or (b) add a chunking-doc Speckit Stop Resolution declaring "doctor accepts whatever Content-Encoding the chunk store advertises; supports gzip and zstd at minimum." The latter defers to chunking and is acceptable.

#### PSA-11-F06

**ID:** PSA-11-F06
**Severity:** MEDIUM
**Locus:** US-005, Implementation Context > Sibling project context
**Finding:** The drill (US-005) implicitly depends on a published canonical. The pre-spec doesn't pin whether the drill canonical is a project-published canonical, a private fixture, or an artifact generated by `pocketnet_create_checkpoint` for the test specifically. Plan-stage will pick.
**Why it matters:** Less-critical because US-005 is P2 and drill setup naturally lives in test-rig configuration. But the dependency on `pocketnet_create_checkpoint`'s output schema is real and chunking will need to express it.
**Recommendation:** Defer to chunking-doc Speckit Stop Resolutions. Note in Stage 3 that the drill chunk needs to declare its canonical source.

#### PSA-11-F07

**ID:** PSA-11-F07
**Severity:** MEDIUM
**Locus:** Implementation Context > Technology defaults > Concurrency
**Finding:** "Apply may parallelize chunk fetches" is permissive, not prescriptive. Plan-stage will pick a parallelism cap (1, 4, 8, dynamic-by-bandwidth?). No pre-declared answer.
**Why it matters:** Tasks-stage stop more than plan-stage; the cap is plumbing. Defensive default ("4-way parallel fetches") will likely be fine.
**Recommendation:** Either pin a default cap in Implementation Context, or accept the plan-stage defensive default. This is the lowest-priority PSA-11 finding.

## PSA-11 SpecKit Stop Coverage matrix

For each pipeline stage, inventoried stops are listed with resolution status. "resolved-by-pre-spec" means the pre-spec contains text that answers the stop without fall-through. "deferred-to-chunking-doc" means the answer legitimately belongs at chunk granularity. "unanswered" is a CRITICAL or HIGH PSA-11 finding.

### Specify-stage

| Stop | Status | Notes |
|---|---|---|
| Ambiguous FR term | resolved-by-pre-spec | Design Principles + Key Entities pin the domain vocabulary |
| Unspecified acceptance scenario for a US | resolved-by-pre-spec | Every US carries Given/When/Then |
| SC that isn't measurable | partially unanswered | SC-001 ("commodity hardware"), SC-008 ("every N MB"), SC-007 ("ancestor") — see PSA-03 findings |

### Clarify-stage

| Stop | Status | Notes |
|---|---|---|
| FR term ambiguity ("verification") | resolved-by-pre-spec | FR-014/015 pin verification = SHA-256 + integrity_check |
| FR term ambiguity ("authenticity" / "trust root") | unanswered | PSA-06-F01 — signature vs. hash compare |
| Scope boundary ("partial pocketdb" in apply) | unanswered | PSA-07-F01 — EC-002 not assigned to US-002 |
| Edge-case omission (pocketdb gains new artifact class) | unanswered | PSA-06-F02 — manifest authority not declared |
| Terminology drift | resolved-by-pre-spec | "pocketnet block height" disambiguated in v0.2.0 |

### Plan-stage

| Stop | Status | Notes |
|---|---|---|
| Technology choice (HTTP transport) | resolved-by-pre-spec | Implementation Context "HTTPS GET" |
| Architectural pattern (sync vs. event-driven) | resolved-by-pre-spec | Apply is sequential per file; per-chunk parallel |
| Data shape (plan artifact format) | **unanswered** | **PSA-11-F02 (CRITICAL)** |
| Testing strategy | deferred-to-chunking-doc | Per-chunk Speckit Stop Resolutions |
| Integration pattern (server-side counterpart) | deferred-to-chunking-doc | Reference to `pocketnet_create_checkpoint` epic child `delt.3` |
| Error-handling posture (fail-fast vs. retry) | resolved-by-pre-spec | FR-019, Design Principle 4 |
| Concurrency model (fetch parallelism cap) | unanswered | PSA-11-F07 — low priority |
| **Verification instrument (post-apply)** | resolved-by-pre-spec | FR-014/015 pin SHA-256 + integrity_check |
| **Verification timing (pre- vs. post-rename)** | **unanswered** | **PSA-11-F04 (HIGH)** |
| **Rollback instrument** | **unanswered** | **PSA-11-F01 (CRITICAL)** |
| Resumability state location | unanswered | PSA-11-F03 (HIGH) |
| Compression negotiation | deferred-to-chunking-doc | PSA-11-F05 |
| Trust-root authentication mechanism | unanswered | PSA-06-F01 (HIGH) |

### Tasks-stage

| Stop | Status | Notes |
|---|---|---|
| Task count > 100 | resolved-by-pre-spec | Scope is bounded; chunking will further bound |
| FR uncovered | resolved-by-pre-spec | All FRs trace to USs and SCs |
| Phase boundary ambiguity | resolved-by-pre-spec | Diagnose / Apply / Refusal / Verification / Trust / Network are distinct functional areas |

### Analyze-stage

| Finding class | Status | Notes |
|---|---|---|
| Coverage gap | resolved-by-pre-spec | Traceability is intact |
| Terminology drift | resolved-by-pre-spec | Single-term use is consistent (one exception: "manifest signature/hash" in EC-008) |
| Requirement/task misalignment | deferred-to-chunking-doc | Will be visible at Stage 5 |

### Superb.review

| Block condition | Status | Notes |
|---|---|---|
| Known Issues from clarify fall-through | at risk | If PSA-11-F01 / F02 / F04 are not closed, clarify will fall through and Known Issues will land at superb.review |
| TDD-readiness gap | resolved-by-pre-spec | SCs are mostly testable; SC-001/008 need tightening (see PSA-03) |
| Scope-change signal in Known Issues | resolved-by-pre-spec | Out-of-scope section is explicit |

## Pass list

- **PSA-02 (Traceability)** — every US has at least one SC; every FR backs at least one US; no orphaned SCs. Triad is intact.
- **PSA-05 (Inherited Capabilities)** — doctor is a green-field build; no MCP server / library adoption inflating the FR list.
- **PSA-08 (Declarative Tone)** — body is declarative throughout. Version history confined to changelog.
- **PSA-09 (NEEDS CLARIFICATION Hygiene)** — zero clarification markers in pre-spec body.

## Recommended Stage 3 priorities

1. **Close PSA-11-F01 (rollback instrument).** This is the single highest-impact gap. One sentence in Implementation Context > Technology defaults pinning the rollback mechanism (per-file shadow copy + reverse-rename is the conventional safe choice) closes the stop and de-risks FR-009 / FR-013 interaction.
2. **Close PSA-11-F02 (plan artifact format and self-hash).** Pin format (JSON), required fields, self-hash mechanism. Update Key Entities > Plan accordingly. EC-009's "embedded self-hash" needs a corresponding field declaration.
3. **Close PSA-06-F01 (trust-root authentication mechanism).** Decide signature vs. hash compare, normalize FR-017 + EC-008 + Implementation Context to use one term consistently.
4. **Close PSA-11-F04 (pre-rename verification).** One sentence in FR-014 or Implementation Context.
5. **Close PSA-11-F03 (resumability state location).** Naturally bundled with the plan-format pin from priority 2.
6. **Scrub prescription leaks (PSA-01 + PSA-04).** FR-001 (4 KB), FR-006 (HTTP), FR-007 (fsync+rename), FR-011 (change_counter), FR-015 (PRAGMA), FR-019 (exponential backoff). Mechanical reword to outcome form, push details to Implementation Context.
7. **Tighten unmeasurable SCs (PSA-03).** SC-001 reference rig, SC-008 N value, SC-007 observation surface.
8. **Fix EC distribution (PSA-07).** EC-002 add US-002; EC-007 trim US-003 or split.
9. **Defer PSA-11-F05 (compression) and PSA-11-F06 (drill canonical) to chunking-doc Speckit Stop Resolutions.** Note in the Stage 3 hand-off so Stage 4 carries them forward.
