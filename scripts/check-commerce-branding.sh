#!/usr/bin/env bash
set -euo pipefail

fail() { echo "COMMERCE BRANDING CHECK FAILED: $*" >&2; exit 1; }

commerce_files=()
while IFS= read -r path; do commerce_files+=("$path"); done < <(
  find Shell -type f -name '*.swift' \
    \( -iname '*paywall*' -o -iname '*purchase*' -o -iname '*subscription*' \
       -o -iname '*winback*' -o -iname '*restore*' -o -iname '*commerce*' \
       -o -iname '*upgrade*' -o -iname '*offer*' \) | sort
)

(( ${#commerce_files[@]} > 0 )) || fail "No commerce surfaces were found"

# SF Symbols are allowed. Named image assets and app-brand references are not.
if rg -n -P 'Image\s*\(\s*(?!systemName:)|UIImage\s*\(\s*named:|ImageResource\.|ShellConfiguration\.appName|\.appIcon\b|Asset\.[A-Za-z0-9_]*(Logo|Icon|Brand)' "${commerce_files[@]}"; then
  fail "A commerce surface references an app image, icon, logo, name, or brand asset"
fi

echo "Commerce surfaces contain no app logo/icon/brand asset references."
