# CLI Surface Contract: `pocketnet-node-doctor diagnose` (Chunk 002)

**Branch**: `003-001-delta-recovery-client-chunk-002` | **Date**: 2026-04-30 | **Plan**: [../plan.md](../plan.md)

## Scope

This document is the contract for the operator-facing CLI surface this chunk publishes. It pins flag names, default values, exit codes, output destinations, predicate evaluation order, and diagnostic message templates. Companion to [plan.schema.json](plan.schema.json), which is the contract for the artifact this surface produces (`plan.json`).

The `apply` subcommand's namespace is reserved here but its surface is owned by Chunk 003.

## Subcommand: `diagnose`

### Synopsis

```
pocketnet-node-doctor diagnose --canonical <url> --pocketdb <path> [--plan-out <path>] [--verbose]
```

### Flags

| Flag | Required | Default | Notes |
|---|---|---|---|
| `--canonical` | yes | — | Base URL of the canonical chunk store; the manifest is fetched from `<canonical>/manifest.json` (chunk-001 grammar; doctor strips trailing `/`). HTTPS only. |
| `--pocketdb` | yes | — | Absolute or relative path to the operator's `pocketdb/` directory (the directory `pocketnet-core` reads/writes; not its parent). Resolved to absolute at startup. |
| `--plan-out` | no | `<dirname --pocketdb>/plan.json` | Path where `plan.json` is written. Per [plan.md § D5](../plan.md). |
| `--verbose` | no | `false` | Enables debug-level stderr output. Default mode emits info-level only. |

### Global flags

| Flag | Notes |
|---|---|
| `--help` | Prints subcommand-specific help (per-subcommand FlagSet) when used after a subcommand; prints global help (subcommand list + version) when used without a subcommand. |
| `--version` | Prints `pocketnet-node-doctor <semver> (commit <git-sha>; built <build-date>; trust-root <pinned-hash>)` to stdout and exits 0. The trust-root pinned hash is included so operators can confirm their binary's compiled-in trust-root matches their canonical's published trust-root. |

`--version` is the single intentional stdout writer in v1; diagnose itself writes nothing to stdout (per spec Q3/A3).

### Output destinations

| Destination | Content |
|---|---|
| stdout | unused by `diagnose` in v1 (spec Q3/A3); reserved for future machine-readable output. The `--version` global flag writes to stdout but is not part of the diagnose pathway. |
| stderr | All human-readable output: predicate diagnostics, manifest verification milestones, page-hashing progress, file-class progress, summary, error diagnostics. Plain-text, info level by default; debug level added when `--verbose` is set. |
| filesystem at `--plan-out` | The `plan.json` artifact (per [plan.schema.json](plan.schema.json)). Written atomically via temp-file-and-rename: write to `<plan-out>.tmp.<rand>`, fsync, rename to `<plan-out>`. On any failure during write, the temp file is unlinked. |

`plan.json` is **not** emitted on pre-flight refusal (spec Q1/A1, US-002 acceptance scenario 7).

### Exit code allocation

Codes 0..7 are owned by Chunk 002. Codes 10..19 are reserved for Chunk 003's apply-time mid-run failures.

| Code | Class | Meaning |
|---|---|---|
| 0 | success | diagnose completed; `plan.json` written and fsynced; clean exit. |
| 1 | generic error | argument-parse failure, unwritable `--plan-out` target (per [plan.md § D6](../plan.md)), malformed manifest body that passes trust-root but fails struct unmarshal (publisher bug), `pocketnet-core` binary not on PATH, malformed SQLite header, network failure during manifest fetch, or any other unclassified internal failure. |
| 2 | pre-flight refusal: running-node | `pocketnet-core` is using `pocketdb/` OR a non-`pocketnet-core` OS-level lock holds `main.sqlite3` (treated identically per pre-spec EC-004). |
| 3 | pre-flight refusal: ahead-of-canonical | local `main.sqlite3` SQLite-header `change_counter` strictly exceeds canonical manifest's recorded `change_counter` for `main.sqlite3` (FR-011). |
| 4 | pre-flight refusal: pocketnet-core version mismatch | local `pocketnet-core` binary version differs from manifest's `canonical_identity.pocketnet_core_version` (FR-012). |
| 5 | pre-flight refusal: volume capacity | volume holding `pocketdb/` lacks free space for the staging area (2 × plan-listed-files-size; FR-013). Diagnostic names the shortfall in bytes. |
| 6 | pre-flight refusal: permission / read-only | volume holding `pocketdb/` lacks write permission for the doctor's user account, or is mounted read-only at pre-flight (EC-011). |
| 7 | manifest-format-version unrecognized | manifest's `format_version` is not 1 (FR-018; CSC002-002). Fires within manifest verification; categorized as pre-flight per chunking-doc (refuses before mutating anything). |
| 10..19 | reserved for Chunk 003 | apply-time mid-run failures (rollback completed, rollback failed, retry budget exhausted, EC-005 superseded canonical, plan tamper, etc.). Doctor's diagnose subcommand never emits these. |

### Predicate sequence

The diagnose subcommand evaluates predicates in this canonical order. **Stop at first refusal** (per spec Q2/A2): only the first refusing predicate's exit code and diagnostic are emitted; subsequent predicates are not evaluated.

```
1. argument validation             (parse failures → exit code 1)
2. running-node predicate          (refuse → exit code 2)
   ├─ argument-validated invocation; manifest not yet fetched
   └─ mechanism: advisory-lock probe + process-table scan (plan.md D8)

   --- manifest fetch + trust-root verification + format_version check ---
   3a. manifest GET                 (network failure → exit code 1)
   3b. trust-root verification      (mismatch → EC-008 refusal, exit code 1 with explicit-trust-root-mismatch diagnostic to distinguish from generic network failure; alternatively allocated to a future code)
   3c. format_version recognition   (unrecognized → exit code 7, FR-018 / CSC002-002)
   --- (manifest now available to subsequent predicates) ---

3. version-mismatch predicate      (refuse → exit code 4)
4. volume-capacity predicate       (refuse → exit code 5)
5. permission/read-only predicate  (refuse → exit code 6)
6. ahead-of-canonical predicate    (refuse → exit code 3)
   ├─ mechanism: direct SQLite-header byte parse (plan.md D7)
   └─ this is the last predicate because parsing the SQLite header is the most-invasive of the read-only checks

7. --plan-out writability probe    (probe failure → exit code 1)
   └─ non-predicate; up-front write check before any pocketdb byte is read for hashing (plan.md D6)

8. diagnose hash phase             (begins reading pocketdb/ for the first time)
   ├─ stream-hash main.sqlite3 pages, compare each against manifest's per-page hash
   ├─ stream-hash non-SQLite files whole-file, compare against manifest's per-file hash
   └─ accumulate divergences

9. plan emission                   (write to <plan-out>.tmp, fsync, rename to <plan-out>)
10. summary emission to stderr     (per plan.md D9)
11. clean exit                     (exit code 0)
```

**Note on EC-008 trust-root mismatch exit code**: the chunking-doc Speckit Stop allocates codes 2..7 to pre-flight refusals; trust-root mismatch is a refusal but doesn't have a dedicated code in the chunking-doc's allocation. The spec's US-003 acceptance scenario 2 says "exits non-zero" without naming a specific code. **Resolved at this contract**: trust-root mismatch maps to **exit code 1** with a distinguishing diagnostic ("manifest hash verification failed: computed <hex>, expected <hex>"). The diagnostic is the differentiator; wrappers parsing for trust-root failure should match the diagnostic, not the exit code.

The `format_version` unrecognized refusal has its own code (7) per the chunking-doc allocation; this is the FR-018 forward-compat surface and is distinct from the trust-root mismatch case.

### Diagnostic message templates

All diagnostics emitted on stderr; format `pocketnet-node-doctor: <severity>: <message>`. Severities: `error`, `warning`, `info`, `debug`. Templates:

#### Pre-flight refusals

| Predicate | Template |
|---|---|
| running-node | `pocketnet-node-doctor: error: pre-flight refusal (running-node): <reason>. <pocketdb-path> appears in use; stop pocketnet-core (or release the foreign lock on main.sqlite3) and re-run.` Where `<reason>` is `pocketnet-core process holding fd on <pocketdb-path>` or `advisory lock held on <main.sqlite3-path>`. |
| version-mismatch | `pocketnet-node-doctor: error: pre-flight refusal (pocketnet-core version mismatch): local pocketnet-core <local-ver>, canonical built against <canonical-ver>. Update or downgrade pocketnet-core to <canonical-ver> and re-run.` |
| volume-capacity | `pocketnet-node-doctor: error: pre-flight refusal (volume capacity): <pocketdb-volume> has <free-bytes> free; needs <required-bytes> (2× sum of plan-listed-files-size). Free <delta> bytes and re-run.` |
| permission/read-only | `pocketnet-node-doctor: error: pre-flight refusal (permission/read-only): <pocketdb-volume> is <reason> (<mount-flags>). Re-run as a user with write access, or remount read-write.` |
| ahead-of-canonical | `pocketnet-node-doctor: error: pre-flight refusal (ahead-of-canonical): local main.sqlite3 change_counter <local-cc> exceeds canonical <canonical-cc>. Local pocketdb is newer than canonical; recovery would discard local state. Refusing.` |

#### Manifest verification

| Surface | Template |
|---|---|
| trust-root mismatch (EC-008) | `pocketnet-node-doctor: error: manifest hash verification failed: computed <hex>, expected <hex> (compiled-in trust-root). The fetched manifest is not authentic. No chunk-store bytes were fetched.` |
| format-version unrecognized (FR-018 / CSC002-002) | `pocketnet-node-doctor: error: manifest format_version <version> not recognized by this doctor (recognizes: 1). Update pocketnet-node-doctor to a version that recognizes manifest format_version <version>.` |

#### Plan-out writability probe (plan.md D6)

| Surface | Template |
|---|---|
| writability probe failure | `pocketnet-node-doctor: error: cannot write to --plan-out target <plan-out-path>: <error>. Pre-pocketdb-read writability probe failed; no pocketdb byte has been read.` |

#### Progress messages (plan.md D10)

```
[diagnose] hashing main.sqlite3 pages...
[diagnose] hashing main.sqlite3 pages: 1,914,521 / 38,290,432 (5.00%)
[diagnose] hashing main.sqlite3 pages: 3,829,043 / 38,290,432 (10.00%)
...
[diagnose] hashed main.sqlite3 in 47.3s
[diagnose] hashing blocks/...
[diagnose] hashing blocks/: 25 / 2104 files
[diagnose] hashing blocks/: 50 / 2104 files
...
[diagnose] hashed blocks/ in 92.1s
[diagnose] hashing chainstate/...
[diagnose] hashed chainstate/ in 0.4s
[diagnose] hashing indexes/...
[diagnose] hashed indexes/ in 0.1s
```

#### Summary (plan.md D9)

Emitted at the very end of a successful diagnose run, after `plan.json` is written and fsynced:

```
pocketnet-node-doctor diagnose summary
  canonical block height: 3806626
  divergent files: <N> (<bytes-to-fetch> total)
  by class:
    main.sqlite3 pages: <pages-divergent> of <pages-total> (<pct>%; <bytes>)
    blocks/      :    <N> of <M> files (<bytes>)
    chainstate/  :    <N> of <M> files (<bytes>)
    indexes/     :    <N> of <M> files (<bytes>)
    other        :    <N> of <M> files (<bytes>)
  plan written to: <plan-out-path>
  estimated apply ETA: ~<minutes> minutes (assuming 50 MiB/s sustained download)
```

When the plan is empty (node identical to canonical):

```
pocketnet-node-doctor diagnose summary
  canonical block height: 3806626
  no recovery needed: local pocketdb matches canonical bitwise.
  plan written to: <plan-out-path>  (zero divergences)
```

### `--help` output

The top-level `--help` (or invocation with no subcommand) prints:

```
pocketnet-node-doctor — recover dead/corrupted pocketnet nodes via byte-level delta from a canonical snapshot.

Usage:
  pocketnet-node-doctor <subcommand> [flags]

Subcommands:
  diagnose    Identify what differs from canonical; emit a machine-readable plan. Read-only.
  apply       Consume a plan and atomically swap differing chunks into place. Mutating. (Chunk 003)
  --help      Print this help.
  --version   Print version, commit, build date, and compiled-in trust-root hash.

Exit codes:
   0  success
   1  generic error (argument failure, network failure, internal failure, etc.)
   2  pre-flight refusal: running-node
   3  pre-flight refusal: ahead-of-canonical
   4  pre-flight refusal: pocketnet-core version mismatch
   5  pre-flight refusal: volume capacity
   6  pre-flight refusal: permission / read-only
   7  manifest format_version unrecognized
  10..19  reserved for apply-time mid-run failures (Chunk 003)

Run 'pocketnet-node-doctor <subcommand> --help' for subcommand-specific flags.
```

The `diagnose --help` output prints the diagnose synopsis, flag table, and "see top-level --help for full exit-code allocation."

### Inheritance contract for Chunk 003

- The exit-code allocation 0..7 is fixed by this contract; Chunk 003's `apply` subcommand may emit codes 0, 1, 2, 4, 5, 6, 7 (sharing the pre-flight refusal surface) and additionally codes 10..19.
- Chunk 003's `apply` subcommand consumes `plan.json` per [plan.schema.json](plan.schema.json); no extension to the plan format from the apply side.
- Chunk 003 inherits the `--help` output's "exit codes" section and extends it with codes 10..19.
- The CLI surface's no-stdout invariant (except `--version`) is inherited by Chunk 003; apply also writes only to stderr + filesystem.
