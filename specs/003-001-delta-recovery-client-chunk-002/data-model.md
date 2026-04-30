# Phase 1 Data Model: Plan, Manifest-as-Consumed, Refusal-Predicate, Trust-Root

**Branch**: `003-001-delta-recovery-client-chunk-002` | **Date**: 2026-04-30 | **Plan**: [plan.md](plan.md)

## Scope

This document is the human-readable companion to [contracts/plan.schema.json](contracts/plan.schema.json) and [contracts/cli-surface.md](contracts/cli-surface.md). It enumerates the entities this chunk produces or consumes, their fields, validation rules, and inter-entity relationships. The JSON Schema is normative for `plan.json`; this document is descriptive.

## Entity: Plan

The artifact this chunk produces — written by `diagnose` to the file at the resolved `--plan-out` path. Read-only after emission; consumed by Chunk 003's apply without mutation.

### Fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `format_version` | integer | yes | Initial value `1`. Increments on schema-incompatible change (post-v1; pre-spec Implementation Context plan-artifact). |
| `canonical_identity` | object | yes | See [Sub-entity: Canonical Identity](#sub-entity-canonical-identity-plan). |
| `divergences` | array of objects | yes | One element per divergent file or per divergent `main.sqlite3` page run. Element shape varies by `divergence_kind` discriminator — see [Sub-entity: Divergence](#sub-entity-divergence). |
| `self_hash` | string (64-char lowercase hex) | yes | SHA-256 over the plan's canonical-form payload with the `self_hash` field removed (sorted JSON keys, no insignificant whitespace, UTF-8 — pre-spec Implementation Context canonical-form rule). |

### Validation rules

- All four fields above MUST be present. No additional top-level fields are permitted (`unevaluatedProperties: false` in the schema — matches Chunk 001 manifest precedent).
- Field key order in producer output MUST follow canonical-form serialization (sorted JSON keys, no insignificant whitespace, UTF-8).
- `self_hash` is computed as: serialize the Plan with `self_hash` field removed, in canonical form; SHA-256 the resulting bytes; hex-encode lowercase.
- A consumer (Chunk 003 apply) verifies tamper by re-computing `self_hash` and comparing.

### Sub-entity: Canonical Identity (plan)

| Field | Type | Required | Notes |
|---|---|---|---|
| `block_height` | integer | yes | Pocketnet block height the canonical was minted at. Copied verbatim from the verified manifest's `canonical_identity.block_height`. |
| `manifest_hash` | string (64-char lowercase hex) | yes | The SHA-256 trust-root value the manifest was authenticated against (= the compiled-in trust-root constant for a successful run). Copied verbatim from `internal/trustroot.PinnedHash` at the moment of verification. |
| `pocketnet_core_version` | string | yes | Exact `pocketnet-core` version the canonical was built against. Copied verbatim from the verified manifest's `canonical_identity.pocketnet_core_version`. |

### Validation rules (canonical_identity)

- `block_height`: non-negative integer.
- `manifest_hash`: 64-character lowercase hex regex `^[0-9a-f]{64}$`.
- `pocketnet_core_version`: non-empty string; bytes echo the manifest field.

### Sub-entity: Divergence

Element of the plan's `divergences` array. Shape selected by the `divergence_kind` discriminator:

- `divergence_kind: "sqlite_pages"` — page-level entry for `pocketdb/main.sqlite3` (or any other SQLite-shaped artifact under `pocketdb/`) where one or more 4 KB pages differ.
- `divergence_kind: "whole_file"` — whole-file entry for non-SQLite artifacts, or for an `sqlite_pages` artifact whose entire file is missing locally.

#### Shape: `sqlite_pages` divergence

| Field | Type | Required | Notes |
|---|---|---|---|
| `divergence_kind` | string | yes | Literal `"sqlite_pages"`. |
| `path` | string | yes | Forward-slash relative path, rooted at the pocketnet data directory (e.g., `"pocketdb/main.sqlite3"`). No leading slash. Verbatim from manifest entry. |
| `pages` | array of `{offset, expected_hash}` objects | yes | One element per divergent page. Sorted by `offset` ascending. **Subset of the canonical's pages array** — only pages whose local hash differs from canonical (or whose local file is too short to reach the offset). |

`offset` is a non-negative multiple of 4096; `expected_hash` is the canonical page hash from the manifest entry (64-char lowercase hex). Local hashes are intentionally NOT recorded — the plan declares "what canonical looks like at this offset" so apply can fetch + verify against the recorded hash. Local-side state is observable from `pocketdb/` directly.

#### Shape: `whole_file` divergence

| Field | Type | Required | Notes |
|---|---|---|---|
| `divergence_kind` | string | yes | Literal `"whole_file"`. |
| `path` | string | yes | Forward-slash relative path (e.g., `"blocks/000123.dat"`). Verbatim from manifest entry. |
| `expected_hash` | string (64-char lowercase hex) | yes | Whole-file SHA-256 of the canonical file, copied verbatim from manifest entry's `hash`. |
| `expected_source` | string | optional | When present, must equal `"fetch_full"`. Indicates the file is missing locally (per Chunk 003's EC-002 partial-pocketdb plan contract — chunking-doc Speckit Stop). Apply consumes this to skip pre-apply shadowing (no original to shadow). |

### Validation rules (divergence)

- `divergence_kind` discriminates: schema uses `oneOf` keyed on the value. Unknown values are schema-invalid.
- `path` is non-empty, contains no `..` segments, no leading `/`, no Windows-style separators. Path components are restricted to the same regex Chunk 001 uses: `[A-Za-z0-9_.\-]` per character; `/` separator between components.
- For `sqlite_pages`: `pages` is non-empty (an entry with zero divergent pages would not be in the plan); each page object's `offset` is a non-negative multiple of 4096; pages strictly sorted by `offset` ascending; no duplicate offsets.
- For `whole_file`: `expected_hash` matches `^[0-9a-f]{64}$`; `expected_source` if present equals `"fetch_full"`.

### Relationship: divergence → manifest entry

Every `divergence` element has a 1:1 correspondence with a Chunk 001 manifest entry (selected by `path`). The `expected_hash` (whole-file) or per-page `expected_hash` (sqlite_pages) is taken verbatim from the manifest. This means apply can fetch the chunk URL constructed from `(plan.canonical_identity.block_height, divergence.path, [divergence.pages[i].offset])` per Chunk 001's chunk-URL grammar, and verify the fetched bytes against the recorded hash without re-consulting the manifest.

### State transitions

The plan is read-only after diagnose emits it. Mutation by any consumer is a contract violation.

- **Created**: by `diagnose`, after pre-flight predicates pass and manifest verification succeeds.
- **Consumed**: by `apply` (Chunk 003), atomically. Apply reads the plan, verifies `self_hash`, fetches and applies divergences. The plan file itself is never written by apply.
- **Discarded**: by the operator manually after a successful apply, or implicitly if the staging directory is cleaned up. No automatic-deletion contract.

## Entity: Manifest (consumed)

The frozen-schema JSON document published by Chunk 001 at `<base>/canonicals/<block_height>/manifest.json`. Chunk 002 consumes it; the schema and entity model are owned by [Chunk 001's data-model.md](../002-001-delta-recovery-client-chunk-001/data-model.md) and [Chunk 001's manifest schema](../002-001-delta-recovery-client-chunk-001/contracts/manifest.schema.json).

### Fields the doctor consumes

- `format_version` — used for FR-018 forward-compat refusal (CSC002-002).
- `canonical_identity.block_height` — copied into `Plan.canonical_identity.block_height`.
- `canonical_identity.pocketnet_core_version` — copied into `Plan.canonical_identity.pocketnet_core_version`; also compared against the local `pocketnet-core` binary version for FR-012.
- `entries[*]` — page-level entries for `sqlite_pages`, whole-file entries for `whole_file`. Drives the doctor's per-page and per-file hash comparisons.
- `entries[*]` (where `path == "pocketdb/main.sqlite3"`) `change_counter` — used by FR-011's ahead-of-canonical refusal predicate.
- `trust_anchors` — parsed for presence (required field per Chunk 001 schema); contents ignored in v1 per FR-018.

### The doctor does not consume

- `entries[*].pages[*].hash` is consumed during diagnose (compared against locally-computed page hash) but **not copied verbatim into the plan unless that page is divergent**. Reused-pages' hashes do not appear in the plan.

## Entity: Refusal Predicate

A pre-flight check that, on a positive trigger, emits a diagnostic on stderr and exits with a distinct exit code. Five v1-enumerated predicates:

| Predicate | Exit code | Order | Mechanism (D7, D8) |
|---|---|---|---|
| running-node | 2 | 1st | advisory-lock probe + process-table scan (D8) |
| pocketnet-core-version mismatch | 4 | 2nd | local `pocketnet-core` binary `--version` invocation; string-compare against `manifest.canonical_identity.pocketnet_core_version` |
| volume-capacity | 5 | 3rd | `statfs(2)` on the resolved `--pocketdb` parent volume; required free space = 2 × sum of plan-listed-files-size; predicate fires when free space < required |
| permission/read-only | 6 | 4th | `access(W_OK)` probe + mount-flag check (read-only mount) on the volume holding `pocketdb/` |
| ahead-of-canonical | 3 | 5th | direct SQLite-header parse of `pocketdb/main.sqlite3` (D7); `local_change_counter > canonical_change_counter` |

### Behavioral contract

- Each predicate is `func(ctx PreflightContext) PredicateResult`.
- `PredicateResult` is either `Pass` or `Refuse{Code int, Diagnostic string}`.
- The orchestrator evaluates predicates in the table's `Order` column, **stops at first refusal** (per spec Q2/A2), and emits exactly one diagnostic + exit code.
- Each predicate MUST perform zero writes against `pocketdb/`. Read-only filesystem operations only.
- Predicates emit no diagnostic on Pass; only on Refuse.

### Special case: pocketnet-core binary version probe (FR-012)

The version-mismatch predicate invokes the local `pocketnet-core` binary with a version-printing flag (`--version` or equivalent — exact flag is plan-stage-deferred to task-stage; bash equivalent: `pocketnet-core --version 2>&1 | head -n1`) and parses the version string. If `pocketnet-core` is not on `PATH`, the predicate fails open (cannot evaluate version) and the doctor returns generic exit code 1 with a diagnostic naming the missing binary — not the version-mismatch refusal. Operator-runnable doctor presupposes `pocketnet-core` is installed (per pre-spec Out-of-Scope: "Driving `pocketnet-core` is the operator's job").

## Entity: Trust-Root Constant

A pinned-hash credential the doctor binary is built against. Pre-spec defines two co-published shapes (server-side sidecar file + compiled-in client constant). Chunk 002 consumes the compiled-in shape.

### In-memory shape (this chunk)

A package-level `var` in `internal/trustroot/trustroot.go`:

```go
package trustroot

var PinnedHash = "a939828d349bc5259d2c79fe9251d4e3497d2d1518c944dfc91ae9594f029249"
```

Overridable at build time via `go build -ldflags "-X internal/trustroot.PinnedHash=<64-hex>"`.

### Construction (re-statement)

```
PinnedHash == SHA-256( canonical_form_serialize(manifest_json) )
```

The doctor authenticates a fetched manifest by:

1. Parsing the manifest bytes into a typed Go struct.
2. Re-serializing the struct using `internal/canonform` (sorted keys, no insignificant whitespace, UTF-8).
3. Computing SHA-256 over the re-serialized bytes.
4. Comparing to `PinnedHash`. Mismatch → refusal with EC-008 diagnostic; no chunk-store byte fetch attempted.

## Entity: Pre-flight Context

Internal aggregate threaded through predicate evaluation. Holds the resolved `--pocketdb` path, the verified manifest (after manifest verification completes — version-mismatch and ahead-of-canonical use it), and the doctor invocation logger.

| Field | Type | Notes |
|---|---|---|
| `PocketDBPath` | string (absolute) | Resolved from `--pocketdb`. |
| `Manifest` | *Manifest | nil before manifest verification step. The first predicate (running-node) does not consult the manifest; manifest fetch + verification happens between running-node and version-mismatch in the orchestrator's order. (See `cli-surface.md` § Predicate Sequence.) |
| `Logger` | *stderrlog.Logger | All predicate diagnostics emitted via this logger. |

The PreflightContext is constructed by the diagnose orchestrator per invocation; it is not persistent state.

## Entity Inheritance to Chunk 003

The Plan entity's contract is the inheritance surface for Chunk 003. Chunk 003's apply:

- Reads the plan file, parses it via `internal/plan.Unmarshal`.
- Re-verifies `self_hash` (chunking-doc EC-009 plan-tamper detection — fires with code 15 on mismatch).
- Reads `canonical_identity.manifest_hash` and re-fetches the manifest via the same `internal/manifest` package; if the served manifest's trust-root hash differs from `Plan.canonical_identity.manifest_hash`, fires the EC-005 superseded-canonical refusal (code 14).
- Iterates `divergences[*]`, constructing chunk URLs per Chunk 001's grammar and fetching + verifying + atomic-renaming as the apply pathway.

The plan is the only state that crosses the diagnose → apply boundary. No environment variables, no separate config files, no inter-process state.
