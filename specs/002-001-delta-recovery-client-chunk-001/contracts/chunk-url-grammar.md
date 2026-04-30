# Contract: Chunk-URL Grammar

**Branch**: `002-001-delta-recovery-client-chunk-001` | **Date**: 2026-04-30 | **Plan**: [../plan.md](../plan.md)

## Purpose

Defines the URL grammar a doctor binary uses to construct manifest, trust-root, and chunk URLs from manifest fields. The grammar is what CR001-004 ("discrete HTTPS GETs") commits the publisher to.

## Base

`<base>` is the existing full-snapshot distribution channel's HTTPS root. The chunking doc's Speckit Stop pinned hosting topology to "same hosting channel as today's full-snapshot distribution"; `<base>` resolves to that channel's root URL at the time the doctor binary is built. The doctor knows `<base>` through compile-time configuration (One-Time Setup Checklist; pre-spec).

## Per-canonical prefix

```
<canonical-prefix> ::= <base> "/canonicals/" <block_height>
```

- `<block_height>` is the value of `canonical_identity.block_height` rendered as a decimal integer string with no leading zeros (e.g., `3806626`).

## URL families

### Manifest URL

```
<manifest-url> ::= <canonical-prefix> "/manifest.json"
```

- Stable per CR001-001. Remains accessible at least until a higher-block-height canonical is published (spec Q4/A4 conservative interpretation).
- Response: `Content-Type: application/json; charset=utf-8`, body conforms to [manifest.schema.json](manifest.schema.json).

### Trust-root sidecar URL

```
<trust-root-url> ::= <canonical-prefix> "/trust-root.sha256"
```

- Response: `Content-Type: text/plain; charset=utf-8`, body is exactly 65 bytes — 64 lowercase hex chars + `\n`.
- See [trust-root-format.md](trust-root-format.md) for the full sidecar contract.

### Chunk URL — whole-file entry

```
<whole-file-chunk-url> ::= <canonical-prefix> "/files/" <path>
```

- `<path>` is the manifest entry's `path` value verbatim, with each path component URL-encoded per RFC 3986 §2 (forward slashes between components are NOT encoded). The schema's path pattern restricts components to `[A-Za-z0-9_.-]`, so URL-encoding is normally a no-op.
- Body bytes (after applying any `Content-Encoding`; see [http-encoding.md](http-encoding.md)) MUST hash to the entry's top-level `hash` field.

### Chunk URL — sqlite_pages entry

```
<sqlite-page-chunk-url> ::= <canonical-prefix> "/files/" <path> "/pages/" <offset>
```

- `<path>` as above.
- `<offset>` is the page object's `offset` value rendered as a decimal integer string with no leading zeros and no thousand-separators (e.g., `0`, `4096`, `8192`, ..., `134258688`).
- Body bytes (after applying any `Content-Encoding`) MUST hash to the page object's `hash` field. Body is exactly 4096 uncompressed bytes — one SQLite page.

## Construction algorithm (doctor side)

Given a manifest and a chosen entry, the doctor constructs URLs as:

```
url = base + "/canonicals/" + str(block_height) + "/files/" + path
if entry_kind == "sqlite_pages":
    url += "/pages/" + str(offset)
```

No additional server interaction is required to discover URLs.

## Rules and prohibitions

- **No directory listings.** The grammar is the only way for the doctor to discover URLs. The publisher MUST NOT rely on any listing or index endpoint to make chunks discoverable.
- **No URL-encoded segment traversal.** The schema's `path` pattern rejects `..` segments; the grammar inherits that restriction. URLs constructed under this grammar refer only to under-canonical-prefix paths.
- **No alternative URLs for the same chunk.** Each chunk has one URL. (Mirrors at different `<base>` values are different URLs serving the same bytes — that is replication, not divergence; see pre-spec "Single canonical, single block height" operational invariant.)
- **No range-request requirement.** The grammar yields one URL per chunk; the doctor never relies on `Range:` headers. Servers MAY support `Range:` as an optimization, but the doctor's contract is the discrete-URL form.
- **Trailing-slash sensitivity.** The URLs above do NOT end in `/`. The publisher MUST NOT redirect chunk-URL requests to slash-terminated forms (would break content negotiation caches keyed on URL).

## Examples

Given a manifest with `canonical_identity.block_height = 3806626` and base `https://example-pocketnet-publisher.example/`:

| Entity | Concrete URL |
|---|---|
| Manifest | `https://example-pocketnet-publisher.example/canonicals/3806626/manifest.json` |
| Trust-root sidecar | `https://example-pocketnet-publisher.example/canonicals/3806626/trust-root.sha256` |
| `main.sqlite3` page at offset 0 | `https://example-pocketnet-publisher.example/canonicals/3806626/files/pocketdb/main.sqlite3/pages/0` |
| `main.sqlite3` page at offset 4096 | `https://example-pocketnet-publisher.example/canonicals/3806626/files/pocketdb/main.sqlite3/pages/4096` |
| `blocks/000123.dat` (whole file) | `https://example-pocketnet-publisher.example/canonicals/3806626/files/blocks/000123.dat` |
| `chainstate/CURRENT` (whole file) | `https://example-pocketnet-publisher.example/canonicals/3806626/files/chainstate/CURRENT` |

## Acceptance mapping

| Spec acceptance | Verified by |
|---|---|
| US-1 AS-3 (`(path, offset)` addressability) | sqlite-page-chunk-url shape |
| US-1 AS-5 (HTTPS GET returns chunk bytes whose SHA-256 matches the manifest) | All chunk-url shapes |
| CR001-004 (discrete HTTPS GETs) | All chunk-url shapes |
| CSC001-002(a) (manifest URL serves manifest for pinned canonical) | manifest-url shape |
| CSC001-002(c) (sampled chunks across `main.sqlite3`, `blocks/`, `chainstate/`) | sqlite-page-chunk-url + whole-file-chunk-url shapes |
