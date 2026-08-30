#!/usr/bin/env bash
set -euo pipefail

required=(
  README.md docs/executive-summary.md docs/architecture.md docs/build-order.md
  docs/ci-strategy.md docs/service-catalog.md docs/api-catalog.md
  docs/iam-permission-matrix.md docs/security-model.md
  docs/test-strategy.md docs/cost-and-teardown.md evidence/index.md
)
for path in "${required[@]}"; do
  test -s "$path" || { printf 'missing or empty documentation: %s\n' "$path" >&2; exit 1; }
done

if rg -n --glob '*.md' 'file://|C:\\Users\\|Authorization: Bearer [A-Za-z0-9]' .; then
  printf 'documentation contains a local path or credential-like value\n' >&2
  exit 1
fi
