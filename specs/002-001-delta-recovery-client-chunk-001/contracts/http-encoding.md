# Contract: HTTP Accept-Encoding / 406 Negotiation

**Branch**: `002-001-delta-recovery-client-chunk-001` | **Date**: 2026-04-30 | **Plan**: [../plan.md](../plan.md)

## Purpose

Pins the encoding-negotiation contract for **chunk URLs** (sqlite-page chunks and whole-file chunks). The publisher pre-compresses chunk payloads in two encodings (zstd, gzip), caches them server-side, and selects per request `Accept-Encoding`. Absence of either supported encoding returns HTTP 406 with a body naming the supported encodings.

## Scope

This contract binds:

- All chunk URLs under `<canonical-prefix>/files/...` — both `whole_file` and `sqlite_pages` chunks.

This contract does NOT bind:

- The manifest URL `<canonical-prefix>/manifest.json` (the publisher MAY serve identity-encoded JSON regardless of `Accept-Encoding`; see [trust-root-format.md](trust-root-format.md) on canonical-form serving).
- The trust-root sidecar `<canonical-prefix>/trust-root.sha256` (small plain-text, identity-encoded).

## Server behavior

### Request offers `zstd` (anywhere in `Accept-Encoding` token list)

Response:

| Field | Value |
|---|---|
| Status | `200 OK` |
| `Content-Encoding` | `zstd` |
| `Content-Type` | `application/octet-stream` |
| `Vary` | `Accept-Encoding` |
| Body | The pre-compressed zstd-encoded payload at rest. |

Decoding the body bytes via zstd yields the **uncompressed payload** whose SHA-256 equals the manifest's recorded hash for the chunk.

### Request offers `gzip` (anywhere in `Accept-Encoding` token list, and `zstd` is NOT also offered)

If both `zstd` and `gzip` are offered, the publisher SHOULD prefer `zstd` (better ratio for the SQLite-page workload — pre-spec Implementation Context). If only `gzip` is offered:

| Field | Value |
|---|---|
| Status | `200 OK` |
| `Content-Encoding` | `gzip` |
| `Content-Type` | `application/octet-stream` |
| `Vary` | `Accept-Encoding` |
| Body | The pre-compressed gzip-encoded payload at rest. |

Decoding via gzip yields the uncompressed payload whose SHA-256 equals the manifest's recorded hash.

### Request offers neither `zstd` nor `gzip`

Including but not limited to: `Accept-Encoding: identity`, `Accept-Encoding: *;q=0`, `Accept-Encoding: br`, missing `Accept-Encoding` header (which per RFC 9110 §12.5.3 implies any encoding acceptable but the publisher chooses to refuse on absence as a defensive default), or any other token list that does not include `zstd` or `gzip`.

Response:

| Field | Value |
|---|---|
| Status | `406 Not Acceptable` |
| `Content-Type` | `text/plain; charset=utf-8` |
| `Vary` | `Accept-Encoding` |
| Body | Exactly: `Supported encodings: zstd, gzip\n` (33 bytes including the trailing LF). |

The body MUST contain both the literal substrings `zstd` and `gzip` (CR001-005 / US-4 AS-3). Doctor-side and out-of-band tests grep for both tokens.

## Hash invariant

For every chunk URL:

```
SHA-256( decode( response_body, Content-Encoding ) ) == manifest.entry.hash
```

Where `decode(b, "zstd")` is zstd decompression, `decode(b, "gzip")` is gzip decompression, and `decode(b, <none>)` is identity (the body bytes themselves).

The hash is computed over the **uncompressed** payload regardless of which encoding the server selected. This preserves the property that one manifest entry pins one byte sequence even though that sequence is delivered through multiple compressed transports.

## Cache-key shape

The publisher's caching layer (or a CDN in front of it) keys responses on:

```
cache_key = (full URL) × (selected Content-Encoding)
```

`Vary: Accept-Encoding` on every response signals this to intermediate caches. Two on-origin pre-compressed variants exist per chunk URL (`<chunk-path>.zst` and `<chunk-path>.gz`); the encoding-agnostic chunk URL is what the doctor sees.

## Out-of-band verification recipes

```bash
# zstd path
curl -sS -H 'Accept-Encoding: zstd' --output - <chunk-url> | zstd -d - -o /tmp/chunk.bin
sha256sum /tmp/chunk.bin
# Expect: <manifest entry's hash> for that chunk

# gzip path
curl -sS -H 'Accept-Encoding: gzip' --output - <chunk-url> | gzip -d > /tmp/chunk.bin
sha256sum /tmp/chunk.bin
# Expect: <manifest entry's hash>

# Unsupported encoding
curl -sS -i -H 'Accept-Encoding: identity' <chunk-url>
# Expect: HTTP/1.1 406 Not Acceptable
#         body containing "zstd" and "gzip"
```

Note: when curl sees `Content-Encoding: zstd` or `Content-Encoding: gzip` and no transparent decoding flag is set, it returns the encoded bytes verbatim (suitable for piping to `zstd -d` or `gzip -d`). This is the correct shape for verifying the contract.

## Acceptance mapping

| Spec acceptance | Verified by |
|---|---|
| US-4 AS-1 (zstd request → zstd-encoded response, decompressed SHA-256 matches manifest) | server behavior (zstd path) + hash invariant |
| US-4 AS-2 (gzip request → gzip-encoded response, decompressed SHA-256 matches manifest) | server behavior (gzip path) + hash invariant |
| US-4 AS-3 (neither encoding offered → HTTP 406 with body naming `zstd` and `gzip`) | server behavior (406 path) |
| CR001-005 | All of the above |
| CSC001-002(d) | All of the above |
