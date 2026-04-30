```
 ____            _        _   _   _      _
|  _ \ ___   ___| | _____| |_| \ | | ___| |_
| |_) / _ \ / __| |/ / _ \ __|  \| |/ _ \ __|
|  __/ (_) | (__|   <  __/ |_| |\  |  __/ |_
|_|   \___/ \___|_|\_\___|\__|_| \_|\___|\__|

                NODE DOCTOR
       delta recovery for pocketnet operators
```

# Pocketnet Node Doctor

A CLI tool that lets pocketnet operators recover from local data corruption by downloading only byte-level differences from a canonical snapshot — instead of a full ~60 GB blockchain re-download.

## Why

Today, an operator with a dead or corrupted node downloads the entire ~60 GB snapshot. Most of those bytes have not changed since the operator's node last synced.

Empirical measurement on a real-world interval (March block 3,745,867 → April block 3,806,626) of `pocketdb/main.sqlite3` at SQLite's 4 KB page boundary:

- **32.86M of 38.29M pages are byte-identical at the same offset** (85.83% reuse).
- Projected operator wire cost: **~13–15 GB compressed** versus ~60 GB full-snapshot baseline.
- **4–5× bandwidth reduction.**

The raw measurement output is in [`experiments/01-page-alignment-baseline/compare-output.log`](experiments/01-page-alignment-baseline/compare-output.log).

## How

Two operator-invoked modes:

- **`diagnose`** — read-only. Hashes the local `pocketdb/` against a canonical manifest. Emits a machine-readable plan listing exactly which bytes diverge.
- **`apply`** — consumes the plan. Fetches the differing chunks via HTTPS, stages them, atomically swaps them into place, runs `PRAGMA integrity_check` plus full-file SHA-256 verification, and rolls back on any failure.

A frozen-canonical model: any local byte that does not match canonical is overwritten. The doctor is for **dead or corrupted nodes**, not running healthy ones — pre-flight refusals catch a running node, an ahead-of-canonical node, a version-mismatched binary, or insufficient disk space before a single byte is touched.

## Status

**Pre-implementation, pre-spec phase.** This repository currently contains:

- The pre-spec — [`specs/001-delta-recovery-client/pre-spec.md`](specs/001-delta-recovery-client/pre-spec.md) — describing the user stories, functional requirements, and success criteria the implementation will be measured against.
- The empirical baseline experiments under [`experiments/`](experiments/).
- The pre-spec build methodology in [`docs/pre-spec-build/`](docs/pre-spec-build/) — the iterative authoring + adversarial audit + chunked implementation process this project follows.

Implementation is queued behind pre-spec audit and refinement. Watch the repo or open an issue if you want to track progress.

## Contributing

Early feedback on the pre-spec is the most valuable contribution at this stage:

- Read [`specs/001-delta-recovery-client/pre-spec.md`](specs/001-delta-recovery-client/pre-spec.md).
- Open an issue if a user story misses your operator scenario, a success criterion is unverifiable, or an edge case is unhandled.

Once implementation begins, the project ships in dependency-ordered chunks (see the pre-spec build process) — each chunk is a self-contained, testable, debuggable unit. The current child-issue breakdown of the implementation epic is visible in the upstream task tracker; once any of those chunks open for community contribution, this README will say so.

## License

[MIT](LICENSE) © 2026 Pewe Jekubam
