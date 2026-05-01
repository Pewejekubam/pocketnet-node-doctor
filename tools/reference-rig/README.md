# reference-rig

Tooling for SC-001 / SC-002 reference-rig acceptance gates: deploy a built `pocketnet-node-doctor` to a designated reference-rig host, run the build-tag-gated reference-rig tests, capture results back to the dev host, and clean up — all under cgroup-bounded resource budgets so the rig's primary workload is never disrupted.

## Why this exists

`tests/integration/sc001_timing_test.go` and `tests/integration/sc002_zero_entry_timing_test.go` are gated behind `//go:build reference_rig` because the SC-001 5-minute end-to-end budget can only be validated on the named reference rig (8 vCPU x86_64, NVMe-class disk, 16 GB RAM per [pre-spec.md](../../specs/001-delta-recovery-client/pre-spec.md)). Dev-laptop runs against `testdata/small/` cannot validate the timing claim. This harness is the operator-side glue that gets the reference-scale fixtures into a known location, runs the tests there, and brings results back.

## Project policy: no internal-infrastructure leakage

This harness is operator-private at its boundaries. The repo carries only generic shell driven by environment variables; **all hostnames, paths, SSH config, and resource budgets live in a per-developer `config.local.sh` that is gitignored**. The pattern mirrors [`bu-project.sh`](../../bu-project.sh) — itself gitignored for the same reason.

The `.git/hooks/pre-commit` and `.git/hooks/pre-push` hooks scan staged content for known internal hostname prefixes and refuse leaks. If one of these hooks fires on a file in `tools/reference-rig/`, you've put operator-specific data in a tracked file by mistake — move it to `config.local.sh`.

## Quick start

```sh
# 1. Bootstrap your local config from the example template
cp tools/reference-rig/config.example.sh tools/reference-rig/config.local.sh
$EDITOR tools/reference-rig/config.local.sh
# Fill in: REFERENCE_RIG_HOST, REFERENCE_RIG_USER, REFERENCE_RIG_BASE,
# REFERENCE_RIG_BASELINE_FIXTURES, etc.

# 2. Verify the rig is reachable and healthy
./tools/reference-rig/healthcheck.sh

# 3. Build the binary with reference-rig pinned trust-root and deploy
./tools/reference-rig/deploy.sh

# 4. Run the SC-001/SC-002 reference-rig tests under cgroup budgets
./tools/reference-rig/run.sh sc001
./tools/reference-rig/run.sh sc002

# 5. Pull results back to dev host
./tools/reference-rig/run.sh fetch-results

# 6. (Optional) Clean up rig-side artifacts
./tools/reference-rig/cleanup.sh
```

## What gets deployed

| Path on rig | Owner | Purpose |
|---|---|---|
| `$REFERENCE_RIG_BASE/bin/pocketnet-node-doctor-<sha>` | this harness | Built binary, ldflags-pinned to a rig-minted manifest's trust-root |
| `$REFERENCE_RIG_BASE/manifests/<canonical-name>/manifest.json` | this harness | Manifest minted from the canonical-source SQLite |
| `$REFERENCE_RIG_BASE/pocketdb-rigs/<scenario>/` | this harness | cp-on-test working copies seeded from `$REFERENCE_RIG_BASELINE_FIXTURES` |
| `$REFERENCE_RIG_BASE/runs/<ISO8601>-<scenario>/` | this harness | Per-run output (plan.json, stderr.log, stdout.log, summary.json, healthcheck snapshots) |
| `$REFERENCE_RIG_BASE/deploy/` | this harness | Copy of `tools/reference-rig/remote/` rsynced over for on-rig invocation |

`$REFERENCE_RIG_BASE` lives entirely under the SMB-exposed share configured in `config.local.sh`. Nothing is written outside that path.

## What gets read but not written

`$REFERENCE_RIG_BASELINE_FIXTURES` (per `config.local.sh`) — the host directory containing the historical baseline SQLite fixtures. The harness treats this as **read-only**: it `cp`s into per-test working copies under `$REFERENCE_RIG_BASE/pocketdb-rigs/`, never mutates the originals. If `config.local.sh` accidentally points the harness at a production data path, the cp-on-test pattern still doesn't write back — but the healthcheck step will refuse to proceed if the path is owned by a non-`$REFERENCE_RIG_USER` account.

## Resource-budget posture

Every `run.sh` invocation wraps the test in a `systemd-run --user --scope --slice=$REFERENCE_RIG_SLICE` container. The slice is primarily a **kill-switch handle** and a process-grouping mechanism, not a resource clamp.

Defaults (fair-share, no caps):

- `CPUWeight=100`, `IOWeight=100` — the test gets a fair share alongside any other workload on the rig
- `MemoryHigh` / `MemoryMax` unset — the test inherits the rig's full physical memory

When to override (in `config.local.sh`):

- **Compute-intolerant primary workload on the rig**: lower `REFERENCE_RIG_CPU_WEIGHT` and `REFERENCE_RIG_IO_WEIGHT` (e.g., 20) so any contention yields to the primary workload.
- **Memory contention with another workload**: set `REFERENCE_RIG_MEMORY_HIGH` and/or `REFERENCE_RIG_MEMORY_MAX` to bound test-side allocation.

The chunk-002 reference rig is production-critical but compute-tolerant during normal hours, so the fair-share defaults are appropriate; explicit caps are an opt-in when needed.

**Kill switch:**
```sh
ssh $REFERENCE_RIG_HOST 'systemctl --user stop $REFERENCE_RIG_SLICE'
```

Tears down all reference-rig processes in one call. The slice is documented in [lib/common.sh](lib/common.sh).

## Healthcheck

Pre-, mid-, and post-run, [healthcheck.sh](healthcheck.sh) ssh's to the rig and verifies:

- Each service in `$REFERENCE_RIG_HEALTHCHECK_SERVICES` is `active (running)`
- `dmesg --since "5 min ago"` is empty of error/warn-level lines
- `$REFERENCE_RIG_NVME_DEVICE` extended stats show no latency outliers (`ioutil < 80%`, `await < 50ms`)
- `$REFERENCE_RIG_BASE` has at least `$REFERENCE_RIG_FREE_SPACE_REQUIRED` free
- `smbstatus` does not report errored sessions

Healthcheck output is captured into the run directory alongside the test results so a CI-side review can confirm the run was contained.

## Files

| File | Tracked? | Purpose |
|---|---|---|
| [README.md](README.md) | yes | this file |
| [config.example.sh](config.example.sh) | yes | placeholder template; copy to `config.local.sh` and fill in |
| `config.local.sh` | **no** (gitignored) | per-developer rig connection + paths |
| [deploy.sh](deploy.sh) | yes | build binary, rsync to rig, hash-verify on arrival |
| [run.sh](run.sh) | yes | invoke a named scenario under cgroup budgets; capture results |
| [cleanup.sh](cleanup.sh) | yes | idempotent removal of `$REFERENCE_RIG_BASE/{bin,pocketdb-rigs,runs}/...` |
| [healthcheck.sh](healthcheck.sh) | yes | pre/mid/post rig health probe |
| [lib/common.sh](lib/common.sh) | yes | sources `config.local.sh`; shared helpers |
| [remote/run-tests.sh](remote/run-tests.sh) | yes | runs ON the rig; invoked via SSH by `run.sh` |
| [remote/healthcheck-on-rig.sh](remote/healthcheck-on-rig.sh) | yes | runs ON the rig; invoked by `healthcheck.sh` |
| [remote/stop.sh](remote/stop.sh) | yes | runs ON the rig; kill-switch for `$REFERENCE_RIG_SLICE` |

## Pre-flight refusal contract

`run.sh` and `deploy.sh` both refuse to proceed if any of these are true:

1. `config.local.sh` is missing or unreadable
2. Any required `REFERENCE_RIG_*` variable is unset
3. `healthcheck.sh` fails any check
4. The rig's `$REFERENCE_RIG_BASE` is not on the SMB-exposed share configured in `config.local.sh` (cross-checked against `$REFERENCE_RIG_SMB_SHARE_PATH`)
5. The rig's primary-workload service (per `$REFERENCE_RIG_PRIMARY_WORKLOAD_SERVICE`) is in a degraded state

This is the safety contract: the harness refuses to operate when it cannot verify rig health. There is no `--force` flag.
