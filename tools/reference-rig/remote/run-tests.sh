#!/usr/bin/env bash
# tools/reference-rig/remote/run-tests.sh
#
# Runs ON the reference rig. Invoked by run.sh via SSH. Wraps the test in a
# systemd-run --user --scope --slice= ... container for cgroup-bounded
# resource budgets. Stages a cp-on-test pocketdb working copy from the
# read-only baseline fixtures, then invokes go test -tags reference_rig.
#
# Args:
#   $1 — scenario name (sc001 or sc002)
#   $2 — absolute run-dir path (under $REFERENCE_RIG_BASE/runs/)

set -euo pipefail

scenario="$1"
run_dir="$2"

require_var() {
  local n="$1"
  if [[ -z "${!n:-}" ]]; then echo "FAIL: $n unset on rig"; exit 64; fi
}
require_var REFERENCE_RIG_BASE
require_var REFERENCE_RIG_BASELINE_FIXTURES
require_var REFERENCE_RIG_SLICE

case "$scenario" in
  sc001) baseline_subdir="30day-divergent" ;;
  sc002) baseline_subdir="identical" ;;
  *) echo "unknown scenario: $scenario" >&2; exit 64 ;;
esac

src="$REFERENCE_RIG_BASELINE_FIXTURES/$baseline_subdir"
if [[ ! -d "$src" ]]; then
  echo "REFUSE: baseline fixture missing: $src" >&2
  exit 1
fi

work="$REFERENCE_RIG_BASE/pocketdb-rigs/$baseline_subdir"
mkdir -p "$work"

# cp-on-test (reflink if available — instant on btrfs/xfs with reflink support).
echo "==> staging $src -> $work (cp --reflink=auto)"
cp --reflink=auto -an "$src/." "$work/"

# Resolve the deployed binary (latest by mtime).
bin="$(ls -1t "$REFERENCE_RIG_BASE/bin/pocketnet-node-doctor-"* 2>/dev/null | head -1)"
if [[ -z "$bin" ]]; then
  echo "REFUSE: no deployed binary in $REFERENCE_RIG_BASE/bin/" >&2
  exit 1
fi
echo "==> using binary: $bin"

# Output destinations.
plan_out="$run_dir/plan.json"
stderr_log="$run_dir/stderr.log"
stdout_log="$run_dir/stdout.log"
summary="$run_dir/summary.json"

# Manifest URL — operator-supplied via $REFERENCE_RIG_MANIFEST_URL or
# $REFERENCE_RIG_BASE/manifests/current/manifest.json served via local TLS.
manifest_url="${REFERENCE_RIG_MANIFEST_URL:-https://127.0.0.1:18443/manifest.json}"

# Resource-budget wrapper. systemd-run --user --scope ties lifetime to the
# ssh session; the slice gets cgroup limits applied.
start_ts="$(date -u +%s)"
set +e
nice -n 19 ionice -c2 -n7 \
  systemd-run --user --scope \
    --slice="$REFERENCE_RIG_SLICE" \
    --property="CPUWeight=$REFERENCE_RIG_CPU_WEIGHT" \
    --property="IOWeight=$REFERENCE_RIG_IO_WEIGHT" \
    --property="MemoryHigh=$REFERENCE_RIG_MEMORY_HIGH" \
    --property="MemoryMax=$REFERENCE_RIG_MEMORY_MAX" \
    "$bin" diagnose \
      --canonical "$manifest_url" \
      --pocketdb "$work" \
      --plan-out "$plan_out" \
      --verbose \
    > "$stdout_log" 2> "$stderr_log"
exit_code=$?
end_ts="$(date -u +%s)"
set -e
elapsed=$(( end_ts - start_ts ))

cat > "$summary" <<EOF
{
  "scenario": "$scenario",
  "binary": "$bin",
  "fixture": "$work",
  "manifest_url": "$manifest_url",
  "exit_code": $exit_code,
  "elapsed_seconds": $elapsed,
  "started_at": "$(date -u -d "@$start_ts" +%Y-%m-%dT%H:%M:%SZ)",
  "ended_at": "$(date -u -d "@$end_ts" +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "==> exit=$exit_code elapsed=${elapsed}s"
echo "==> outputs: $run_dir"
echo "    plan.json:   $(stat -c%s "$plan_out" 2>/dev/null || echo "missing") bytes"
echo "    stderr.log:  $(wc -l < "$stderr_log" 2>/dev/null || echo 0) lines"
echo "    stdout.log:  $(wc -l < "$stdout_log" 2>/dev/null || echo 0) lines"
echo "    summary.json: $summary"

exit $exit_code
