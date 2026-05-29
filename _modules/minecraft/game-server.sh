#!/bin/bash
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

echo "-----game-server-output-minecraft-data-perms"
if [ ! -f "$MODULE_DIR/minecraft.env" ]; then
  echo "ERROR: $MODULE_DIR/minecraft.env missing. Copy minecraft.env.example and set CF_API_KEY."
  exit 1
fi
mkdir -p "$MODULE_DIR/data"
docker run --rm \
  -v "$MODULE_DIR/data:/mdata" \
  alpine:3.19 \
  sh -c 'chown -R 1000:1000 /mdata'

echo "-----game-server-output-docker-compose"
docker compose --file "$COMPOSE_FILE" up -d
