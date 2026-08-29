#!/usr/bin/env bash
set -euo pipefail

name=${1:?lab name required}
script="tests/labs/${name}.sh"
test -f "$script" || { printf 'unknown lab: %s\n' "$name" >&2; exit 2; }
test -f .gate-state/layer-8.json || { printf 'baseline edge gate must pass before destructive labs\n' >&2; exit 1; }
timeout "${LAB_TIMEOUT:-15m}" bash "$script"
