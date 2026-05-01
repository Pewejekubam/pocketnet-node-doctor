#!/usr/bin/env bash
# tools/reference-rig/run.sh — invoke a named scenario on the rig under
# cgroup budgets; capture results.
#
# Subcommands:
#   sc001              run SC-001 timing test against 30day-divergent fixture
#   sc002              run SC-002 zero-entry-plan test against identical fixture
#   fetch-results      pull all $REFERENCE_RIG_BASE/runs/* back to dev host
#   stop               kill switch — terminate $REFERENCE_RIG_SLICE on the rig
#
# Resource budgets are sourced from config.local.sh; never overrideable on
# the command line (the harness's safety contract).

set -euo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"
load_config

scenario="${1:-}"

case "$scenario" in
  sc001|sc002)
    ;;
  fetch-results)
    mkdir -p "${REFERENCE_RIG_LOCAL_RESULTS:-$HOME/pnd-reference-rig-results}"
    rsync_from_rig "$REFERENCE_RIG_BASE/runs/" "${REFERENCE_RIG_LOCAL_RESULTS:-$HOME/pnd-reference-rig-results}/"
    echo "Results fetched to ${REFERENCE_RIG_LOCAL_RESULTS:-$HOME/pnd-reference-rig-results}/"
    exit 0
    ;;
  stop)
    ssh_rig "systemctl --user stop '$REFERENCE_RIG_SLICE' || true"
    echo "Sent stop to slice $REFERENCE_RIG_SLICE"
    exit 0
    ;;
  ""|-h|--help)
    sed -n '2,16p' "$0"
    exit 0
    ;;
  *)
    echo "unknown scenario: $scenario" >&2
    exit 64
    ;;
esac

# Pre-flight: rig health.
"$HARNESS_DIR/healthcheck.sh" >&2

# Run-dir + per-run healthcheck capture.
RUN_DIR="$(new_run_dir "$scenario")"
ssh_rig "mkdir -p '$RUN_DIR'"
ssh_rig "env \
  REFERENCE_RIG_BASE='$REFERENCE_RIG_BASE' \
  REFERENCE_RIG_HEALTHCHECK_SERVICES='$REFERENCE_RIG_HEALTHCHECK_SERVICES' \
  REFERENCE_RIG_NVME_DEVICE='$REFERENCE_RIG_NVME_DEVICE' \
  REFERENCE_RIG_PRIMARY_WORKLOAD_SERVICE='$REFERENCE_RIG_PRIMARY_WORKLOAD_SERVICE' \
  REFERENCE_RIG_FREE_SPACE_REQUIRED_BYTES='${REFERENCE_RIG_FREE_SPACE_REQUIRED_BYTES:-53687091200}' \
  bash '$REFERENCE_RIG_BASE/deploy/healthcheck-on-rig.sh' --json '$RUN_DIR/healthcheck-pre.json'"

# Invoke the scenario under cgroup budgets via systemd-run.
echo "==> Running $scenario in $RUN_DIR"
ssh_rig "env \
  REFERENCE_RIG_BASE='$REFERENCE_RIG_BASE' \
  REFERENCE_RIG_BASELINE_FIXTURES='$REFERENCE_RIG_BASELINE_FIXTURES' \
  REFERENCE_RIG_SLICE='$REFERENCE_RIG_SLICE' \
  REFERENCE_RIG_CPU_WEIGHT='${REFERENCE_RIG_CPU_WEIGHT:-100}' \
  REFERENCE_RIG_IO_WEIGHT='${REFERENCE_RIG_IO_WEIGHT:-100}' \
  REFERENCE_RIG_MEMORY_HIGH='${REFERENCE_RIG_MEMORY_HIGH:-}' \
  REFERENCE_RIG_MEMORY_MAX='${REFERENCE_RIG_MEMORY_MAX:-}' \
  REFERENCE_RIG_MANIFEST_URL='${REFERENCE_RIG_MANIFEST_URL:-}' \
  bash '$REFERENCE_RIG_BASE/deploy/run-tests.sh' '$scenario' '$RUN_DIR'"

# Post-run healthcheck.
ssh_rig "env \
  REFERENCE_RIG_BASE='$REFERENCE_RIG_BASE' \
  REFERENCE_RIG_HEALTHCHECK_SERVICES='$REFERENCE_RIG_HEALTHCHECK_SERVICES' \
  REFERENCE_RIG_NVME_DEVICE='$REFERENCE_RIG_NVME_DEVICE' \
  REFERENCE_RIG_PRIMARY_WORKLOAD_SERVICE='$REFERENCE_RIG_PRIMARY_WORKLOAD_SERVICE' \
  bash '$REFERENCE_RIG_BASE/deploy/healthcheck-on-rig.sh' --json '$RUN_DIR/healthcheck-post.json'"

# Pull this run's artifacts back to dev host.
mkdir -p "${REFERENCE_RIG_LOCAL_RESULTS:-$HOME/pnd-reference-rig-results}"
rsync_from_rig "$RUN_DIR/" "${REFERENCE_RIG_LOCAL_RESULTS:-$HOME/pnd-reference-rig-results}/$(basename "$RUN_DIR")/"
echo "==> Run complete; results in ${REFERENCE_RIG_LOCAL_RESULTS:-$HOME/pnd-reference-rig-results}/$(basename "$RUN_DIR")/"
