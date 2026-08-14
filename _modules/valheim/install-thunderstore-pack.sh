#!/bin/bash
# Download a Thunderstore package + transitive deps into Valheim BepInEx dirs.
# Skips denikson-BepInExPack_Valheim — lloesche image installs that when BEPINEX=true.
#
# Usage: install-thunderstore-pack.sh <module_dir> <Namespace-Name> [version]
# Env: THUNDERSTORE_FORCE=1 to re-download even if stamp matches.

set -euo pipefail

MODULE_DIR="${1:?module dir required}"
PACK_ID="${2:?Thunderstore Namespace-Name required}"
PACK_VERSION="${3:-}"

API_BASE="https://thunderstore.io/api/experimental/package"
DL_BASE="https://thunderstore.io/package/download"
SKIP_PACKAGES="denikson-BepInExPack_Valheim"

BEPINEX_ROOT="$MODULE_DIR/config/bepinex"
PLUGINS_DIR="$BEPINEX_ROOT/plugins"
CONFIG_DIR="$BEPINEX_ROOT/config"
PATCHERS_DIR="$BEPINEX_ROOT/patchers"
STAGING="$MODULE_DIR/config/.thunderstore-staging"
STAMP_FILE="$MODULE_DIR/config/.thunderstore-pack-stamp"

mkdir -p "$PLUGINS_DIR" "$CONFIG_DIR" "$PATCHERS_DIR" "$STAGING"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required for Thunderstore pack install" >&2
  exit 1
fi
if ! command -v unzip >/dev/null 2>&1; then
  echo "-----thunderstore-install-apt-unzip"
  sudo apt-get update -y
  sudo apt-get install -y unzip
fi

parse_dep() {
  # Author-Name-1.2.3 → AUTHOR NAME VERSION (name may contain hyphens/underscores)
  local dep="$1"
  if [[ ! "$dep" =~ ^([^-]+)-(.+)-([0-9]+\.[0-9].*)$ ]]; then
    echo "WARN: skip unparseable dependency: $dep" >&2
    return 1
  fi
  printf '%s\t%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
}

fetch_version_json() {
  local author="$1" name="$2" version="$3"
  if [ -n "$version" ]; then
    curl -sfL "$API_BASE/$author/$name/$version/"
  else
    curl -sfL "$API_BASE/$author/$name/" | jq -c '.latest'
  fi
}

install_zip_contents() {
  local zipfile="$1"
  local extract="$STAGING/extract-$$"
  rm -rf "$extract"
  mkdir -p "$extract"
  unzip -qo "$zipfile" -d "$extract"

  # Common Thunderstore layouts
  if [ -d "$extract/BepInEx/plugins" ]; then
    cp -a "$extract/BepInEx/plugins/." "$PLUGINS_DIR/"
  fi
  if [ -d "$extract/BepInEx/config" ]; then
    cp -a "$extract/BepInEx/config/." "$CONFIG_DIR/"
  fi
  if [ -d "$extract/BepInEx/patchers" ]; then
    cp -a "$extract/BepInEx/patchers/." "$PATCHERS_DIR/"
  fi
  if [ -d "$extract/plugins" ]; then
    cp -a "$extract/plugins/." "$PLUGINS_DIR/"
  fi
  if [ -d "$extract/patchers" ]; then
    cp -a "$extract/patchers/." "$PATCHERS_DIR/"
  fi
  # Loose DLLs at package root
  find "$extract" -maxdepth 1 -type f \( -name '*.dll' -o -name '*.dll.mdb' \) -exec cp -a {} "$PLUGINS_DIR/" \;

  rm -rf "$extract"
}

declare -A SEEN=()
QUEUE=()

enqueue() {
  local key="$1"
  if [ -n "${SEEN[$key]:-}" ]; then
    return 0
  fi
  SEEN[$key]=1
  QUEUE+=("$key")
}

# Resolve pack author/name
if [[ ! "$PACK_ID" =~ ^([^-]+)-(.+)$ ]]; then
  echo "ERROR: PACK_ID must be Namespace-Name (got: $PACK_ID)" >&2
  exit 1
fi
PACK_AUTHOR="${BASH_REMATCH[1]}"
PACK_NAME="${BASH_REMATCH[2]}"

echo "-----thunderstore-install-resolve $PACK_AUTHOR/$PACK_NAME version=${PACK_VERSION:-latest}"
PACK_JSON=$(fetch_version_json "$PACK_AUTHOR" "$PACK_NAME" "$PACK_VERSION")
PACK_VERSION=$(printf '%s' "$PACK_JSON" | jq -r '.version_number')
STAMP="${PACK_AUTHOR}-${PACK_NAME}-${PACK_VERSION}"

if [ "${THUNDERSTORE_FORCE:-0}" != "1" ] && [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE")" = "$STAMP" ]; then
  if find "$PLUGINS_DIR" -type f -print -quit 2>/dev/null | grep -q .; then
    echo "-----thunderstore-install-skip-stamp-match $STAMP"
    exit 0
  fi
fi

enqueue "$STAMP"

idx=0
while [ "$idx" -lt "${#QUEUE[@]}" ]; do
  key="${QUEUE[$idx]}"
  idx=$((idx + 1))

  if ! parsed=$(parse_dep "$key"); then
    continue
  fi
  IFS=$'\t' read -r author name version <<<"$parsed"
  full="${author}-${name}"

  skip=false
  for s in $SKIP_PACKAGES; do
    if [ "$full" = "$s" ]; then
      echo "-----thunderstore-install-skip-bepinex-pack $full"
      skip=true
      break
    fi
  done
  if $skip; then
    continue
  fi

  echo "-----thunderstore-install-package $author/$name@$version"
  meta=$(fetch_version_json "$author" "$name" "$version")
  while IFS= read -r dep; do
    [ -z "$dep" ] && continue
    enqueue "$dep"
  done < <(printf '%s' "$meta" | jq -r '.dependencies[]?')

  zipfile="$STAGING/${author}-${name}-${version}.zip"
  curl -sfL --retry 3 -o "$zipfile" "$DL_BASE/$author/$name/$version/"
  install_zip_contents "$zipfile"
  rm -f "$zipfile"
done

printf '%s\n' "$STAMP" > "$STAMP_FILE"
chown -R 1000:1000 "$BEPINEX_ROOT" "$STAMP_FILE" 2>/dev/null || true
echo "-----thunderstore-install-done $STAMP plugins=$(find "$PLUGINS_DIR" -type f | wc -l)"
