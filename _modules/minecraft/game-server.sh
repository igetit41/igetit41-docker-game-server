#!/bin/bash

# Write module env + optional API key from GAME_ENV_B64 / GAME_API_KEY_B64 metadata.
# Sourced by startup-script.sh on first boot; also run when executed by systemd.

install_env_from_metadata() {
  local dest="${1:?env file destination required}"
  local api_key_secret="${2:-}"

  local env_b64 key_b64
  env_b64=$(curl -sf \
    "http://metadata.google.internal/computeMetadata/v1/instance/attributes/GAME_ENV_B64" \
    -H "Metadata-Flavor: Google" || true)
  key_b64=$(curl -sf \
    "http://metadata.google.internal/computeMetadata/v1/instance/attributes/GAME_API_KEY_B64" \
    -H "Metadata-Flavor: Google" || true)

  if [ -z "$env_b64" ]; then
    echo "ERROR: GAME_ENV_B64 missing from instance metadata."
    echo "Ensure the module env file exists locally and run terraform apply."
    exit 1
  fi

  mkdir -p "$(dirname "$dest")"
  echo "$env_b64" | base64 -d > "$dest"
  sed -i 's/\r$//' "$dest"
  chmod 600 "$dest"
  if id game-server &>/dev/null; then
    chown game-server:game-server "$dest" 2>/dev/null || true
  fi

  if [ -n "$key_b64" ] && [ -n "$api_key_secret" ]; then
    echo "$key_b64" | base64 -d > "$api_key_secret"
    chmod 400 "$api_key_secret"
    chown 1000:1000 "$api_key_secret"
  fi

  echo "-----game-server-output-env-installed"
}

# When sourced, only define install_env_from_metadata.
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  return 0
fi

echo "-----game-server-output-pull-origin"

GAME_NAME=minecraft

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

echo "-----game-server-output-install-env"
install_env_from_metadata "$MODULE_DIR/minecraft.env" "$MODULE_DIR/cf-api-key.secret"

echo "-----game-server-output-minecraft-data-perms"
mkdir -p "$MODULE_DIR/data"
docker run --rm \
  -v "$MODULE_DIR/data:/mdata" \
  alpine:3.19 \
  sh -c 'chown -R 1000:1000 /mdata'

echo "-----game-server-output-docker-compose"
docker compose --file "$COMPOSE_FILE" up -d
