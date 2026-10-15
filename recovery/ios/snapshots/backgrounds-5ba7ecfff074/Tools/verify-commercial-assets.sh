#!/usr/bin/env bash
set -euo pipefail

# Distribution boundary only.
#
# This guard never inspects or restricts files a user selects at runtime through
# Files/iCloud. KANTA may import and play any structurally valid user-supplied
# SF2 regardless of its filename. This check exists only to prevent user/third-
# party media from being accidentally committed to and shipped with KANTA.

violations=()

while IFS= read -r -d '' path; do
  lower="$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')"

  case "$lower" in
    *.sf2|*.sfz|*.mid|*.midi|*.kar|*.mp3|*.wav|*.m4a|*.aac|*.flac|*.ogg)
      violations+=("$path")
      ;;
  esac

  case "$path" in
    ReferenceUploads/*|ThirdParty/Reference/*)
      size="$(git cat-file -s "HEAD:$path" 2>/dev/null || printf '0')"
      if [[ "$size" =~ ^[0-9]+$ ]] && (( size > 1048576 )); then
        violations+=("$path")
      fi
      ;;
  esac
done < <(git ls-files -z)

if ((${#violations[@]} > 0)); then
  printf '%s\n' "::error::Distribution guard rejected user/third-party media tracked in source control."
  printf '%s\n' "KANTA is BYOL: runtime imports are allowed, but user libraries and SoundFonts must not ship inside the app or repository."
  printf ' - %s\n' "${violations[@]}" | sort -u
  exit 1
fi

echo "Distribution guard passed: no user/third-party karaoke media is tracked for shipment."
echo "Runtime Files/iCloud imports, including arbitrarily named valid SF2 files, remain allowed."
