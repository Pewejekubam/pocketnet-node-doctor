#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
source "${REPO_ROOT}/tools/chunk-runner/run.sh"
# If we got here, main did not auto-run
echo "SOURCEABLE_OK"
