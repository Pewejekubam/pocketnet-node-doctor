# tools/reference-rig/lib/common.sh
#
# Shared helpers for the reference-rig harness. Sourced by deploy.sh, run.sh,
# healthcheck.sh, and cleanup.sh.
#
# This file MUST NOT contain operator-specific data. All operator-specific
# values come from $REPO_ROOT/tools/reference-rig/config.local.sh (gitignored).

set -euo pipefail

# Resolve repo root from this file's location.
_THIS_FILE="${BASH_SOURCE[0]}"
_THIS_DIR="$(cd "$(dirname "$_THIS_FILE")" && pwd)"
REPO_ROOT="$(cd "$_THIS_DIR/../../.." && pwd)"
HARNESS_DIR="$(cd "$_THIS_DIR/.." && pwd)"

CONFIG_FILE="$HARNESS_DIR/config.local.sh"

# Required variables — sourced from config.local.sh; absence is a refuse.
REQUIRED_VARS=(
  REFERENCE_RIG_HOST
  REFERENCE_RIG_USER
  REFERENCE_RIG_BASE
  REFERENCE_RIG_BASELINE_FIXTURES
  REFERENCE_RIG_SMB_SHARE_PATH
  REFERENCE_RIG_SLICE
  REFERENCE_RIG_HEALTHCHECK_SERVICES
  REFERENCE_RIG_NVME_DEVICE
  REFERENCE_RIG_PRIMARY_WORKLOAD_SERVICE
)

load_config() {
  if [[ ! -r "$CONFIG_FILE" ]]; then
    echo "ERROR: $CONFIG_FILE not found." >&2
    echo "Bootstrap from the example template:" >&2
    echo "  cp $HARNESS_DIR/config.example.sh $CONFIG_FILE" >&2
    echo "Then fill in the placeholder values for your reference rig." >&2
    exit 64  # EX_USAGE
  fi
  # shellcheck source=/dev/null
  . "$CONFIG_FILE"

  local missing=()
  for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      missing+=("$var")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    echo "ERROR: required variables unset in $CONFIG_FILE:" >&2
    printf '  %s\n' "${missing[@]}" >&2
    exit 64
  fi

  # Refuse if $REFERENCE_RIG_BASE is not under $REFERENCE_RIG_SMB_SHARE_PATH.
  case "$REFERENCE_RIG_BASE" in
    "$REFERENCE_RIG_SMB_SHARE_PATH"/*) ;;
    *)
      echo "ERROR: REFERENCE_RIG_BASE ($REFERENCE_RIG_BASE) is not under" >&2
      echo "       REFERENCE_RIG_SMB_SHARE_PATH ($REFERENCE_RIG_SMB_SHARE_PATH)." >&2
      echo "       The harness refuses to operate outside SMB-exposed paths." >&2
      exit 64
      ;;
  esac
}

# ssh / rsync wrappers that consume $REFERENCE_RIG_SSH_OPTS / _SSH_PORT.
ssh_rig() {
  local port_opt=()
  if [[ -n "${REFERENCE_RIG_SSH_PORT:-}" ]]; then
    port_opt=(-p "$REFERENCE_RIG_SSH_PORT")
  fi
  # shellcheck disable=SC2086
  ssh -o BatchMode=yes -o ConnectTimeout=10 ${REFERENCE_RIG_SSH_OPTS:-} \
    "${port_opt[@]}" \
    "${REFERENCE_RIG_USER}@${REFERENCE_RIG_HOST}" "$@"
}

rsync_to_rig() {
  local src="$1"
  local dst="$2"
  local port_opt=""
  if [[ -n "${REFERENCE_RIG_SSH_PORT:-}" ]]; then
    port_opt="-p $REFERENCE_RIG_SSH_PORT"
  fi
  rsync -avz --delete \
    -e "ssh -o BatchMode=yes -o ConnectTimeout=10 ${REFERENCE_RIG_SSH_OPTS:-} $port_opt" \
    "$src" \
    "${REFERENCE_RIG_USER}@${REFERENCE_RIG_HOST}:$dst"
}

rsync_from_rig() {
  local src="$1"
  local dst="$2"
  local port_opt=""
  if [[ -n "${REFERENCE_RIG_SSH_PORT:-}" ]]; then
    port_opt="-p $REFERENCE_RIG_SSH_PORT"
  fi
  rsync -avz \
    -e "ssh -o BatchMode=yes -o ConnectTimeout=10 ${REFERENCE_RIG_SSH_OPTS:-} $port_opt" \
    "${REFERENCE_RIG_USER}@${REFERENCE_RIG_HOST}:$src" \
    "$dst"
}

# Resolve a name-spaced run directory in $REFERENCE_RIG_BASE/runs/.
new_run_dir() {
  local scenario="$1"
  local stamp
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  echo "$REFERENCE_RIG_BASE/runs/${stamp}-${scenario}"
}

# Print the current build's git short-hash for ldflags injection.
git_short_hash() {
  git -C "$REPO_ROOT" rev-parse --short HEAD
}
