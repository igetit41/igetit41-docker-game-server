#!/bin/bash
GITPATH=/home/d3f1l3/igetit41-docker-game-server

git -C $GITPATH reset --hard
git -C $GITPATH pull origin main
chmod +x $GITPATH/game_server/game_server.sh
cp $GITPATH/game_server/game_server.service /etc/systemd/system/game_server.service

docker compose --file $GITPATH/game_server/compose.yaml up -d
