---
version: 0.1.0
status: draft
created: 2026-05-01
last_modified: 2026-05-01
authors: [pewejekubam, claude]
related: ../../specs/001-delta-recovery-client/pre-spec-strategic-chunking.md
changelog:
  - version: 0.1.0
    date: 2026-05-01
    summary: Initial outbound Gate 002 → 003 evidence bundle
    changes:
      - "Enumerated each Gate 002 → 003 predicate from the chunking-doc with the task ID(s) producing the evidence and the test command + expected output for re-verification."
---

# Outbound Gate 002 → 003 Evidence Bundle (T095)

This document maps each Gate 002 → 003 predicate from `specs/001-delta-recovery-client/pre-spec-strategic-chunking.md` to the concrete tasks and tests producing its evidence. Each row is independently re-verifiable from a clean checkout.

## Predicate matrix

| Gate predicate | Source task(s) | Verification command | Expected outcome |
|---|---|---|---|
| Diagnose pathway runs end-to-end on a small fixture and emits a self-hash-verified plan | T071, T086 | `go test ./tests/integration/ -run US001_30Day` | PASS; plan.json self_hash verifies; FR-005 zero-write invariant holds |
| Plan self-hash round-trip (CSC002-001) | T056, T071 | `go test ./internal/plan/ -run SelfHash` | PASS for all sub-tests including tampered-plan detection |
| Plan canonical-identity bound to verified manifest | T069 | `go test ./tests/integration/ -run CanonicalIdentity` (subsumed by `US001_30Day`) | PASS; plan's `manifest_hash` equals the trust-root the manifest was authenticated against |
| Manifest format-version refusal with exit 7 (CSC002-002) | T028, T030 | `go test ./internal/manifest/ -run FormatVersion ./tests/integration/ -run RigC` | PASS; FormatVersionUnrecognizedError surfaced for `format_version: 2`; doctor maps to exit 7 |
| Five distinct refusal exit codes (SC-006) | T044, T074 | `go test ./tests/integration/ -run SC006` | PASS; running-node=2, ahead-of-canonical=3, version-mismatch=4, capacity=5, permission-readonly=6 |
| SC-001 timing half (≤ 5 min on reference rig, 30-day-divergent fixture) | T072 | `go test -tags reference_rig ./tests/integration/sc001_timing_test.go` on the reference rig | PASS (manual chunk-acceptance gate; see plan.md § Known Coverage Gaps) |
| SC-002 zero-entry plan within 5 min | T068, T073 | `go test -tags reference_rig ./tests/integration/sc002_zero_entry_timing_test.go` (reference rig) plus `go test ./tests/integration/ -run Identical` (small) | PASS; identical-fixture small case green; reference-rig run manual |
| Trust-root mismatch refusal (FR-017, EC-008) with no chunk-store fetch | T026, T030, T032 | `go test ./tests/integration/ -run RigB` | PASS; TrustRootMismatchError surfaced; rig.PostManifestGETs() reports zero post-manifest fetches |
| trust_anchors forward-compat tolerance (FR-018) | T029, T030 | `go test ./tests/integration/ -run RigD` | PASS; non-empty trust_anchors object parsed; doctor proceeds normally |
| Static-binary build with no CGO and no operator-runtime dependencies | T093, T094 | `CGO_ENABLED=0 go build -o /tmp/pnd ./cmd/pocketnet-node-doctor && file /tmp/pnd && ldd /tmp/pnd` | `statically linked`; `not a dynamic executable` |
| `-ldflags -X` build-time injection of Version/Commit/BuildDate/PinnedHash | T012, T013, T093 | `go build -ldflags "-X .../buildinfo.Version=0.1.0 -X .../trustroot.PinnedHash=00...00" -o /tmp/pnd ./cmd/...; /tmp/pnd --version` | `--version` reflects injected values |

## Re-verification

A clean-tree re-run is the single command:

```sh
go test ./...
```

The reference-rig timing tests are intentionally excluded from `go test ./...` via the `//go:build reference_rig` constraint and are exercised by hand on the named reference rig per the chunk-acceptance gate.
