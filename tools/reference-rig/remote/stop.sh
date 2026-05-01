#!/usr/bin/env bash
# tools/reference-rig/remote/stop.sh — kill switch.
#
# Tears down all reference-rig processes by stopping the systemd user slice.
# Idempotent: succeeds whether the slice is running or already stopped.

set -euo pipefail

slice="${1:-${REFERENCE_RIG_SLICE:-pnd-reference-rig.slice}}"

systemctl --user stop "$slice" 2>/dev/null || true
systemctl --user reset-failed "$slice" 2>/dev/null || true
echo "stop sent to $slice"
