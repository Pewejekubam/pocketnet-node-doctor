# Quickstart: Out-of-Band Verification of a Published Canonical

**Branch**: `002-001-delta-recovery-client-chunk-001` | **Date**: 2026-04-30 | **Plan**: [plan.md](plan.md)

## What this is

A self-contained recipe for verifying that a canonical published by the chunk-001 contract conforms to the spec — without using the doctor binary. This recipe IS the chunking-doc Independent Test for US-1 and serves as the operational predicate for CSC001-001 / CSC001-002.

## Prerequisites

- `curl` (any reasonably modern version with `-H`, `-sS`, `-i` support).
- `sha256sum` (GNU coreutils; on macOS use `shasum -a 256`).
- `zstd` and `gzip` decoder CLIs.
- `jq` (for canonical-form re-serialization in the trust-root check).
- A published canonical's `<base>` URL and `<block_height>` value.

Substitute throughout:

```bash
BASE='<base URL of the publisher's chunk store; e.g., https://example.example>'
HEIGHT='<block_height of the canonical to verify; e.g., 3806626>'
PREFIX="$BASE/canonicals/$HEIGHT"
```

## Step 1 — Fetch the manifest and confirm schema-validity

```bash
curl -sS "$PREFIX/manifest.json" -o /tmp/manifest.json
file /tmp/manifest.json
jq '.format_version, .canonical_identity, (.entries | length), .trust_anchors' /tmp/manifest.json
```

Expected:

- `format_version` is `1`.
- `canonical_identity` carries `block_height`, `pocketnet_core_version`, `created_at` (RFC 3339).
- `entries | length` is at least 1 (and in practice many — one per artifact in the canonical set).
- `trust_anchors` is `[]`.

For full schema validation (optional but recommended), use a JSON Schema Draft 2020-12 validator (e.g., `check-jsonschema` or `ajv`) against [contracts/manifest.schema.json](contracts/manifest.schema.json):

```bash
check-jsonschema --schemafile contracts/manifest.schema.json /tmp/manifest.json
```

Expected: validator reports success.

## Step 2 — Verify the trust-root

```bash
# Fetch the published trust-root sidecar
curl -sS "$PREFIX/trust-root.sha256" -o /tmp/trust-root.sha256
EXPECTED=$(head -c 64 /tmp/trust-root.sha256)
echo "$EXPECTED"

# Re-serialize the manifest in canonical form (sorted keys, no insignificant whitespace, UTF-8)
# and hash it.
COMPUTED=$(jq -cS . /tmp/manifest.json | tr -d '\n' | sha256sum | awk '{print $1}')
echo "$COMPUTED"

[ "$EXPECTED" = "$COMPUTED" ] && echo "trust-root MATCH" || echo "trust-root MISMATCH"
```

Notes:

- `jq -cS` produces compact (no insignificant whitespace) sorted-key output. `tr -d '\n'` strips jq's trailing newline so the hashed bytes are exactly the canonical-form payload.
- If the publisher serves the manifest already in canonical form, `sha256sum </tmp/manifest.json | awk '{print $1}'` would also match — but the re-serialize-then-hash recipe is mirror-agnostic.

Expected: `trust-root MATCH`.

This step verifies CSC001-002(a) and US-1 AS-1.

## Step 3 — Fetch sampled chunks and verify their hashes

Sample one entry of each kind. Replace the JSON-extraction expressions with the actual paths/offsets from your fetched manifest.

### 3a. `main.sqlite3` page (sqlite_pages entry)

```bash
# Pull the first page entry for main.sqlite3
PAGE_OFFSET=$(jq -r '.entries[] | select(.entry_kind=="sqlite_pages" and .path=="pocketdb/main.sqlite3") | .pages[0].offset' /tmp/manifest.json)
PAGE_HASH=$(jq   -r '.entries[] | select(.entry_kind=="sqlite_pages" and .path=="pocketdb/main.sqlite3") | .pages[0].hash'   /tmp/manifest.json)
PAGE_URL="$PREFIX/files/pocketdb/main.sqlite3/pages/$PAGE_OFFSET"

curl -sS -H 'Accept-Encoding: zstd' --output - "$PAGE_URL" | zstd -d - -o /tmp/page.bin
COMPUTED=$(sha256sum /tmp/page.bin | awk '{print $1}')
[ "$PAGE_HASH" = "$COMPUTED" ] && echo "page hash MATCH" || echo "page hash MISMATCH"
```

Expected: `page hash MATCH`. Page size is 4096 bytes.

### 3b. `blocks/` whole-file entry

```bash
BLOCK_PATH=$(jq -r '.entries[] | select(.entry_kind=="whole_file" and (.path|startswith("blocks/"))) | .path' /tmp/manifest.json | head -n1)
BLOCK_HASH=$(jq -r --arg p "$BLOCK_PATH" '.entries[] | select(.path==$p) | .hash' /tmp/manifest.json)
BLOCK_URL="$PREFIX/files/$BLOCK_PATH"

curl -sS -H 'Accept-Encoding: zstd' --output - "$BLOCK_URL" | zstd -d - -o /tmp/block.bin
COMPUTED=$(sha256sum /tmp/block.bin | awk '{print $1}')
[ "$BLOCK_HASH" = "$COMPUTED" ] && echo "block file hash MATCH" || echo "block file hash MISMATCH"
```

### 3c. `chainstate/` whole-file entry

```bash
CS_PATH=$(jq -r '.entries[] | select(.entry_kind=="whole_file" and (.path|startswith("chainstate/"))) | .path' /tmp/manifest.json | head -n1)
CS_HASH=$(jq -r --arg p "$CS_PATH" '.entries[] | select(.path==$p) | .hash' /tmp/manifest.json)
CS_URL="$PREFIX/files/$CS_PATH"

curl -sS -H 'Accept-Encoding: zstd' --output - "$CS_URL" | zstd -d - -o /tmp/cs.bin
COMPUTED=$(sha256sum /tmp/cs.bin | awk '{print $1}')
[ "$CS_HASH" = "$COMPUTED" ] && echo "chainstate file hash MATCH" || echo "chainstate file hash MISMATCH"
```

Steps 3a–3c verify CSC001-002(c) and US-1 AS-5.

## Step 4 — Verify the encoding-negotiation contract

```bash
# 4a. zstd-only request returns zstd-encoded response
curl -sS -i -H 'Accept-Encoding: zstd' "$PAGE_URL" | head -n 20
# Expect: HTTP/1.1 200 OK + Content-Encoding: zstd

# 4b. gzip-only request returns gzip-encoded response
curl -sS -i -H 'Accept-Encoding: gzip' "$PAGE_URL" | head -n 20
# Expect: HTTP/1.1 200 OK + Content-Encoding: gzip

# 4c. identity-only request returns HTTP 406 with body naming both encodings
RESP=$(curl -sS -i -H 'Accept-Encoding: identity' "$PAGE_URL")
echo "$RESP" | head -n 20
echo "$RESP" | grep -q '^HTTP/.* 406'    && echo "status 406 OK"
echo "$RESP" | grep -q 'zstd'            && echo "names zstd OK"
echo "$RESP" | grep -q 'gzip'            && echo "names gzip OK"
```

Expected: `status 406 OK`, `names zstd OK`, `names gzip OK`.

This step verifies CSC001-002(d) and US-4 AS-1, AS-2, AS-3.

## Step 5 — Verify publication freshness

```bash
CREATED_AT=$(jq -r '.canonical_identity.created_at' /tmp/manifest.json)
echo "$CREATED_AT"
# Compute days-since (Linux date):
NOW_EPOCH=$(date -u +%s)
PAST_EPOCH=$(date -u -d "$CREATED_AT" +%s)
DAYS=$(( (NOW_EPOCH - PAST_EPOCH) / 86400 ))
echo "$DAYS days since creation"
[ "$DAYS" -le 30 ] && echo "freshness OK" || echo "freshness VIOLATION"
```

Step 5 verifies CR001-008 / US-5 AS-1 against the **latest** canonical at the publisher (run this against the latest-published `<HEIGHT>`, not against an arbitrary historical canonical).

## Step 6 — Verify the `change_counter` field on the `main.sqlite3` entry

```bash
CC=$(jq -r '.entries[] | select(.path=="pocketdb/main.sqlite3") | .change_counter' /tmp/manifest.json)
echo "main.sqlite3 change_counter: $CC"
# Expect: a non-negative integer.
```

Step 6 verifies CR001-007 / US-3 AS-1 — the canonical's `main.sqlite3` SQLite header `change_counter` is exposed for the doctor's pre-flight FR-011.

## Mapping summary

| Acceptance | Verified by |
|---|---|
| US-1 AS-1 | Step 2 |
| US-1 AS-2 | Step 1 |
| US-1 AS-3 | Step 3a (URL shape) |
| US-1 AS-4 | Step 3b/3c (whole-file entries) |
| US-1 AS-5 | Steps 3a, 3b, 3c |
| US-2 AS-1 | Step 2 (deterministic across builds) |
| US-2 AS-2 | Step 2 (mismatch case — substitute a tampered manifest and observe MISMATCH) |
| US-3 AS-1 | Step 6 |
| US-3 AS-2 | trivial — numeric comparison after Step 6 |
| US-4 AS-1 / AS-2 / AS-3 | Step 4 |
| US-5 AS-1 | Step 5 |
| US-6 AS-1 | Step 2 against the drill canonical's `<HEIGHT>` (the drill rig's pinned trust-root must equal the published trust-root for that canonical) |

## Failure modes

If any step fails, the publisher has not produced a conforming canonical. Diagnostic notes:

- **Schema validation fails (Step 1)** → manifest does not conform to [contracts/manifest.schema.json](contracts/manifest.schema.json). Most common: missing `entry_kind` discriminator, `change_counter` on a non-`main.sqlite3` entry, or non-multiple-of-4096 page offset.
- **Trust-root mismatch (Step 2)** → publisher's manifest generator and trust-root publisher disagree on canonical-form serialization. Check sorted-keys + no-whitespace + UTF-8 invariants.
- **Chunk hash mismatch (Step 3)** → publisher's chunk-store generation and manifest-hashing pass disagreed on the byte boundary, the compression-vs-uncompressed input to the hash, or the chunk URL → file mapping.
- **Encoding contract failure (Step 4)** → publisher served `Content-Encoding: identity` for a chunk-URL request that should have 200'd zstd/gzip, or 200'd identity-encoded bytes for a no-supported-encoding request that should have been 406.
- **Freshness violation (Step 5)** → publisher's release cadence is behind the 30-day commitment. (CR001-008 is a publisher operational SLO, not a per-request property; investigate the publication pipeline.)
