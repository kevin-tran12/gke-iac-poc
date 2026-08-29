#!/usr/bin/env bash
set -euo pipefail

for source in docs/diagrams/source/*.mmd; do
  target="docs/diagrams/rendered/$(basename "${source%.mmd}").svg"
  npx --yes @mermaid-js/mermaid-cli@11.12.0 -i "$source" -o "$target" -b transparent
done
