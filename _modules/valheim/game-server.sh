#!/bin/bash

# Write module env from GAME_ENV_B64 metadata.
# Sourced by startup-script.sh on first boot; also run when executed by systemd.

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

chmod +x "$REPO_ROOT/_modules"/*.sh 2>/dev/null || true
chmod +x "$MODULE_DIR"/*.sh 2>/dev/null || true
chmod +x "$REPO_ROOT"/*.sh 2>/dev/null || true
sudo cp "$REPO_ROOT/_modules/game-server.service" /etc/systemd/system/game-server.service
sudo systemctl daemon-reload

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

BEPINEX_FLAG=$(grep -E '^BEPINEX=' "$MODULE_DIR/valheim.env" 2>/dev/null | tail -n1 | sed 's/^BEPINEX=//')
PACK_ID=$(grep -E '^THUNDERSTORE_PACK=' "$MODULE_DIR/valheim.env" 2>/dev/null | tail -n1 | sed 's/^THUNDERSTORE_PACK=//')
PACK_VER=$(grep -E '^THUNDERSTORE_PACK_VERSION=' "$MODULE_DIR/valheim.env" 2>/dev/null | tail -n1 | sed 's/^THUNDERSTORE_PACK_VERSION=//')

# Thunderstore pack → config/bepinex (Valheim prep, same as chown / compose).
# Highest version per Author-Name wins so older transitive pins cannot overwrite Jotunn.
if [[ "${BEPINEX_FLAG,,}" == "true" ]] && [ -n "$PACK_ID" ]; then
  echo "-----game-server-output-thunderstore-pack $PACK_ID ${PACK_VER:-latest}"
  sudo apt-get install -y jq unzip >/dev/null 2>&1 || true
  command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required for Thunderstore install"; exit 1; }
  command -v unzip >/dev/null 2>&1 || { echo "ERROR: unzip required for Thunderstore install"; exit 1; }

  API_BASE="https://thunderstore.io/api/experimental/package"
  DL_BASE="https://thunderstore.io/package/download"
  BEPINEX_ROOT="$MODULE_DIR/config/bepinex"
  PLUGINS_DIR="$BEPINEX_ROOT/plugins"
  CONFIG_DIR="$BEPINEX_ROOT/config"
  PATCHERS_DIR="$BEPINEX_ROOT/patchers"
  STAGING="$MODULE_DIR/config/.thunderstore-staging"
  STAMP_FILE="$MODULE_DIR/config/.thunderstore-pack-stamp"
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
  STAMP="v2|${PACK_AUTHOR}-${PACK_NAME}-${PACK_VER}"
  echo "-----thunderstore-install-resolve $PACK_AUTHOR/$PACK_NAME@$PACK_VER"

  if [ "${THUNDERSTORE_FORCE:-0}" != "1" ] && [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE")" = "$STAMP" ] \
      && find "$PLUGINS_DIR" -type f -name '*.dll' -print -quit 2>/dev/null | grep -q .; then
    echo "-----thunderstore-install-skip-stamp-match $STAMP"
  else
    declare -A BEST_VER=()
    QUEUE_KEYS=()

    ts_parse() {
      if [[ ! "$1" =~ ^([^-]+)-(.+)-([0-9]+\.[0-9].*)$ ]]; then
        return 1
      fi
      printf '%s\t%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
    }

    ts_enqueue() {
      local author="$1" name="$2" version="$3" key="${1}-${2}"
      local cur="${BEST_VER[$key]:-}"
      if [ -z "$cur" ]; then
        BEST_VER[$key]="$version"
        QUEUE_KEYS+=("$key")
        return 0
      fi
      local best
      best=$(printf '%s\n%s\n' "$cur" "$version" | sort -V | tail -n1)
      if [ "$best" != "$cur" ]; then
        echo "-----thunderstore-install-upgrade $key $cur -> $best"
        BEST_VER[$key]="$best"
        QUEUE_KEYS+=("$key")
      fi
    }

    ts_enqueue "$PACK_AUTHOR" "$PACK_NAME" "$PACK_VER"
    idx=0
    while [ "$idx" -lt "${#QUEUE_KEYS[@]}" ]; do
      key="${QUEUE_KEYS[$idx]}"
      idx=$((idx + 1))
      parsed=$(ts_parse "${key}-${BEST_VER[$key]}") || continue
      IFS=$'\t' read -r author name version <<<"$parsed"
      echo "-----thunderstore-install-resolve-deps $author/$name@$version"
      meta=$(curl -sfL "$API_BASE/$author/$name/$version/")
      while IFS= read -r dep; do
        [ -z "$dep" ] && continue
        dparsed=$(ts_parse "$dep") || continue
        IFS=$'\t' read -r da dn dv <<<"$dparsed"
        ts_enqueue "$da" "$dn" "$dv"
      done < <(printf '%s' "$meta" | jq -r '.dependencies[]?')
    done

    echo "-----thunderstore-install-clear-plugins"
    rm -rf "$PLUGINS_DIR"
    mkdir -p "$PLUGINS_DIR"

    for key in "${!BEST_VER[@]}"; do
      parsed=$(ts_parse "${key}-${BEST_VER[$key]}") || continue
      IFS=$'\t' read -r author name version <<<"$parsed"
      if [ "${author}-${name}" = "denikson-BepInExPack_Valheim" ]; then
        echo "-----thunderstore-install-skip-bepinex-pack ${author}-${name}"
        continue
      fi
      echo "-----thunderstore-install-package $author/$name@$version"
      zipfile="$STAGING/${author}-${name}-${version}.zip"
      curl -sfL --retry 3 -o "$zipfile" "$DL_BASE/$author/$name/$version/" \
        || { echo "ERROR: Thunderstore download failed $author/$name@$version"; exit 1; }
      extract="$STAGING/extract-$$"
      rm -rf "$extract"
      mkdir -p "$extract"
      unzip -qo "$zipfile" -d "$extract" \
        || { echo "ERROR: Thunderstore unzip failed $zipfile"; exit 1; }
      [ -d "$extract/BepInEx/config" ] && mkdir -p "$CONFIG_DIR" && cp -a "$extract/BepInEx/config"/. "$CONFIG_DIR/"
      [ -d "$extract/BepInEx/patchers" ] && mkdir -p "$PATCHERS_DIR" && cp -a "$extract/BepInEx/patchers"/. "$PATCHERS_DIR/"
      [ -d "$extract/patchers" ] && mkdir -p "$PATCHERS_DIR" && cp -a "$extract/patchers"/. "$PATCHERS_DIR/"
      if [ -d "$extract/BepInEx/plugins" ]; then
        cp -a "$extract/BepInEx/plugins"/. "$PLUGINS_DIR/"
      elif [ -d "$extract/plugins" ]; then
        cp -a "$extract/plugins"/. "$PLUGINS_DIR/"
      else
        dest="$PLUGINS_DIR/${author}-${name}"
        mkdir -p "$dest"
        find "$extract" -mindepth 1 -maxdepth 1 \
          ! -name 'manifest.json' ! -name 'icon.png' \
          ! -iname 'README.md' ! -iname 'CHANGELOG.md' ! -iname 'LICENSE*' \
          -exec cp -a {} "$dest/" \;
      fi
      rm -rf "$extract" "$zipfile"
    done

    dlls=$(find "$PLUGINS_DIR" -type f -name '*.dll' | wc -l)
    printf '%s\n' "$STAMP" > "$STAMP_FILE"
    echo "-----thunderstore-install-done $STAMP dlls=$dlls"
    if [ "$dlls" -lt 1 ]; then
      echo "ERROR: Thunderstore install produced no plugin DLLs"
      exit 1
    fi
    if ! find "$PLUGINS_DIR" -type f -iname 'Jotunn.dll' | grep -q .; then
      echo "ERROR: Jotunn.dll missing after Thunderstore install"
      exit 1
    fi
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
docker compose --file "$COMPOSE_FILE" up -d
echo "-----game-server-output-compose-up-ok"
