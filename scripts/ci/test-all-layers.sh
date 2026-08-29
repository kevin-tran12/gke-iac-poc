#!/usr/bin/env bash
set -euo pipefail

bash scripts/ci/security-gates.sh
for layer in {0..9}; do
  bash scripts/ci/test-layer.sh "$layer"
done
