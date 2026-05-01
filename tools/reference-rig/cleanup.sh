#!/usr/bin/env bash
# tools/reference-rig/cleanup.sh — idempotent removal of harness artifacts on the rig.
#
# Removes:
#   $REFERENCE_RIG_BASE/bin/pocketnet-node-doctor-*
#   $REFERENCE_RIG_BASE/pocketdb-rigs/*
#   $REFERENCE_RIG_BASE/runs/*  (default: keep last 7 days; --all to remove all)
#   $REFERENCE_RIG_BASE/deploy/* (rsynced harness scripts)
#
# Does NOT touch $REFERENCE_RIG_BASELINE_FIXTURES (read-only baseline).
# Does NOT touch $REFERENCE_RIG_BASE itself.

set -euo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"
load_config

remove_all_runs=0
keep_days=7
while (( "$#" )); do
  case "$1" in
    --all) remove_all_runs=1; shift;;
    --keep-days) keep_days="$2"; shift 2;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 64;;
  esac
done

# Refuse if $REFERENCE_RIG_BASE is unreasonably broad.
if [[ "$REFERENCE_RIG_BASE" == "/" || "$REFERENCE_RIG_BASE" == "" ]]; then
  echo "REFUSE: REFERENCE_RIG_BASE looks unsafe: '$REFERENCE_RIG_BASE'" >&2
  exit 1
fi

echo "==> Cleanup target: $REFERENCE_RIG_HOST:$REFERENCE_RIG_BASE"
ssh_rig "
  set -e
  rm -rf '$REFERENCE_RIG_BASE/bin'
  rm -rf '$REFERENCE_RIG_BASE/pocketdb-rigs'
  rm -rf '$REFERENCE_RIG_BASE/deploy'
  if [ '$remove_all_runs' = '1' ]; then
    rm -rf '$REFERENCE_RIG_BASE/runs'
  else
    find '$REFERENCE_RIG_BASE/runs' -mindepth 1 -maxdepth 1 -type d -mtime +$keep_days -exec rm -rf {} +
  fi
  echo OK
"
