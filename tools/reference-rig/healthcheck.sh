#!/usr/bin/env bash
# tools/reference-rig/healthcheck.sh — pre/mid/post rig health probe.
#
# Verifies the reference rig is healthy enough to receive harness work without
# disrupting its primary role. Refuses with a non-zero exit (and a diagnostic
# naming the failed check) if any check fails.
#
# Output: human-readable status to stdout; if --json is passed, also writes
# a machine-readable summary to the given path.

set -euo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"
load_config

JSON_OUT=""
while (( "$#" )); do
  case "$1" in
    --json) JSON_OUT="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 64;;
  esac
done

# rsync the on-rig probe into a known location and invoke it.
ssh_rig "mkdir -p '$REFERENCE_RIG_BASE/deploy'"
rsync_to_rig "$HARNESS_DIR/remote/" "$REFERENCE_RIG_BASE/deploy/"

# Forward the variables the on-rig probe needs via env, then invoke bash.
ssh_rig "env \
  REFERENCE_RIG_BASE='$REFERENCE_RIG_BASE' \
  REFERENCE_RIG_HEALTHCHECK_SERVICES='$REFERENCE_RIG_HEALTHCHECK_SERVICES' \
  REFERENCE_RIG_NVME_DEVICE='$REFERENCE_RIG_NVME_DEVICE' \
  REFERENCE_RIG_PRIMARY_WORKLOAD_SERVICE='$REFERENCE_RIG_PRIMARY_WORKLOAD_SERVICE' \
  REFERENCE_RIG_FREE_SPACE_REQUIRED_BYTES='${REFERENCE_RIG_FREE_SPACE_REQUIRED_BYTES:-53687091200}' \
  bash '$REFERENCE_RIG_BASE/deploy/healthcheck-on-rig.sh' ${JSON_OUT:+--json $REFERENCE_RIG_BASE/runs/last-healthcheck.json}"

if [[ -n "$JSON_OUT" && "$JSON_OUT" != "/dev/null" ]]; then
  rsync_from_rig "$REFERENCE_RIG_BASE/runs/last-healthcheck.json" "$JSON_OUT"
fi
