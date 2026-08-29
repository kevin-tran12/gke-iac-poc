#!/usr/bin/env bash
set -euo pipefail

if command -v chmod >/dev/null 2>&1; then
  chmod +x .githooks/pre-push
fi
git config --local core.hooksPath .githooks
printf 'Installed repository hooks from .githooks (pre-push runs every local layer gate).\n'
