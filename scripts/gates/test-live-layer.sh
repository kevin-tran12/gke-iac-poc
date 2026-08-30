#!/usr/bin/env bash
set -euo pipefail

layer=${1:?layer required}
profile=${2:-core}
(( layer >= 1 && layer <= 9 )) || { printf 'live layer must be 1-9\n' >&2; exit 2; }
test_script=$(printf 'scripts/gates/live/layer-%02d.sh' "$layer")
test -f "$test_script" || { printf 'No live test is defined for layer %s\n' "$layer" >&2; exit 2; }
exec bash "$test_script" "$profile"
