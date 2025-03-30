#!/bin/bash
echo "-----game-server-output-pull-origin"
#sudo -H -u game-server bash -c 'git -C /home/game-server/igetit41-docker-game-server reset --hard'
#sudo -H -u game-server bash -c 'git -C /home/game-server/igetit41-docker-game-server pull origin main'
#
#sudo chmod +x /home/game-server/igetit41-docker-game-server/game-server/*.sh
#sudo chmod +x /home/game-server/igetit41-docker-game-server/*.sh
#sudo cp /home/game-server/igetit41-docker-game-server/game-server/game-server.service /etc/systemd/system/game-server.service

git -C /home/game-server/igetit41-docker-game-server reset --hard
git -C /home/game-server/igetit41-docker-game-server pull origin main

chmod +x /home/game-server/igetit41-docker-game-server/game-server/*.sh
chmod +x /home/game-server/igetit41-docker-game-server/*.sh
sudo cp /home/game-server/igetit41-docker-game-server/game-server/game-server.service /etc/systemd/system/game-server.service

echo "-----game-server-output-docker-compose"
docker compose --file /home/game-server/igetit41-docker-game-server/game-server/compose.yaml up -d
