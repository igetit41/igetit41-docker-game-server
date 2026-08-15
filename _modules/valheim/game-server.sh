#!/bin/bash

# Write module env from GAME_ENV_B64 metadata. Sourced by startup-script.sh; also run by systemd.

install_env_from_metadata() {
  local dest="${1:?env file destination required}"

  local env_b64
  env_b64=$(curl -sf \
    "http://metadata.google.internal/computeMetadata/v1/instance/attributes/GAME_ENV_B64" \
    -H "Metadata-Flavor: Google" || true)

  if [ -z "$env_b64" ]; then
    echo "ERROR: GAME_ENV_B64 missing from instance metadata."
    echo "Ensure _modules/valheim/valheim.env exists locally and run terraform apply."
    exit 1
  fi

  mkdir -p "$(dirname "$dest")"
  echo "$env_b64" | base64 -d > "$dest"
  sed -i 's/\r$//' "$dest"
  chmod 600 "$dest"
  if id game-server &>/dev/null; then
    chown game-server:game-server "$dest" 2>/dev/null || true
  fi

  echo "-----game-server-output-env-installed"
}

upsert_env_var() {
  local file="$1"
  local key="$2"
  local value="$3"
  touch "$file"
  if grep -qE "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

# When sourced, only define helpers used by startup-script.sh.
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  return 0
fi

echo "-----game-server-output-pull-origin"

GAME_NAME=valheim

STANDARD_REPO=/home/game-server/igetit41-docker-game-server
FLAT_REPO=/home/game-server
if [ -f "$STANDARD_REPO/_modules/$GAME_NAME/compose.yaml" ]; then
  REPO_ROOT=$STANDARD_REPO
elif [ -f "$FLAT_REPO/_modules/$GAME_NAME/compose.yaml" ]; then
  REPO_ROOT=$FLAT_REPO
else
  REPO_ROOT=$STANDARD_REPO
fi

MODULE_DIR="$REPO_ROOT/_modules/$GAME_NAME"
COMPOSE_FILE="$MODULE_DIR/compose.yaml"

git -C "$REPO_ROOT" reset --hard
git -C "$REPO_ROOT" pull origin main

# Re-exec after pull so this process runs the on-disk script.
if [ "${GAME_SERVER_REEXEC:-0}" != "1" ]; then
  export GAME_SERVER_REEXEC=1
  echo "-----game-server-output-reexec-after-pull"
  exec bash "${BASH_SOURCE[0]}"
fi

chmod +x "$REPO_ROOT/_modules"/*.sh 2>/dev/null || true
chmod +x "$MODULE_DIR"/*.sh 2>/dev/null || true
chmod +x "$REPO_ROOT"/*.sh 2>/dev/null || true

echo "-----game-server-output-install-env"
install_env_from_metadata "$MODULE_DIR/valheim.env"

SERVER_PASSWORD=$(curl -sf \
  "http://metadata.google.internal/computeMetadata/v1/instance/attributes/SERVER_PASSWORD" \
  -H "Metadata-Flavor: Google" || true)
if [ -n "$SERVER_PASSWORD" ]; then
  upsert_env_var "$MODULE_DIR/valheim.env" "SERVER_PASS" "$SERVER_PASSWORD"
  echo "-----game-server-output-password-from-metadata"
fi

echo "-----game-server-output-valheim-data-dirs"
mkdir -p "$MODULE_DIR/config" "$MODULE_DIR/data" \
  "$MODULE_DIR/config/bepinex/plugins" \
  "$MODULE_DIR/config/bepinex/config"

# game-server must own config for Thunderstore writes; container later uses 1000:1000.
echo "-----game-server-output-valheim-config-owner"
docker run --rm \
  -v "$MODULE_DIR/config:/vconfig" \
  -v "$MODULE_DIR/data:/vdata" \
  alpine:3.19 \
  sh -c "chown -R $(id -u):$(id -g) /vconfig /vdata"

BEPINEX_FLAG=$(grep -E '^BEPINEX=' "$MODULE_DIR/valheim.env" 2>/dev/null | tail -n1 | sed 's/^BEPINEX=//')
PACK_ID=$(grep -E '^THUNDERSTORE_PACK=' "$MODULE_DIR/valheim.env" 2>/dev/null | tail -n1 | sed 's/^THUNDERSTORE_PACK=//')
PACK_VER=$(grep -E '^THUNDERSTORE_PACK_VERSION=' "$MODULE_DIR/valheim.env" 2>/dev/null | tail -n1 | sed 's/^THUNDERSTORE_PACK_VERSION=//')

# Thunderstore: pack dependency list at latest; reinstall only when .thunderstore-resolved drifts.
PLUGINS_REFRESHED=0
if [[ "${BEPINEX_FLAG,,}" == "true" ]] && [ -n "$PACK_ID" ]; then
  echo "-----game-server-output-thunderstore-pack $PACK_ID ${PACK_VER:-latest}"
  command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required for Thunderstore install"; exit 1; }
  command -v unzip >/dev/null 2>&1 || { echo "ERROR: unzip required for Thunderstore install"; exit 1; }

  API_BASE="https://thunderstore.io/api/experimental/package"
  DL_BASE="https://thunderstore.io/package/download"
  BEPINEX_ROOT="$MODULE_DIR/config/bepinex"
  PLUGINS_DIR="$BEPINEX_ROOT/plugins"
  CONFIG_DIR="$BEPINEX_ROOT/config"
  PATCHERS_DIR="$BEPINEX_ROOT/patchers"
  STAGING="$MODULE_DIR/config/.thunderstore-staging"
  mkdir -p "$PLUGINS_DIR" "$CONFIG_DIR" "$PATCHERS_DIR" "$STAGING"

  if [[ ! "$PACK_ID" =~ ^([^-]+)-(.+)$ ]]; then
    echo "ERROR: THUNDERSTORE_PACK must be Namespace-Name (got: $PACK_ID)"
    exit 1
  fi
  PACK_AUTHOR="${BASH_REMATCH[1]}"
  PACK_NAME="${BASH_REMATCH[2]}"

  if [ -n "$PACK_VER" ]; then
    PACK_JSON=$(curl -sfL "$API_BASE/$PACK_AUTHOR/$PACK_NAME/$PACK_VER/")
  else
    PACK_JSON=$(curl -sfL "$API_BASE/$PACK_AUTHOR/$PACK_NAME/" | jq -c '.latest')
  fi
  PACK_VER=$(printf '%s' "$PACK_JSON" | jq -r '.version_number')
  RESOLVED_FILE="$MODULE_DIR/config/.thunderstore-resolved"
  echo "-----thunderstore-install-resolve $PACK_AUTHOR/$PACK_NAME@$PACK_VER (pack-deps-latest)"

  declare -A BEST_VER=()

  ts_parse() {
    if [[ ! "$1" =~ ^([^-]+)-(.+)-([0-9]+\.[0-9].*)$ ]]; then
      return 1
    fi
    printf '%s\t%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
  }

  # Resolve each pack dependency string to Thunderstore latest.
  BEST_VER["${PACK_AUTHOR}-${PACK_NAME}"]="$PACK_VER"
  while IFS= read -r dep; do
    [ -z "$dep" ] && continue
    dparsed=$(ts_parse "$dep") || continue
    IFS=$'\t' read -r da dn _dv <<<"$dparsed"
    key="${da}-${dn}"
    if [ -n "${BEST_VER[$key]:-}" ]; then
      continue
    fi
    echo "-----thunderstore-install-resolve-latest $da/$dn"
    latest=$(curl -sfL --retry 3 --retry-delay 1 "$API_BASE/$da/$dn/" | jq -r '.latest.version_number')
    if [ -z "$latest" ] || [ "$latest" = "null" ]; then
      echo "ERROR: no Thunderstore latest for $da/$dn"
      exit 1
    fi
    BEST_VER[$key]="$latest"
  done < <(printf '%s' "$PACK_JSON" | jq -r '.dependencies[]?')

  RESOLVED_TEXT=$(
    for key in "${!BEST_VER[@]}"; do
      printf '%s=%s\n' "$key" "${BEST_VER[$key]}"
    done | sort
  )

  if [ "${THUNDERSTORE_FORCE:-0}" != "1" ] && [ -f "$RESOLVED_FILE" ] \
      && [ "$(cat "$RESOLVED_FILE")" = "$RESOLVED_TEXT" ] \
      && find "$PLUGINS_DIR" -type f -name '*.dll' -print -quit 2>/dev/null | grep -q .; then
    echo "-----thunderstore-install-skip-resolved-match packages=$(printf '%s\n' "$RESOLVED_TEXT" | wc -l)"
  else
    echo "-----thunderstore-install-download-start packages=$(printf '%s\n' "$RESOLVED_TEXT" | wc -l)"
    NEW_PLUGINS="$STAGING/plugins-new"
    rm -rf "$NEW_PLUGINS" "$STAGING/zips"
    mkdir -p "$NEW_PLUGINS" "$STAGING/zips" "$CONFIG_DIR" "$PATCHERS_DIR"

    INSTALL_KEYS=()
    for key in "${!BEST_VER[@]}"; do
      parsed=$(ts_parse "${key}-${BEST_VER[$key]}") || continue
      IFS=$'\t' read -r author name version <<<"$parsed"
      if [ "${author}-${name}" = "denikson-BepInExPack_Valheim" ]; then
        echo "-----thunderstore-install-skip-bepinex-pack ${author}-${name}"
        continue
      fi
      if [ "${author}-${name}" = "${PACK_AUTHOR}-${PACK_NAME}" ]; then
        echo "-----thunderstore-install-skip-modpack-meta ${author}-${name}"
        continue
      fi
      INSTALL_KEYS+=("$key")
    done

    # Parallel package downloads (max 8).
    DL_PIDS=()
    DL_FAIL="$STAGING/download-failed"
    rm -f "$DL_FAIL"
    for key in "${INSTALL_KEYS[@]}"; do
      parsed=$(ts_parse "${key}-${BEST_VER[$key]}") || continue
      IFS=$'\t' read -r author name version <<<"$parsed"
      zipfile="$STAGING/zips/${author}-${name}-${version}.zip"
      echo "-----thunderstore-install-download $author/$name@$version"
      (
        curl -sfL --retry 3 --retry-delay 1 -o "$zipfile" "$DL_BASE/$author/$name/$version/" \
          || { echo "$author/$name@$version" >> "$DL_FAIL"; exit 1; }
      ) &
      DL_PIDS+=($!)
      if [ "${#DL_PIDS[@]}" -ge 8 ]; then
        for p in "${DL_PIDS[@]}"; do wait "$p" || true; done
        DL_PIDS=()
      fi
    done
    for p in "${DL_PIDS[@]}"; do wait "$p" || true; done
    if [ -f "$DL_FAIL" ]; then
      echo "ERROR: Thunderstore download failed: $(tr '\n' ' ' < "$DL_FAIL")"
      exit 1
    fi

    for key in "${INSTALL_KEYS[@]}"; do
      parsed=$(ts_parse "${key}-${BEST_VER[$key]}") || continue
      IFS=$'\t' read -r author name version <<<"$parsed"
      zipfile="$STAGING/zips/${author}-${name}-${version}.zip"
      echo "-----thunderstore-install-extract $author/$name@$version"
      extract="$STAGING/extract-$$-${author}-${name}"
      rm -rf "$extract"
      mkdir -p "$extract"
      unzip -qo "$zipfile" -d "$extract" \
        || { echo "ERROR: Thunderstore unzip failed $zipfile"; exit 1; }
      [ -d "$extract/BepInEx/config" ] && cp -a "$extract/BepInEx/config"/. "$CONFIG_DIR/"
      [ -d "$extract/BepInEx/patchers" ] && cp -a "$extract/BepInEx/patchers"/. "$PATCHERS_DIR/"
      [ -d "$extract/patchers" ] && cp -a "$extract/patchers"/. "$PATCHERS_DIR/"
      if [ -d "$extract/BepInEx/plugins" ]; then
        cp -a "$extract/BepInEx/plugins"/. "$NEW_PLUGINS/"
      elif [ -d "$extract/plugins" ]; then
        cp -a "$extract/plugins"/. "$NEW_PLUGINS/"
      else
        dest="$NEW_PLUGINS/${author}-${name}"
        mkdir -p "$dest"
        find "$extract" -mindepth 1 -maxdepth 1 \
          ! -name 'manifest.json' ! -name 'icon.png' \
          ! -iname 'README.md' ! -iname 'CHANGELOG.md' ! -iname 'LICENSE*' \
          -exec cp -a {} "$dest/" \;
      fi
      rm -rf "$extract"
    done

    dlls=$(find "$NEW_PLUGINS" -type f -name '*.dll' | wc -l)
    if [ "$dlls" -lt 1 ]; then
      echo "ERROR: Thunderstore install produced no plugin DLLs"
      exit 1
    fi
    if ! find "$NEW_PLUGINS" -type f -iname 'Jotunn.dll' | grep -q .; then
      echo "ERROR: Jotunn.dll missing after Thunderstore install"
      exit 1
    fi
    # Swap plugins into place after a complete download/extract.
    rm -rf "$PLUGINS_DIR"
    mv "$NEW_PLUGINS" "$PLUGINS_DIR"
    printf '%s\n' "$RESOLVED_TEXT" > "$RESOLVED_FILE"
    rm -rf "$STAGING/zips"
    PLUGINS_REFRESHED=1
    echo "-----thunderstore-install-done packages=$(printf '%s\n' "$RESOLVED_TEXT" | wc -l) dlls=$dlls"
  fi
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed; refusing compose up."
  exit 1
fi

echo "-----game-server-output-valheim-data-perms"
docker run --rm \
  -v "$MODULE_DIR/config:/vconfig" \
  -v "$MODULE_DIR/data:/vdata" \
  alpine:3.19 \
  sh -c "chown -R 1000:1000 /vconfig /vdata"

echo "-----game-server-output-docker-compose"
if [ "$PLUGINS_REFRESHED" = "1" ]; then
  docker compose --file "$COMPOSE_FILE" up -d --force-recreate
else
  docker compose --file "$COMPOSE_FILE" up -d
fi
echo "-----game-server-output-compose-up-ok"
