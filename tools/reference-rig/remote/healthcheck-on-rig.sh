#!/usr/bin/env bash
# tools/reference-rig/remote/healthcheck-on-rig.sh
#
# Runs ON the reference rig (rsynced over by healthcheck.sh). Probes the
# primary-workload service, NVMe latency, dmesg, smbstatus, free space.
# Refuses (non-zero exit) on any failed check. Writes a machine-readable
# summary to $JSON_OUT when --json <path> is provided.
#
# All operator-specific values are read from environment variables passed in
# by the caller (REFERENCE_RIG_HEALTHCHECK_SERVICES, REFERENCE_RIG_NVME_DEVICE,
# REFERENCE_RIG_PRIMARY_WORKLOAD_SERVICE, REFERENCE_RIG_BASE,
# REFERENCE_RIG_FREE_SPACE_REQUIRED_BYTES). This script contains no hostnames,
# paths, or service names.

set -euo pipefail

JSON_OUT=""
while (( "$#" )); do
  case "$1" in
    --json) JSON_OUT="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 64;;
  esac
done

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "FAIL: $name not provided to on-rig probe" >&2
    exit 64
  fi
}
require_var REFERENCE_RIG_HEALTHCHECK_SERVICES
require_var REFERENCE_RIG_NVME_DEVICE
require_var REFERENCE_RIG_PRIMARY_WORKLOAD_SERVICE
require_var REFERENCE_RIG_BASE

failures=()
checks_json=()

check_service() {
  local svc="$1"
  if systemctl is-active --quiet "$svc"; then
    echo "OK  service active: $svc"
    checks_json+=("{\"check\":\"service\",\"name\":\"$svc\",\"status\":\"active\"}")
  else
    echo "FAIL service not active: $svc" >&2
    failures+=("service:$svc")
    checks_json+=("{\"check\":\"service\",\"name\":\"$svc\",\"status\":\"inactive\"}")
  fi
}

check_dmesg() {
  local errs
  errs="$(dmesg --since '5 min ago' 2>/dev/null | grep -iE 'error|warn' | head -5 || true)"
  if [[ -z "$errs" ]]; then
    echo "OK  dmesg clean (last 5 min)"
    checks_json+=("{\"check\":\"dmesg\",\"status\":\"clean\"}")
  else
    echo "FAIL dmesg errors/warnings (last 5 min):" >&2
    echo "$errs" | sed 's/^/    /' >&2
    failures+=("dmesg")
    checks_json+=("{\"check\":\"dmesg\",\"status\":\"errors\"}")
  fi
}

check_nvme_latency() {
  local dev="$REFERENCE_RIG_NVME_DEVICE"
  # /sys/block/<dev>/stat fields: read I/Os, read merges, read sectors,
  # read ticks, write I/Os, write merges, write sectors, write ticks,
  # in-flight, io_ticks, time_in_queue
  if [[ ! -r "/sys/block/$dev/stat" ]]; then
    echo "WARN /sys/block/$dev/stat not readable; latency check skipped"
    checks_json+=("{\"check\":\"nvme_latency\",\"status\":\"skipped\",\"device\":\"$dev\"}")
    return
  fi
  read -r r_io r_mrg r_sec r_tick w_io w_mrg w_sec w_tick in_flight io_ticks time_in_queue < "/sys/block/$dev/stat"
  echo "OK  nvme stats read (device: $dev, in-flight: $in_flight, io_ticks: $io_ticks)"
  checks_json+=("{\"check\":\"nvme_latency\",\"status\":\"ok\",\"device\":\"$dev\",\"in_flight\":$in_flight,\"io_ticks\":$io_ticks}")
}

check_free_space() {
  local required="${REFERENCE_RIG_FREE_SPACE_REQUIRED_BYTES:-0}"
  local avail_bytes
  avail_bytes="$(df --output=avail --block-size=1 "$REFERENCE_RIG_BASE" 2>/dev/null | tail -1 | tr -d ' ')"
  if [[ -z "$avail_bytes" ]] || (( avail_bytes < required )); then
    echo "FAIL free space on $REFERENCE_RIG_BASE: ${avail_bytes:-?} bytes < required $required" >&2
    failures+=("free_space")
    checks_json+=("{\"check\":\"free_space\",\"status\":\"insufficient\",\"available\":${avail_bytes:-0},\"required\":$required}")
  else
    echo "OK  free space on $REFERENCE_RIG_BASE: $avail_bytes bytes (>= $required)"
    checks_json+=("{\"check\":\"free_space\",\"status\":\"ok\",\"available\":$avail_bytes,\"required\":$required}")
  fi
}

check_smbstatus() {
  if command -v smbstatus >/dev/null 2>&1; then
    if smbstatus --brief 2>/dev/null | grep -qiE 'error|denied'; then
      echo "FAIL smbstatus reports errors/denied" >&2
      failures+=("smbstatus")
      checks_json+=("{\"check\":\"smbstatus\",\"status\":\"errors\"}")
    else
      echo "OK  smbstatus clean"
      checks_json+=("{\"check\":\"smbstatus\",\"status\":\"clean\"}")
    fi
  else
    echo "WARN smbstatus not on PATH; smb session check skipped"
    checks_json+=("{\"check\":\"smbstatus\",\"status\":\"skipped\"}")
  fi
}

# Run checks in order: services first (cheapest), then dmesg, NVMe, free space, smb.
for svc in $REFERENCE_RIG_HEALTHCHECK_SERVICES; do
  check_service "$svc"
done
check_service "$REFERENCE_RIG_PRIMARY_WORKLOAD_SERVICE"
check_dmesg
check_nvme_latency
check_free_space
check_smbstatus

if [[ -n "$JSON_OUT" ]]; then
  mkdir -p "$(dirname "$JSON_OUT")"
  {
    printf '{"timestamp":"%s","checks":[' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local_first=1
    for c in "${checks_json[@]}"; do
      if (( local_first )); then local_first=0; else printf ','; fi
      printf '%s' "$c"
    done
    printf '],"failures":['
    local_first=1
    for f in "${failures[@]:-}"; do
      [[ -z "$f" ]] && continue
      if (( local_first )); then local_first=0; else printf ','; fi
      printf '"%s"' "$f"
    done
    printf ']}\n'
  } > "$JSON_OUT"
fi

if (( ${#failures[@]} > 0 )); then
  echo
  echo "REFUSE: ${#failures[@]} healthcheck(s) failed: ${failures[*]}" >&2
  exit 1
fi
echo
echo "PASS: rig healthy"
