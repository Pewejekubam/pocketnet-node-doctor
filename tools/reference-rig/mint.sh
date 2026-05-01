#!/usr/bin/env bash
# tools/reference-rig/mint.sh — build rig-helper, deploy it to the rig, mint
# a manifest from a canonical SQLite path on the rig, print the trust-root.
#
# Usage:
#   ./mint.sh <rig-absolute-path-to-main.sqlite3> [--block-height N] \
#             [--core-version V] [--created-at RFC3339]
#
# Prints to stdout: a single 64-hex SHA-256 trust-root. Pipe / capture it for
# deploy.sh:
#
#   TRUST_ROOT=$(./mint.sh /data/checkpoint-doctor-experiment/april-source/main.sqlite3 \
#                  --block-height 3806626 --core-version 0.21.16-test \
#                  --created-at 2026-04-15T00:00:00Z)
#   ./deploy.sh "$TRUST_ROOT"
#
# Side effect on the rig: writes manifest.json under
# $REFERENCE_RIG_BASE/manifests/ (the nginx document root).

set -euo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"
load_config

if [[ $# -lt 1 ]]; then
  sed -n '2,20p' "$0" >&2
  exit 64
fi
SQLITE_PATH="$1"; shift

# Pre-flight: rig health.
"$HARNESS_DIR/healthcheck.sh" >&2

# Defaults sourced from config.local.sh; overridable per-invocation.
BLOCK_HEIGHT="${REFERENCE_RIG_MANIFEST_BLOCK_HEIGHT:-0}"
CORE_VERSION="${REFERENCE_RIG_MANIFEST_CORE_VERSION:-}"
CREATED_AT="${REFERENCE_RIG_MANIFEST_CREATED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
WHOLE_FILE_ARGS=()

while (( $# )); do
  case "$1" in
    --block-height)  BLOCK_HEIGHT="$2"; shift 2;;
    --core-version)  CORE_VERSION="$2"; shift 2;;
    --created-at)    CREATED_AT="$2"; shift 2;;
    --whole-file)    WHOLE_FILE_ARGS+=(--whole-file "$2"); shift 2;;
    *) echo "unknown arg: $1" >&2; exit 64;;
  esac
done

if [[ "$BLOCK_HEIGHT" == "0" || -z "$CORE_VERSION" ]]; then
  echo "ERROR: --block-height (>0) and --core-version are required" >&2
  echo "       (or set REFERENCE_RIG_MANIFEST_BLOCK_HEIGHT / _CORE_VERSION in config.local.sh)" >&2
  exit 64
fi

# Build rig-helper.
SHA="$(git_short_hash)"
HELPER_LOCAL="$REPO_ROOT/.build/rig-helper-$SHA"
mkdir -p "$REPO_ROOT/.build"
echo "==> Building rig-helper-$SHA" >&2
( cd "$REPO_ROOT" && GOTOOLCHAIN=local CGO_ENABLED=0 go build -o "$HELPER_LOCAL" ./tools/reference-rig/cmd/rig-helper )

echo "==> rsync rig-helper -> $REFERENCE_RIG_BASE/bin/" >&2
ssh_rig "mkdir -p '$REFERENCE_RIG_BASE/bin' '$REFERENCE_RIG_BASE/manifests'"
rsync_to_rig "$HELPER_LOCAL" "$REFERENCE_RIG_BASE/bin/"

OUT="$REFERENCE_RIG_BASE/manifests/manifest.json"
echo "==> Minting manifest on rig from $SQLITE_PATH" >&2
TRUST_ROOT="$(ssh_rig "
  '$REFERENCE_RIG_BASE/bin/rig-helper-$SHA' mint \
    --sqlite '$SQLITE_PATH' \
    --pocketnet-core-version '$CORE_VERSION' \
    --block-height $BLOCK_HEIGHT \
    --created-at '$CREATED_AT' \
    --out '$OUT' \
    ${WHOLE_FILE_ARGS[*]}
" 2>&1 | tail -1)"

if ! [[ "$TRUST_ROOT" =~ ^[0-9a-f]{64}$ ]]; then
  echo "ERROR: rig-helper did not return a 64-hex trust-root; got: $TRUST_ROOT" >&2
  exit 1
fi

# Sanity: confirm nginx serves the freshly-minted manifest via TLS at the
# operator-configured endpoint. Skipped silently if REFERENCE_RIG_MANIFEST_URL
# is unset (manifest is on disk; serving may be configured later).
if [[ -n "${REFERENCE_RIG_MANIFEST_URL:-}" ]]; then
  echo "==> Smoke-testing TLS endpoint: $REFERENCE_RIG_MANIFEST_URL" >&2
  ssh_rig "curl -fsS -o /dev/null -w 'HTTP %{http_code} bytes=%{size_download}\n' '$REFERENCE_RIG_MANIFEST_URL'" >&2 \
    || echo "WARN: TLS smoke test failed; manifest is on disk but nginx serving may need attention" >&2
fi

echo "$TRUST_ROOT"
