#!/usr/bin/env bash
# tools/reference-rig/deploy.sh — build pocketnet-node-doctor and stage to rig.
#
# Steps:
#   1. Verify config.local.sh + healthcheck PASS.
#   2. Build the binary with -ldflags injection of Version (git short hash),
#      Commit (full sha), BuildDate, and PinnedHash (rig-side trust-root for
#      whatever manifest will be served).
#   3. Compute SHA-256 of the binary locally.
#   4. rsync binary + remote/ scripts to $REFERENCE_RIG_BASE/{bin,deploy}/.
#   5. Verify SHA-256 on the rig matches the local computation.
#   6. Print the deployed binary's path + hash so subsequent run.sh can
#      reference it.

set -euo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"
load_config

PINNED_HASH="${1:-}"
if [[ -z "$PINNED_HASH" ]]; then
  echo "usage: $0 <pinned-trust-root-hex>" >&2
  echo "  The trust-root must match the canonical-form SHA-256 of the manifest" >&2
  echo "  this binary will be tested against. Mint the manifest first via the" >&2
  echo "  chunk-001 manifest generator (or rig-side helper)." >&2
  exit 64
fi
if [[ ! "$PINNED_HASH" =~ ^[0-9a-f]{64}$ ]]; then
  echo "ERROR: pinned hash must be 64 lowercase hex chars; got: $PINNED_HASH" >&2
  exit 64
fi

# Pre-flight: rig health.
"$HARNESS_DIR/healthcheck.sh" >&2

SHA="$(git_short_hash)"
COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BIN_LOCAL="$REPO_ROOT/.build/pocketnet-node-doctor-$SHA"

mkdir -p "$REPO_ROOT/.build"
echo "==> Building pocketnet-node-doctor-$SHA"
(
  cd "$REPO_ROOT"
  GOTOOLCHAIN=local CGO_ENABLED=0 go build \
    -ldflags "-X github.com/pocketnet-team/pocketnet-node-doctor/internal/buildinfo.Version=$SHA \
              -X github.com/pocketnet-team/pocketnet-node-doctor/internal/buildinfo.Commit=$COMMIT \
              -X github.com/pocketnet-team/pocketnet-node-doctor/internal/buildinfo.BuildDate=$BUILD_DATE \
              -X github.com/pocketnet-team/pocketnet-node-doctor/internal/trustroot.PinnedHash=$PINNED_HASH" \
    -o "$BIN_LOCAL" \
    ./cmd/pocketnet-node-doctor
)

LOCAL_SHA256="$(sha256sum "$BIN_LOCAL" | awk '{print $1}')"
echo "==> Local sha256: $LOCAL_SHA256"

echo "==> rsync binary -> $REFERENCE_RIG_BASE/bin/"
ssh_rig "mkdir -p '$REFERENCE_RIG_BASE/bin' '$REFERENCE_RIG_BASE/deploy' '$REFERENCE_RIG_BASE/runs'"
rsync_to_rig "$BIN_LOCAL" "$REFERENCE_RIG_BASE/bin/"
rsync_to_rig "$HARNESS_DIR/remote/" "$REFERENCE_RIG_BASE/deploy/"

# Drop a pocketnet-core stub so the version-mismatch predicate has something
# to invoke. The reference rig is a storage head (no pocketnet-core service)
# but the doctor's version-mismatch predicate requires `pocketnet-core
# --version` to return the canonical version. The stub returns whatever
# REFERENCE_RIG_MANIFEST_CORE_VERSION is set to in config.local.sh.
echo "==> Installing pocketnet-core version stub on rig"
core_version="${REFERENCE_RIG_MANIFEST_CORE_VERSION:-0.21.16-test}"
ssh_rig "cat > '$REFERENCE_RIG_BASE/bin/pocketnet-core' <<'STUB_EOF'
#!/usr/bin/env bash
# Reference-rig stub: storage-head has no real pocketnet-core; this stub
# satisfies the doctor's version-mismatch predicate.
case \"\$1\" in
  --version) echo '$core_version' ;;
  *) echo 'pocketnet-core (stub): only --version is implemented' >&2; exit 64 ;;
esac
STUB_EOF
chmod +x '$REFERENCE_RIG_BASE/bin/pocketnet-core'"

REMOTE_SHA256="$(ssh_rig "sha256sum '$REFERENCE_RIG_BASE/bin/$(basename "$BIN_LOCAL")' | awk '{print \$1}'")"
if [[ "$LOCAL_SHA256" != "$REMOTE_SHA256" ]]; then
  echo "ERROR: deployed binary hash mismatch" >&2
  echo "  local:  $LOCAL_SHA256" >&2
  echo "  remote: $REMOTE_SHA256" >&2
  exit 1
fi
echo "==> Verified remote sha256 matches"
echo
echo "Deployed: $REFERENCE_RIG_BASE/bin/$(basename "$BIN_LOCAL")"
echo "Pinned trust-root: $PINNED_HASH"
echo "Use scenario name with run.sh, e.g.: $HARNESS_DIR/run.sh sc001"
