#!/usr/bin/env bash
set -euo pipefail

hook_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/gke-iac-poc/hooks"
mkdir -p "$hook_dir"
cp .githooks/pre-push "$hook_dir/pre-push"
chmod 0755 "$hook_dir/pre-push"
git config --local core.hooksPath "$hook_dir"
printf 'Installed repository hooks in %s (pre-push runs every local layer gate).\n' "$hook_dir"
