#!/usr/bin/env bash
set -euo pipefail

registry="ThirdParty/media-provenance.tsv"

if [[ ! -f "$registry" ]]; then
  echo "::error::Missing media provenance registry: $registry"
  exit 1
fi

violations=()

is_background_media() {
  local path="$1"
  local lower
  lower="$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')"

  case "$lower" in
    bgv/*|bg/*)
      case "$lower" in
        *.mp4|*.mov|*.m4v|*.jpg|*.jpeg|*.png|*.heic|*.webp)
          return 0
          ;;
      esac
      ;;
  esac

  return 1
}

while IFS= read -r path; do
  if ! is_background_media "$path"; then
    continue
  fi

  status="$(
    awk -F '	' -v target="$path" '
      NR > 1 && $1 == target { print $2; exit }
    ' "$registry"
  )"

  if [[ "$status" != "approved" ]]; then
    violations+=("$path")
  fi
done < <(git ls-files)

if (( ${#violations[@]} > 0 )); then
  echo "::error::Background media without approved redistribution provenance was found."
  printf ' - %s\n' "${violations[@]}"
  echo "Record the exact path as approved in ThirdParty/media-provenance.tsv only after rights are verified."
  exit 1
fi

echo "Media provenance guard passed."


python3 Tools/verify-bundled-backgrounds.py
