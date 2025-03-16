#!/bin/bash
echo 'export GITPATH=/home/d3f1l3/igetit41-docker-game-server' >> ~/.bashrc
echo 'export CONTAINER=game_server' >> ~/.bashrc


# Changes Section - Unique to Each Game
#echo 'export SERVER_PORT=15636' >> ~/.bashrc # Enshrouded
echo 'export SERVER_PORT=16261' >> ~/.bashrc # Project Zomboid

sudo apt update -y
sudo apt install net-tools

#Install Docker
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

sudo service docker start
sudo usermod -a -G docker $USER
newgrp docker


# Clone Repo
cd ~
git clone https://github.com/igetit41/igetit41-docker-game-server
sudo git config --global --add safe.directory $GITPATH
#git -C ~/igetit41-docker-game-server reset --hard
#git -C ~/igetit41-docker-game-server pull origin main

sudo chmod +x ~/igetit41-docker-game-server/game_server/game_server.sh

sudo cp ~/igetit41-docker-game-server/game_server/game_server.service /etc/systemd/system/game_server.service

sudo systemctl daemon-reload
sudo systemctl enable game_server
sudo systemctl restart game_server

tail -100  /var/log/syslog | grep game_server
sudo docker logs game_server

sudo docker compose --file $GITPATH/game_server/compose.yaml up -d
sudo docker compose --file $GITPATH/game_server/compose.yaml ps


sudo docker compose --file $GITPATH/game_server/compose.yaml down
sudo poweroff
