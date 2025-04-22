#!/bin/bash
echo "-----game-server-output-pull-origin"

GAME_NAME=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/GAME_NAME" -H "Metadata-Flavor: Google")

git -C /home/game-server/igetit41-docker-game-server reset --hard
git -C /home/game-server/igetit41-docker-game-server pull origin main

chmod +x /home/game-server/igetit41-docker-game-server/game-server/*.sh
chmod +x /home/game-server/igetit41-docker-game-server/*.sh
sudo cp /home/game-server/igetit41-docker-game-server/game-server/game-server.service /etc/systemd/system/game-server.service

echo "-----game-server-output-docker-compose"
docker compose --file /home/game-server/igetit41-docker-game-server/game-server/$GAME_NAME/compose.yaml up -d
