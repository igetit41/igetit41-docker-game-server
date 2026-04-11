#!/bin/bash
echo "-----game-server-output-pull-origin"

GAME_NAME=$(curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/GAME_NAME" -H "Metadata-Flavor: Google")
GAME_NAME=${GAME_NAME:-zomboid}

STANDARD_REPO=/home/game-server/igetit41-docker-game-server
FLAT_REPO=/home/game-server
if [ -f "$STANDARD_REPO/_modules/$GAME_NAME/compose.yaml" ]; then
  REPO_ROOT=$STANDARD_REPO
elif [ -f "$FLAT_REPO/_modules/$GAME_NAME/compose.yaml" ]; then
  REPO_ROOT=$FLAT_REPO
else
  REPO_ROOT=$STANDARD_REPO
fi

COMPOSE_FILE="$REPO_ROOT/_modules/$GAME_NAME/compose.yaml"

git -C "$REPO_ROOT" reset --hard
git -C "$REPO_ROOT" pull origin main

chmod +x "$REPO_ROOT/_modules"/*.sh 2>/dev/null || true
chmod +x "$REPO_ROOT"/*.sh 2>/dev/null || true
sudo cp "$REPO_ROOT/_modules/game-server.service" /etc/systemd/system/game-server.service

echo "-----game-server-output-docker-compose"
docker compose --file "$COMPOSE_FILE" up -d
