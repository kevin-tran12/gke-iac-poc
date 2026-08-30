#!/usr/bin/env bash
set -euo pipefail

mode=${1:---setup}
case "$mode" in
  --setup|--require-auth) ;;
  *) printf 'usage: %s [--setup|--require-auth]\n' "$0" >&2; exit 2 ;;
esac

required_tools=(docker gh git gcloud go gpg helm jq kubectl make python3 rg shellcheck terraform)
missing=()
for tool in "${required_tools[@]}"; do
  command -v "$tool" >/dev/null || missing+=("$tool")
done
if (( ${#missing[@]} > 0 )); then
  printf 'Dev Container is missing required commands: %s\n' "${missing[*]}" >&2
  printf 'Rebuild the container from .devcontainer/devcontainer.json; do not install ad hoc host tools.\n' >&2
  exit 127
fi

persistent_dirs=(
  /home/vscode/.config/gh
  /home/vscode/.config/gcloud
  /home/vscode/.gnupg
  /home/vscode/.cache/go-build
  /home/vscode/go/pkg/mod
  /home/vscode/.cache/trivy
  /home/vscode/.tflint.d
  /home/vscode/.terraform.d/plugin-cache
)
for directory in "${persistent_dirs[@]}"; do
  test -d "$directory" || { printf 'persistent path is missing: %s\n' "$directory" >&2; exit 1; }
  test -w "$directory" || { printf 'persistent path is not writable by %s: %s\n' "$(id -un)" "$directory" >&2; exit 1; }
done
test "$(stat -c '%a' /home/vscode/.gnupg)" = 700 || {
  printf 'GPG home permissions must be 700. Run: chmod 700 /home/vscode/.gnupg\n' >&2
  exit 1
}

if [[ $mode == --require-auth ]]; then
  gh auth status >/dev/null || {
    printf 'GitHub CLI is not authenticated. Run: gh auth login\n' >&2
    exit 1
  }
  gcloud auth application-default print-access-token >/dev/null 2>&1 || {
    printf 'Application Default Credentials are unavailable. Run: gcloud auth application-default login\n' >&2
    exit 1
  }
fi

printf 'Dev Container commands and persistent volumes are ready.\n'
