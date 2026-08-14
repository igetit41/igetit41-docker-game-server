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

env_get() {
  local file="$1"
  local key="$2"
  local line
  line=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n1 || true)
  printf '%s' "${line#${key}=}"
}

# When sourced, only define helpers.
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

echo "-----game-server-output-valheim-data-perms"
mkdir -p "$MODULE_DIR/config" "$MODULE_DIR/data" \
  "$MODULE_DIR/config/bepinex/plugins" \
  "$MODULE_DIR/config/bepinex/config"
docker run --rm \
  -v "$MODULE_DIR/config:/vconfig" \
  -v "$MODULE_DIR/data:/vdata" \
  alpine:3.19 \
  sh -c "chown -R 1000:1000 /vconfig /vdata"

BEPINEX_FLAG=$(env_get "$MODULE_DIR/valheim.env" "BEPINEX")
PACK_ID=$(env_get "$MODULE_DIR/valheim.env" "THUNDERSTORE_PACK")
PACK_VER=$(env_get "$MODULE_DIR/valheim.env" "THUNDERSTORE_PACK_VERSION")
if [[ "${BEPINEX_FLAG,,}" == "true" ]] && [ -n "$PACK_ID" ]; then
  echo "-----game-server-output-thunderstore-pack $PACK_ID $PACK_VER"
  sudo apt-get install -y jq unzip >/dev/null 2>&1 || true
  /bin/bash "$MODULE_DIR/install-thunderstore-pack.sh" "$MODULE_DIR" "$PACK_ID" "$PACK_VER"
fi

echo "-----game-server-output-docker-compose"
docker compose --file "$COMPOSE_FILE" up -d
echo "-----game-server-output-compose-up-ok"
