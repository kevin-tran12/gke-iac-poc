#!/usr/bin/env bash
set -euo pipefail
: "${LAB_BASE_URL:?public base URL required}"
safe=$(curl -sS -o /dev/null -w '%{http_code}' "$LAB_BASE_URL/hello")
test "$safe" = 200
blocked=$(curl -sS -o /dev/null -w '%{http_code}' "$LAB_BASE_URL/echo?q=%27%20OR%201%3D1--")
test "$blocked" = 403
