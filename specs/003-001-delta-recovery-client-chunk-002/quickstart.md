# Quickstart: Build the Doctor and Run Diagnose

**Branch**: `003-001-delta-recovery-client-chunk-002` | **Date**: 2026-04-30 | **Plan**: [plan.md](plan.md)

## What this is

An operator-facing recipe for building the doctor binary from this branch and running `diagnose` against a fixture canonical. Doubles as the chunking-doc Independent Test for US-001 (read-only diagnose pathway) and US-003 (trust-root authentication).

This recipe assumes you have:

- Go (1.23 or later — the iterator-based hash-utils API requires it).
- `git`, `curl`, `sha256sum` (or `shasum -a 256` on macOS), `jq`.
- A fixture canonical at a published `<base>` URL with `<block_height>` (Chunk 001's synthetic fixture is the v1 development reference, pinned at block height `3806626`).

Substitute throughout:

```bash
BASE='<base URL of the published canonical chunk store; e.g., https://example.example>'
HEIGHT='3806626'
PREFIX="$BASE/canonicals/$HEIGHT"
POCKETDB='/var/lib/pocketnet/pocketdb'  # or wherever your pocketdb lives
```

## Step 1 — Build the doctor

```bash
cd /path/to/pocketnet-node-doctor
go build -o ./pocketnet-node-doctor ./cmd/pocketnet-node-doctor
```

The vanilla build pins the v1 development trust-root constant (`a939828d…` from the Chunk 001 synthetic fixture). To build against a different canonical, override at link time:

```bash
go build -ldflags "-X internal/trustroot.PinnedHash=<64-hex>" \
  -o ./pocketnet-node-doctor ./cmd/pocketnet-node-doctor
```

Confirm the binary's compiled-in trust-root:

```bash
./pocketnet-node-doctor --version
# Expected output (stdout):
# pocketnet-node-doctor 0.1.0 (commit <git-sha>; built <date>; trust-root a939828d349b...f029249)
```

The trust-root in `--version` output MUST equal the canonical's published trust-root (Chunk 001 publishes it as the sidecar `trust-root.sha256`); otherwise the manifest verification step below will refuse.

## Step 2 — Confirm the canonical and the binary's trust-root agree

```bash
curl -sS "$PREFIX/trust-root.sha256" | tr -d '\n'
# Expected: 64 lowercase hex chars matching the binary's compiled-in trust-root.
```

If this differs from `--version`'s reported trust-root, you cannot proceed against this canonical without rebuilding the doctor. Refuse to fetch chunks against an unverified canonical (per pre-spec EC-008).

## Step 3 — Stop the local pocketnet-core process

The doctor refuses to run if `pocketnet-core` is using the pocketdb (FR-010 / EC-004 / pre-flight predicate 1). Stop it via your usual mechanism:

```bash
sudo systemctl stop pocketnet-core    # or however your deployment runs it
```

The doctor never starts/stops `pocketnet-core` itself (per pre-spec Out-of-Scope).

## Step 4 — Run diagnose

```bash
./pocketnet-node-doctor diagnose --canonical "$PREFIX" --pocketdb "$POCKETDB"
```

Stderr should show, in order:

1. (if any predicate would refuse) the relevant predicate diagnostic and the doctor exits non-zero.
2. `[diagnose] hashing main.sqlite3 pages...` and 5%-cadence milestones.
3. `[diagnose] hashing blocks/...` and per-25-files milestones; same for `chainstate/`, `indexes/`.
4. The summary block (per [contracts/cli-surface.md § Summary](contracts/cli-surface.md)).

Stdout should be **empty** (per spec Q3/A3).

Exit code 0 indicates success.

## Step 5 — Verify the emitted plan

The plan was written to `--plan-out` (default: alongside the pocketdb-parent directory). Confirm shape:

```bash
PLAN="$(dirname "$POCKETDB")/plan.json"
file "$PLAN"
jq '.format_version, .canonical_identity, (.divergences | length), (.self_hash | length)' "$PLAN"
```

Expected:

- `format_version` is `1`.
- `canonical_identity.block_height` is the value from `$HEIGHT` (e.g., `3806626`).
- `canonical_identity.manifest_hash` is the binary's compiled-in trust-root.
- `canonical_identity.pocketnet_core_version` is the version string from the canonical's manifest.
- `divergences | length` is non-negative (0 if local is identical to canonical).
- `self_hash | length` is `64`.

Optional schema-validate against [contracts/plan.schema.json](contracts/plan.schema.json):

```bash
check-jsonschema --schemafile specs/003-001-delta-recovery-client-chunk-002/contracts/plan.schema.json "$PLAN"
# Expected: validator reports success.
```

## Step 6 — Verify the plan's `self_hash` round-trip (CSC002-001)

The doctor's diagnose phase computes `self_hash` per the canonical-form rule. To verify out-of-band:

```bash
# Strip the self_hash field, re-serialize via jq's canonical form, hash.
jq -cS 'del(.self_hash)' "$PLAN" | tr -d '\n' | sha256sum | awk '{print $1}'
# Expected: matches `jq -r '.self_hash' "$PLAN"`.
```

`-cS` flags: `-c` compact (no insignificant whitespace), `-S` sort keys. `tr -d '\n'` strips the trailing newline jq emits (jq's compact output ends with `\n`; canonical-form does not). The result equals the bytes the doctor SHA-256'd internally.

Tampering the plan (e.g., editing a divergence's `expected_hash`) and re-running this check produces a mismatch — this is the contract Chunk 003's apply consumes for EC-009 plan-tamper detection.

## Step 7 — Verify the no-write contract (FR-005)

```bash
# Before diagnose: capture pocketdb tree's mtime + sha256 for sample files.
find "$POCKETDB" -type f -printf '%T@ %p\n' | sort > /tmp/pocketdb-pre.txt

# Run diagnose.
./pocketnet-node-doctor diagnose --canonical "$PREFIX" --pocketdb "$POCKETDB"

# After: capture again.
find "$POCKETDB" -type f -printf '%T@ %p\n' | sort > /tmp/pocketdb-post.txt

# Diff: should be empty.
diff /tmp/pocketdb-pre.txt /tmp/pocketdb-post.txt
# Expected: no output.
```

Any difference indicates a FR-005 violation (a regression in this chunk) — please file an issue.

## Step 8 — Negative test: trust-root mismatch (EC-008)

To verify trust-root refusal without modifying the published canonical, build the doctor with a deliberately-wrong trust-root constant:

```bash
go build -ldflags "-X internal/trustroot.PinnedHash=0000000000000000000000000000000000000000000000000000000000000000" \
  -o ./pocketnet-node-doctor-bad-trust ./cmd/pocketnet-node-doctor

./pocketnet-node-doctor-bad-trust diagnose --canonical "$PREFIX" --pocketdb "$POCKETDB"
echo "exit=$?"
```

Expected:

- Exit code 1.
- Stderr contains the trust-root-mismatch diagnostic naming both the computed and expected hashes.
- No `plan.json` is written.
- No chunk-store byte was fetched (the doctor refuses before fetching anything beyond the manifest itself).

## Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| Exit code 2 | pocketnet-core is running, OR a foreign OS-level lock holds `main.sqlite3`. | Stop pocketnet-core (`systemctl stop`); release the foreign lock; re-run. |
| Exit code 3 | local main.sqlite3 is newer than canonical. | This is the safety contract — recovery would discard local progress. Investigate why local is ahead before forcing anything; pre-spec scope does not include forcing this state. |
| Exit code 4 | local pocketnet-core version differs from canonical's. | Update or downgrade pocketnet-core to match the canonical's pinned version. |
| Exit code 5 | volume free space < 2× plan-listed-files-size. | Diagnostic names the byte shortfall; free space and re-run. |
| Exit code 6 | volume read-only or doctor's user lacks write access to pocketdb's volume. | Re-run as a user with write access (often `pocketnet`'s service user); or remount read-write. |
| Exit code 7 | manifest's `format_version` ≠ 1. | Update pocketnet-node-doctor to a version that recognizes the new `format_version`. (FR-018 forward-compat surface.) |
| Exit code 1 + diagnostic mentions "trust-root" | manifest authentication failure (EC-008). | Either (a) rebuild the doctor with the correct compiled-in trust-root for this canonical, or (b) verify the canonical itself is authentic (you may be talking to a tampered mirror). Refuse to proceed without resolution. |
| Exit code 1 + diagnostic mentions "--plan-out" | the resolved `--plan-out` parent directory is unwritable. | Set `--plan-out` to a writable directory, or chmod the parent. |
| Exit code 1 + diagnostic mentions "pocketnet-core" not on PATH | the version-check predicate cannot run. | Ensure `pocketnet-core` is installed and on PATH. |

## What this chunk does NOT do

This chunk's diagnose pathway emits a plan describing what apply WOULD do. It does not:

- fetch any chunk-store byte (manifest only);
- modify any byte under `pocketdb/`;
- start, stop, configure, or interact with `pocketnet-core` beyond a `--version` invocation;
- handle plan tamper detection (Chunk 003 / EC-009 owns it).

Apply is Chunk 003's deliverable; this chunk publishes the contract apply consumes.
