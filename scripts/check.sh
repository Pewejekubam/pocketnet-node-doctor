#!/usr/bin/env bash
# T004: gofmt + go vet lint posture (no third-party linters in v1).
# Per plan.md D2/D3: zero runtime dependencies, minimal toolchain footprint.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> gofmt -l (any output = unformatted files; exit non-zero)"
unformatted=$(gofmt -l . 2>&1 || true)
if [[ -n "$unformatted" ]]; then
  echo "FAIL: unformatted files:"
  echo "$unformatted"
  exit 1
fi
echo "OK"

echo "==> go vet ./..."
go vet ./...
echo "OK"

echo "==> go build ./..."
go build ./...
echo "OK"
