---
version: 0.1.0
status: draft
created: 2026-04-30
last_modified: 2026-04-30
authors: [pewejekubam, claude]
related: tasks.md
changelog:
  - version: 0.1.0
    date: 2026-04-30
    summary: Initial contract hand-off document for sibling delt.3 (T049)
    changes:
      - "Enumerate the four artifacts delt.3 must produce conforming to Chunk 001 contracts"
      - "Document how to run the verification harness against delt.3's deployed canonical"
      - "Record BC-003 inheritance from existing distribution channel as a non-test invariant"
---

# Chunk 001 → delt.3 Contract Hand-Off

This document is the operational hand-off from the doctor-side contract spec
(this repo, Chunk 001) to the publisher-side implementation (sibling
`pocketnet_create_checkpoint` repo, epic child `delt.3`). It enumerates what
`delt.3` must produce and how to verify conformance using the in-repo
verification harness.

## What delt.3 must produce

For each canonical published, `delt.3` produces four classes of artifacts:

### 1. Manifest payload — `<base>/canonicals/<block_height>/manifest.json`

Validates against `contracts/manifest.schema.json` (JSON Schema Draft 2020-12,
`format_version: 1`). Required top-level fields: `format_version`,
`canonical_identity`, `entries`, `trust_anchors`. The body is served in
canonical form (sorted keys, no insignificant whitespace, UTF-8, no trailing
newline) so the simple `curl … | sha256sum` workflow recovers the trust-root
without re-serialization. The manifest URL is identity-encoded — the
encoding-negotiation contract binds chunk URLs only.

### 2. Chunk store — `<base>/canonicals/<block_height>/files/<path>[/pages/<offset>]`

Each chunk URL is addressable per the grammar in `contracts/chunk-url-grammar.md`.
Each chunk is published twice on-origin: once zstd-compressed
(`<chunk-path>.zst`) and once gzip-compressed (`<chunk-path>.gz`). The chunk
URL itself is encoding-agnostic — the server selects the at-rest variant per
the request's `Accept-Encoding` and emits `Vary: Accept-Encoding`. Absence of
both supported encodings yields HTTP 406 with body `Supported encodings: zstd,
gzip\n` (`Content-Type: text/plain; charset=utf-8`).

`main.sqlite3` chunks are exactly one 4096-byte page each (the schema enforces
`offset` as a non-negative multiple of 4096 and total page coverage of the
canonical's `main.sqlite3`). Whole-file chunks under `blocks/` and
`chainstate/` carry the file's full uncompressed bytes and are addressed by
file path alone.

### 3. Trust-root sidecar — `<base>/canonicals/<block_height>/trust-root.sha256`

A 65-byte plain-text file: 64 lowercase hex chars (SHA-256 of the canonical-form
manifest payload) + LF (0x0A). `Content-Type: text/plain; charset=utf-8`. Served
identity-encoded regardless of `Accept-Encoding` (small enough that
pre-compression is not load-bearing).

### 4. Encoding-negotiation contract — chunk URLs only

Server behavior on `Accept-Encoding`, summarized in `contracts/http-encoding.md`:

| Header | Status | Content-Encoding |
|---|---|---|
| `zstd` (anywhere) | 200 | `zstd` |
| `gzip` only (no zstd) | 200 | `gzip` |
| zstd + gzip both offered | 200 | `zstd` (preferred) |
| neither offered | 406 | (text/plain body) |

The doctor never inspects the 406 body programmatically beyond a `grep zstd &&
grep gzip` (CSC001-002(d)). The body shape is fixed only insofar as it must
contain both literal substrings.

## How to run the harness against delt.3's deployed canonical

The harness in `harness/` is the test surface this chunk owns. Running it
against `delt.3`'s live publisher is the deployment-time gate evidence.

### Prerequisites

See `harness/README.md` — `bash`, `curl`, `jq`, `sha256sum`, `zstd`, `gzip`,
`python3` ≥ 3.10, `check-jsonschema` (in a project-local venv).

### Command sequence

```bash
BASE='<delt.3 publisher base URL>'
HEIGHT='<a published block_height>'
PREFIX="$BASE/canonicals/$HEIGHT"
TMP=$(mktemp -d)

# 1. Fetch the manifest + trust-root sidecar
curl -fsS "$PREFIX/manifest.json"     -o "$TMP/manifest.json"
curl -fsS "$PREFIX/trust-root.sha256" -o "$TMP/trust-root.sha256"

# 2. Schema validation
harness/verify-schema.sh "$TMP/manifest.json"

# 3. Trust-root consistency
harness/verify-trust-root.sh "$TMP/manifest.json" "$TMP/trust-root.sha256"

# 4. Sampled chunk hashes match (US-1 AS-3..AS-5)
harness/verify-sampled-chunks.sh "$PREFIX" "$TMP/manifest.json"

# 5. Determinism + tamper rejection (BC-001, BC-002)
harness/verify-determinism.sh "$TMP/manifest.json"
# (tamper rejection requires a tampered copy — generate ad hoc:)
jq '.canonical_identity.block_height += 1' "$TMP/manifest.json" \
  | jq -cS . | tr -d '\n' > "$TMP/manifest-tampered.json"
harness/verify-tamper-rejection.sh "$TMP/manifest.json" "$TMP/trust-root.sha256" "$TMP/manifest-tampered.json"

# 6. change_counter exposure (CR001-007)
harness/verify-change-counter.sh "$TMP/manifest.json"

# 7. Encoding negotiation on a sampled chunk URL (CR001-005, US-4)
PAGE_OFFSET=$(jq -r '.entries[] | select(.path=="pocketdb/main.sqlite3") | .pages[0].offset' "$TMP/manifest.json")
PAGE_HASH=$(  jq -r '.entries[] | select(.path=="pocketdb/main.sqlite3") | .pages[0].hash'   "$TMP/manifest.json")
URL="$PREFIX/files/pocketdb/main.sqlite3/pages/$PAGE_OFFSET"
harness/verify-accept-encoding-zstd.sh "$URL" "$PAGE_HASH"
harness/verify-accept-encoding-gzip.sh "$URL" "$PAGE_HASH"
harness/verify-accept-encoding-406.sh  "$URL"

# 8. Freshness (CR001-008)
harness/verify-freshness.sh "$TMP/manifest.json"

# 9. Drill canonical (CSC001-003) — only against the canonical the drill rig pins
harness/verify-drill-canonical.sh "$BASE" "$HEIGHT" "<drill-rig-pin-trust-root-hex>"
```

All eleven invocations exit 0 ⇒ `delt.3` has produced a conforming canonical
and the chunk's outbound gates (Gate 001-Schema → 002, Gate 001 → 002) are
satisfied for that canonical.

## BC-003 (concurrent fetches at typical operator scale) — non-test invariant

Per plan §D9 and the chunking-doc Speckit Stop, the chunk store inherits the
throughput envelope of the existing full-snapshot distribution channel.
Concrete capacity (concurrent operators, requests/sec, byte/sec) is owned
operationally by `delt.3` and is sized by today's operator population × the
doctor's default 4-way concurrency (pre-spec Implementation Context).

This is recorded here as a non-test invariant: no harness in this chunk
exercises real production capacity. The adjacent contract guarantee — chunk
URLs are discrete static GETs over an existing high-capacity channel — is the
load-bearing property. Numerical capacity verification is a `delt.3`
deployment-time concern.

## Retention SLO

Spec Q4/A4: a published canonical's manifest URL remains accessible at least
until the next canonical at higher block height is published. A concrete
retention window (last-N canonicals, fixed-day) is `delt.3`'s call.

## Failure-mode contract

Pipeline failures, mirror outages, cache invalidation paths are owned by
`delt.3`. The contract here is what a successful publication looks like. If a
publication is incomplete (e.g., the manifest is up but some chunks return
404), the harness will fail on `verify-sampled-chunks.sh` or the per-chunk
encoding scripts, surfacing the gap.
