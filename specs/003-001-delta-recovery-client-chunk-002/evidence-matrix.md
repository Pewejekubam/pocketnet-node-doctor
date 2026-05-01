---
version: 0.1.0
status: draft
created: 2026-05-01
last_modified: 2026-05-01
authors: [pewejekubam, claude]
related: ./tasks.md
changelog:
  - version: 0.1.0
    date: 2026-05-01
    summary: Initial evidence matrix mapping every chunk-002-owned FR/SC/EC to its producing task(s)
    changes:
      - "Recorded one-to-many mapping for every requirement chunk 002 owns; enables outbound Gate 002 → 003 audit-trail traversal."
---

# Chunk 002 Evidence Matrix (T096)

Every requirement chunk 002 owns is mapped to the concrete task(s) producing its evidence. Tasks marked `[X]` in [tasks.md](./tasks.md) are the audit-trail surface for the outbound Gate 002 → 003 review.

## Requirement-to-task mapping

| Requirement | Producing task(s) | Notes |
|---|---|---|
| FR-001 | T011, T018, T081 | per-page hash iterator + page-level divergence emission |
| FR-002 | T010, T017, T082 | whole-file hash + whole_file divergence emission |
| FR-003 | T054, T055, T075, T076 | plan schema shape + Marshal/Unmarshal round-trip |
| FR-004 | T065, T084 | summary template (D9) on stderr |
| FR-005 | T064, T071 | zero-write invariant verified by mtime+SHA-256 snapshot before/after |
| FR-010 (+ EC-004) | T038, T046 | running-node predicate (advisory lock + process scan, exit 2) |
| FR-011 | T042, T050 | ahead-of-canonical predicate via SQLite header parse, exit 3 |
| FR-012 | T039, T047 | version-mismatch predicate, exit 4; pocketnet-core-not-on-PATH fail-open |
| FR-013 | T040, T048 | volume-capacity predicate, exit 5 |
| EC-011 | T041, T049 | permission-readonly predicate, exit 6 |
| FR-017 (+ EC-008) | T026, T030, T032 | trust-root authentication; TrustRootMismatchError; zero post-manifest fetch on refusal |
| FR-018 | T028, T029, T030, T034, T035 | format-version + trust_anchors forward-compat tolerance |
| SC-001 (timing half) | T072 | reference-rig 5-min budget; manual gate |
| SC-002 | T068, T073 | zero-entry plan; small + reference-rig variants |
| SC-006 | T044, T074 | five distinct refusal exit codes |
| CSC002-001 | T056, T071 | plan self-hash compute + verify + tamper detection |
| CSC002-002 | T028, T030 | manifest format_version refusal mapped to exit 7 |
| EC-001 | T061, T082 | missing pocketdb → all-files whole_file divergences with `expected_source: "fetch_full"` |
| EC-002 | T062, T082 | partial pocketdb → missing files use fetch_full; present-but-divergent files use normal shape |

## Cross-chunk inheritance surface (chunk 002 → chunk 003)

The following packages inherit unchanged into chunk 003 and form the cross-chunk inheritance contract:

- `internal/canonform`
- `internal/hashutil`
- `internal/exitcode`
- `internal/stderrlog`
- `internal/buildinfo`
- `internal/trustroot`
- `internal/manifest`
- `internal/plan`
- `internal/preflight`
- `internal/cli` (subcommand surface)

Chunk 003 ships the `apply` subcommand body. The CLI surface, exit-code allocation, plan schema, and predicate ordering are frozen by chunk 002.
