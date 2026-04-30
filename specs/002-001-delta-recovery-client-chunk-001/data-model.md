# Phase 1 Data Model: Manifest, Per-File Entry, Chunk, Trust-Root

**Branch**: `002-001-delta-recovery-client-chunk-001` | **Date**: 2026-04-30 | **Plan**: [plan.md](plan.md)

## Scope

This document is the human-readable companion to [contracts/manifest.schema.json](contracts/manifest.schema.json). It enumerates the entities the chunk publishes, their fields, validation rules, and inter-entity relationships. The JSON Schema is normative; this document is descriptive.

## Entity: Manifest

The top-level JSON document published at `<base>/canonicals/<block_height>/manifest.json` for each canonical.

### Fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `format_version` | integer | yes | Initial value `1`. Increments on schema-incompatible change (post-v1 concern, FR-018). |
| `canonical_identity` | object | yes | See [Canonical Identity](#sub-entity-canonical-identity). |
| `entries` | array of objects | yes | One element per file in the canonical artifact set. Element shape varies by `entry_kind` discriminator — see [Per-File Entry](#entity-per-file-entry). |
| `trust_anchors` | array | yes | Reserved for future trust-anchor list (FR-018). v1 publishes `[]`. |

### Validation rules

- All four fields above MUST be present. No additional top-level fields are permitted (`unevaluatedProperties: false` in the schema).
- Field key order in producer output MUST follow canonical-form serialization (sorted JSON keys, no insignificant whitespace, UTF-8) — pre-spec Implementation Context.
- The SHA-256 of the canonical-form-serialized manifest payload is the **trust-root constant** for this canonical, published as the sidecar `trust-root.sha256` (see [Trust-Root](#entity-trust-root)).

### Sub-entity: Canonical Identity

| Field | Type | Required | Notes |
|---|---|---|---|
| `block_height` | integer | yes | Pocketnet block height the canonical was minted at. Strictly increasing across successive published canonicals from a single publisher. |
| `pocketnet_core_version` | string | yes | Exact `pocketnet-core` version string the canonical was built against. Doctor refuses on local mismatch (pre-spec FR-012). |
| `created_at` | string | yes | ISO-8601 / RFC 3339 timestamp in UTC, e.g. `2026-04-15T13:24:00Z`. Used for the 30-day freshness check (CR001-008, US-5). |

### Validation rules (canonical_identity)

- `block_height` is a non-negative integer.
- `pocketnet_core_version` is non-empty.
- `created_at` MUST parse as RFC 3339 with explicit UTC offset (`Z` or `+00:00`).

## Entity: Per-File Entry

Element of the manifest's `entries` array. The entry's shape is selected by the `entry_kind` discriminator. Two kinds are defined in v1:

- `entry_kind: "sqlite_pages"` — page-level shape, used for `pocketdb/main.sqlite3` and any other SQLite-shaped artifacts under `pocketdb/` (per spec Assumptions).
- `entry_kind: "whole_file"` — whole-file shape, used for non-SQLite artifacts (e.g., `blocks/*.dat`, `chainstate/*`, `indexes/*`).

### Shape: `sqlite_pages` entry

| Field | Type | Required | Notes |
|---|---|---|---|
| `entry_kind` | string | yes | Literal `"sqlite_pages"`. |
| `path` | string | yes | Forward-slash relative path, rooted at the pocketnet data directory (e.g., `"pocketdb/main.sqlite3"`). No leading slash. |
| `pages` | array of `{offset, hash}` objects | yes | Total coverage: every 4 KB page of the canonical's file. Sorted by `offset` ascending. |
| `change_counter` | integer | only on the entry whose `path` is `"pocketdb/main.sqlite3"`; MUST NOT appear on any other `sqlite_pages` entry | The canonical's `main.sqlite3` SQLite header `change_counter` value. Doctor's pre-flight ahead-of-canonical reference (pre-spec FR-011). |

### Shape: `whole_file` entry

| Field | Type | Required | Notes |
|---|---|---|---|
| `entry_kind` | string | yes | Literal `"whole_file"`. |
| `path` | string | yes | Forward-slash relative path, as above (e.g., `"blocks/000123.dat"`). |
| `hash` | string | yes | 64-character lowercase hex SHA-256 of the whole file (uncompressed bytes). |

### Validation rules (per-file entry)

- `entry_kind` discriminates: schema uses `oneOf` keyed on `entry_kind`. Unknown values are schema-invalid.
- `path` is non-empty, contains no `..` segments, no leading `/`, no Windows-style separators. v1 path components are restricted to `[A-Za-z0-9_.\-]` per the schema's `path` regex; UTF-8 multibyte components are not permitted in v1.
- For `sqlite_pages`:
  - `pages` is non-empty (a zero-page file would be a `whole_file` entry).
  - Each page object: `offset` is a non-negative multiple of 4096; `hash` is 64-character lowercase hex.
  - Pages strictly sorted by `offset` ascending; no duplicate offsets.
  - Page coverage is contiguous and total — successive offsets differ by exactly 4096; the last offset + 4096 equals the canonical file size.
  - `change_counter` field is permitted only when `path == "pocketdb/main.sqlite3"`.
- For `whole_file`: `hash` is 64-character lowercase hex.

### Relationship: entry → chunk URL

For each per-file entry, the doctor constructs zero or more chunk URLs without further server interaction:

- `whole_file`: one chunk URL: `<base>/canonicals/<block_height>/files/<path>`.
- `sqlite_pages`: one chunk URL per page in `pages`: `<base>/canonicals/<block_height>/files/<path>/pages/<offset>` (offset as decimal integer string).

See [contracts/chunk-url-grammar.md](contracts/chunk-url-grammar.md) for the full grammar.

## Entity: Chunk

Not represented in the manifest as an explicit entity — chunks are addressed implicitly by manifest entries. A chunk is the byte source served at one HTTPS GET URL.

### Properties

| Property | Definition |
|---|---|
| URL | Per the chunk-URL grammar; see [contracts/chunk-url-grammar.md](contracts/chunk-url-grammar.md). |
| Recorded hash | SHA-256 in the manifest entry: per-page `hash` for `sqlite_pages`, top-level `hash` for `whole_file`. |
| Uncompressed payload | The byte source whose SHA-256 the recorded hash matches. |
| Compressed payloads | The bytes the server actually transfers, per `Accept-Encoding`. The recorded hash is computed over the uncompressed payload — see [contracts/http-encoding.md](contracts/http-encoding.md). |

### Invariants

- For every URL constructed from a per-file entry per the grammar, an HTTPS GET MUST return bytes whose SHA-256 (after applying any `Content-Encoding`) equals the manifest's recorded hash.
- The chunk store MUST honor the encoding-negotiation contract (pre-compressed zstd + gzip, HTTP 406 fallback) — see [contracts/http-encoding.md](contracts/http-encoding.md).

## Entity: Trust-Root

A pinned-hash credential the doctor binary is built against.

### Fields

A trust-root has two co-published shapes:

1. **In-memory shape** (compiled into the doctor binary): a 32-byte value (256 bits), conventionally rendered as 64 lowercase hex chars when printed.
2. **On-wire shape** (the sidecar file `<base>/canonicals/<block_height>/trust-root.sha256`): a UTF-8 text file containing exactly 64 lowercase hex chars followed by a single `\n`. Total byte length: 65.

### Construction

```
trust_root = SHA-256( canonical_form_serialize(manifest_json) )
```

Where `canonical_form_serialize` is per pre-spec Implementation Context: sorted JSON keys at every nesting level, no insignificant whitespace (no spaces between tokens, no trailing newline inside the serialized payload), UTF-8 byte output.

### Invariants

- Trust-root is external to the manifest. The manifest does not contain its own trust-root field. (Pre-spec keeps it that way to avoid the meta-hash recursion problem.)
- A doctor binary built with pinned trust-root `T` accepts manifest `M` if and only if `SHA-256(canonical_form_serialize(M)) == T`. Any byte-level difference in the canonical-form payload yields a different hash and a doctor refusal (pre-spec EC-008, exercised in US-2 acceptance scenario 2).

## Relationships

```
                                          ┌──────────────────────────┐
                                          │ Trust-Root (sidecar)     │
                                          │ trust-root.sha256        │
                                          └──────────────────────────┘
                                                       ▲
                                                       │ SHA-256(canonical-form payload)
                                                       │
┌────────────────────┐                       ┌──────────────────────────┐
│ Canonical Identity │  ◄────────────────────│ Manifest                 │
│ block_height       │   composed-in         │ manifest.json            │
│ core_version       │                       │ format_version           │
│ created_at         │                       │ canonical_identity       │
└────────────────────┘                       │ entries [0..n]           │
                                             │ trust_anchors []         │
                                             └──────────────────────────┘
                                                       │
                                                       │ ∀ entry → 1 or N chunks
                                                       ▼
                                             ┌──────────────────────────┐
                                             │ Chunk (HTTPS-addressable)│
                                             │ URL ← f(block_height,    │
                                             │        path, [offset])   │
                                             │ recorded SHA-256         │
                                             └──────────────────────────┘
```

## State transitions

There are no in-flight states for these entities — the manifest, chunks, and trust-root are static at publish time. The publisher's workflow is, abstractly:

```
build canonical → emit manifest payload → canonical-form serialize →
  SHA-256 → write trust-root.sha256 → publish chunk store + manifest.json
```

After publish, all three artifacts are read-only. Re-publication produces a new canonical at a new `block_height` and new trust-root; prior canonicals' artifacts persist per the publisher's retention policy (`delt.3`-owned).

## Validation summary (CSC001-001 / CSC001-002 mapping)

| Predicate | Source | Verified by |
|---|---|---|
| Schema published at stable URL | CSC001-001(a) | `curl <schema-url>` returns the JSON Schema document |
| Schema enumerates required fields | CSC001-001(a) | JSON Schema declares `format_version`, `canonical_identity`, `entries`, `trust_anchors` as required |
| Schema declares page-grid offsets for `main.sqlite3` | CSC001-001(a) | `sqlite_pages` branch's `pages` element shape includes `offset` (multiple of 4096) |
| Schema cites canonical-form rule | CSC001-001(b) | Top-level `$comment` field in the schema document |
| Manifest validates against frozen schema | CSC001-002(b) | Validator returns success on the published manifest |
| Sampled chunk SHA-256 matches manifest | CSC001-002(c) | One `main.sqlite3` page, one `blocks/` file, one `chainstate/` file fetched via HTTPS GET; SHA-256 of decompressed payload matches manifest entry |
| Trust-root matches canonical-form-hash of manifest | CSC001-002(a) | `sha256sum manifest.json` (after canonical-form normalization) equals contents of `trust-root.sha256` |
| Encoding negotiation contract | CSC001-002(d) | See [contracts/http-encoding.md](contracts/http-encoding.md) and [quickstart.md](quickstart.md) |
