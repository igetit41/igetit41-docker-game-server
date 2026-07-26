#!/bin/bash

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

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  return 0
fi

echo "-----game-server-output-pull-origin"

GAME_NAME=smalland

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
chmod +x "$MODULE_DIR/start-server.sh" 2>/dev/null || true
chmod +x "$REPO_ROOT"/*.sh 2>/dev/null || true
sudo cp "$REPO_ROOT/_modules/game-server.service" /etc/systemd/system/game-server.service
sudo systemctl daemon-reload

echo "-----game-server-output-install-env"
install_env_from_metadata "$MODULE_DIR/smalland.env"

SERVER_PASSWORD=$(curl -sf \
  "http://metadata.google.internal/computeMetadata/v1/instance/attributes/SERVER_PASSWORD" \
  -H "Metadata-Flavor: Google" || true)
if [ -n "$SERVER_PASSWORD" ]; then
  upsert_env_var "$MODULE_DIR/smalland.env" "PASSWORD" "$SERVER_PASSWORD"
  echo "-----game-server-output-password-from-metadata"
fi

echo "-----game-server-output-smalland-data-perms"
mkdir -p "$MODULE_DIR/data" "$MODULE_DIR/server-files"
# cm2network/steamcmd steam user is UID/GID 1000
docker run --rm \
  -v "$MODULE_DIR/data:/sdata" \
  -v "$MODULE_DIR/server-files:/sfiles" \
  alpine:3.19 \
  sh -c "chown -R 1000:1000 /sdata /sfiles"

echo "-----game-server-output-docker-compose-build"
docker compose --file "$COMPOSE_FILE" build

echo "-----game-server-output-docker-compose"
docker compose --file "$COMPOSE_FILE" up -d
echo "-----game-server-output-compose-up-ok"
