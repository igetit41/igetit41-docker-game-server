#!/bin/bash
GITPATH=$(pwd)/igetit41-docker-game-server

git -C $GITPATH reset --hard
git -C $GITPATH pull origin main
chmod +x $GITPATH/game-server/game-server.sh
cp $GITPATH/game-server/game-server.service /etc/systemd/system/game-server.service

docker compose --file $GITPATH/game-server/compose.yaml up -d
