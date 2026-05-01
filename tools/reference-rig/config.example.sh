# tools/reference-rig/config.example.sh
#
# Template for per-developer reference-rig configuration. Copy to
# config.local.sh and fill in the placeholder values:
#
#   cp tools/reference-rig/config.example.sh tools/reference-rig/config.local.sh
#   $EDITOR tools/reference-rig/config.local.sh
#
# config.local.sh is gitignored. Never check it in. Never put hostnames,
# absolute internal paths, or SSH config in this template — only placeholders.
#
# This file is sourced by lib/common.sh; values are exported to subshells
# (deploy.sh, run.sh, healthcheck.sh, cleanup.sh, and the on-rig scripts
# under remote/).

# ----- Connection -----
# SSH-reachable hostname or alias of the reference rig.
REFERENCE_RIG_HOST="<your-rig-host-or-ssh-alias>"
# Login user on the rig. Must own $REFERENCE_RIG_BASE on the rig.
REFERENCE_RIG_USER="<rig-user>"
# SSH port; leave empty to use default 22.
REFERENCE_RIG_SSH_PORT=""
# Optional SSH options applied verbatim (e.g. "-i ~/.ssh/rig-key -o StrictHostKeyChecking=accept-new")
REFERENCE_RIG_SSH_OPTS=""

# ----- Paths on the rig (must be inside the SMB-exposed share) -----
# Base directory where this harness deploys binaries, fixtures, and run results.
# Must be a writable, NVMe-class path owned by $REFERENCE_RIG_USER.
REFERENCE_RIG_BASE="<absolute-rig-path-for-this-harness>"
# Directory containing the historical baseline SQLite fixtures (read-only to
# the harness; the harness cp-on-tests into $REFERENCE_RIG_BASE/pocketdb-rigs/).
# Expected layout: <baseline>/<scenario>/main.sqlite3 — see [README.md](README.md).
REFERENCE_RIG_BASELINE_FIXTURES="<absolute-rig-path-to-baseline-fixtures>"
# The SMB-exposed share path that contains $REFERENCE_RIG_BASE. Used by the
# pre-flight refusal contract to confirm the harness is operating inside the
# share's path coverage.
REFERENCE_RIG_SMB_SHARE_PATH="<absolute-smb-share-path>"
# Free-space minimum required on $REFERENCE_RIG_BASE before a run proceeds.
# Format: any value accepted by `df --output=avail` arithmetic in bytes
# (default 50 GiB).
REFERENCE_RIG_FREE_SPACE_REQUIRED_BYTES="$((50 * 1024 * 1024 * 1024))"

# ----- Resource budgets (cgroup v2 via systemd-run --user --scope) -----
# Slice name; pick something namespaced to this harness.
REFERENCE_RIG_SLICE="pnd-reference-rig.slice"
REFERENCE_RIG_CPU_WEIGHT="20"
REFERENCE_RIG_IO_WEIGHT="10"
REFERENCE_RIG_MEMORY_HIGH="4G"
REFERENCE_RIG_MEMORY_MAX="8G"

# ----- Healthcheck -----
# Space-separated list of systemd unit names that must be `active (running)`
# before/during/after every harness invocation.
REFERENCE_RIG_HEALTHCHECK_SERVICES="<service-a> <service-b>"
# Block device name (without /dev/) whose extended stats are sampled to
# detect latency outliers under harness load. Should be the NVMe holding
# $REFERENCE_RIG_BASE.
REFERENCE_RIG_NVME_DEVICE="<nvme-device>"
# Primary-workload service whose degradation must short-circuit the run.
REFERENCE_RIG_PRIMARY_WORKLOAD_SERVICE="<primary-workload-unit>"

# ----- Manifest URL the doctor binary fetches -----
# Full HTTPS URL to manifest.json on the rig. Used both by the in-process
# diagnose runs (passed as --canonical) and by mint.sh's smoke test. The
# CN of the rig's TLS cert must match the hostname in this URL.
REFERENCE_RIG_MANIFEST_URL="https://<rig-fqdn>:18443/manifest.json"

# ----- Manifest minting defaults (mint.sh) -----
# Pre-fill the canonical-identity values mint.sh uses when --block-height /
# --core-version / --created-at are omitted on the command line.
REFERENCE_RIG_MANIFEST_BLOCK_HEIGHT=""
REFERENCE_RIG_MANIFEST_CORE_VERSION=""
REFERENCE_RIG_MANIFEST_CREATED_AT=""

# ----- Local results destination (on dev host) -----
# Where run.sh fetch-results writes captured run artifacts on this dev host.
REFERENCE_RIG_LOCAL_RESULTS="$HOME/pnd-reference-rig-results"
