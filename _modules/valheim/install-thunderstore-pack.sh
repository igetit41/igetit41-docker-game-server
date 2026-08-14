#!/bin/bash
# Download a Thunderstore package + transitive deps into Valheim BepInEx dirs.
# Skips denikson-BepInExPack_Valheim — lloesche image installs that when BEPINEX=true.
#
# Resolves each Author-Name once, keeping the highest version (sort -V). Older
# transitive pins must not overwrite newer DLLs (that left Jotunn unloaded).
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
STAMP_FMT=v2

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
  local dep="$1"
  if [[ ! "$dep" =~ ^([^-]+)-(.+)-([0-9]+\.[0-9].*)$ ]]; then
    echo "WARN: skip unparseable dependency: $dep" >&2
    return 1
  fi
  printf '%s\t%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
}

max_version() {
  printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1
}

fetch_version_json() {
  local author="$1" name="$2" version="$3"
  if [ -n "$version" ]; then
    curl -sfL "$API_BASE/$author/$name/$version/"
  else
    curl -sfL "$API_BASE/$author/$name/" | jq -c '.latest'
  fi
}

copy_tree() {
  local src="$1"
  local dest="$2"
  mkdir -p "$dest"
  cp -a "$src"/. "$dest/"
}

install_zip_contents() {
  local zipfile="$1"
  local author="$2"
  local name="$3"
  local extract="$STAGING/extract-$$"
  rm -rf "$extract"
  mkdir -p "$extract"
  unzip -qo "$zipfile" -d "$extract"

  if [ -d "$extract/BepInEx/config" ]; then
    copy_tree "$extract/BepInEx/config" "$CONFIG_DIR"
  fi
  if [ -d "$extract/BepInEx/patchers" ]; then
    copy_tree "$extract/BepInEx/patchers" "$PATCHERS_DIR"
  fi
  if [ -d "$extract/patchers" ]; then
    copy_tree "$extract/patchers" "$PATCHERS_DIR"
  fi

  if [ -d "$extract/BepInEx/plugins" ]; then
    copy_tree "$extract/BepInEx/plugins" "$PLUGINS_DIR"
  elif [ -d "$extract/plugins" ]; then
    copy_tree "$extract/plugins" "$PLUGINS_DIR"
  else
    # Root-layout packages (e.g. Alpus-NorseDemigods): DLL + data next to manifest
    local dest="$PLUGINS_DIR/${author}-${name}"
    mkdir -p "$dest"
    find "$extract" -mindepth 1 -maxdepth 1 \
      ! -name 'manifest.json' \
      ! -name 'icon.png' \
      ! -iname 'README.md' \
      ! -iname 'CHANGELOG.md' \
      ! -iname 'LICENSE*' \
      -exec cp -a {} "$dest/" \;
  fi

  rm -rf "$extract"
}

if [[ ! "$PACK_ID" =~ ^([^-]+)-(.+)$ ]]; then
  echo "ERROR: PACK_ID must be Namespace-Name (got: $PACK_ID)" >&2
  exit 1
fi
PACK_AUTHOR="${BASH_REMATCH[1]}"
PACK_NAME="${BASH_REMATCH[2]}"

echo "-----thunderstore-install-resolve $PACK_AUTHOR/$PACK_NAME version=${PACK_VERSION:-latest}"
PACK_JSON=$(fetch_version_json "$PACK_AUTHOR" "$PACK_NAME" "$PACK_VERSION")
PACK_VERSION=$(printf '%s' "$PACK_JSON" | jq -r '.version_number')
STAMP="${STAMP_FMT}|${PACK_AUTHOR}-${PACK_NAME}-${PACK_VERSION}"

if [ "${THUNDERSTORE_FORCE:-0}" != "1" ] && [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE")" = "$STAMP" ]; then
  if find "$PLUGINS_DIR" -type f -name '*.dll' -print -quit 2>/dev/null | grep -q .; then
    echo "-----thunderstore-install-skip-stamp-match $STAMP"
    exit 0
  fi
fi

# Resolve graph: Author-Name -> highest version seen
declare -A BEST_VER=()
QUEUE_KEYS=()

enqueue_pkg() {
  local author="$1" name="$2" version="$3"
  local key="${author}-${name}"
  local cur="${BEST_VER[$key]:-}"
  if [ -z "$cur" ]; then
    BEST_VER[$key]="$version"
    QUEUE_KEYS+=("$key")
    return 0
  fi
  local best
  best=$(max_version "$cur" "$version")
  if [ "$best" != "$cur" ]; then
    echo "-----thunderstore-install-upgrade $key $cur -> $best"
    BEST_VER[$key]="$best"
    QUEUE_KEYS+=("$key")
  fi
}

enqueue_pkg "$PACK_AUTHOR" "$PACK_NAME" "$PACK_VERSION"

idx=0
while [ "$idx" -lt "${#QUEUE_KEYS[@]}" ]; do
  key="${QUEUE_KEYS[$idx]}"
  idx=$((idx + 1))
  if ! parsed=$(parse_dep "${key}-${BEST_VER[$key]}"); then
    continue
  fi
  IFS=$'\t' read -r author name version <<<"$parsed"
  echo "-----thunderstore-install-resolve-deps $author/$name@$version"
  meta=$(fetch_version_json "$author" "$name" "$version")
  while IFS= read -r dep; do
    [ -z "$dep" ] && continue
    if ! dparsed=$(parse_dep "$dep"); then
      continue
    fi
    IFS=$'\t' read -r da dn dv <<<"$dparsed"
    enqueue_pkg "$da" "$dn" "$dv"
  done < <(printf '%s' "$meta" | jq -r '.dependencies[]?')
done

echo "-----thunderstore-install-clear-plugins"
rm -rf "$PLUGINS_DIR"
mkdir -p "$PLUGINS_DIR"

for key in "${!BEST_VER[@]}"; do
  version="${BEST_VER[$key]}"
  if ! parsed=$(parse_dep "${key}-${version}"); then
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
  zipfile="$STAGING/${author}-${name}-${version}.zip"
  curl -sfL --retry 3 -o "$zipfile" "$DL_BASE/$author/$name/$version/"
  install_zip_contents "$zipfile" "$author" "$name"
  rm -f "$zipfile"
done

dlls=$(find "$PLUGINS_DIR" -type f -name '*.dll' | wc -l)
printf '%s\n' "$STAMP" > "$STAMP_FILE"
chown -R 1000:1000 "$BEPINEX_ROOT" "$STAMP_FILE" 2>/dev/null || true
echo "-----thunderstore-install-done $STAMP dlls=$dlls"
if [ "$dlls" -lt 1 ]; then
  echo "ERROR: Thunderstore install produced no plugin DLLs" >&2
  exit 1
fi
if ! find "$PLUGINS_DIR" -type f -iname 'Jotunn.dll' | grep -q .; then
  echo "ERROR: Jotunn.dll missing after Thunderstore install" >&2
  exit 1
fi
