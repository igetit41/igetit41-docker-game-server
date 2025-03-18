#!/bin/bash

GITPATH=/home/game-server/igetit41-docker-game-server

CONTAINER=game-server

# Changes Section - Unique to Each Game
#export SERVER_PORT=15636 # Enshrouded
#export SERVER_PORT=25565 # Minecraft
SERVER_PORT=16261 # Project Zomboid

# Define interval between checks for player activity (in seconds)
CHECK_INTERVAL=60

# Max Idle Intervals
IDLE_COUNT=15

# Count Idle Intervals
COUNT=0

if [ -d $GITPATH ]; then
    cd /home/game-server

    sudo -H -u pre-network-packet-capture bash -c 'git -C $GITPATH reset --hard'
    sudo -H -u pre-network-packet-capture bash -c 'git -C $GITPATH pull origin main'

    sudo chmod +x $GITPATH/game-server/game-server.sh
    sudo cp $GITPATH/game-server/game-server.service /etc/systemd/system/game-server.service

    sudo systemctl daemon-reload
    sudo systemctl restart game-server
else
    sudo apt update -y
    sudo apt install net-tools

    #sudo deluser conntrack-exporter
    useradd -m --shell /sbin/nologin game-server
    passwd -d game-server
    usermod -a -G sudo game-server
    cd /home/game-server

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
    sudo usermod -a -G docker game-server
    newgrp docker

    # Clone Repo
    sudo -H -u pre-network-packet-capture bash -c 'git clone https://github.com/igetit41/igetit41-docker-game-server'
    sudo git config --global --add safe.directory $GITPATH

    sudo chmod +x $GITPATH/game-server/game-server.sh
    sudo cp $GITPATH/game-server/game-server.service /etc/systemd/system/game-server.service

    sudo systemctl daemon-reload
    sudo systemctl enable game-server
    sudo systemctl restart game-server
fi

# Main loop
while true; do
    # Check the number of established connections on the server port
    PID=$(sudo docker inspect -f '{{.State.Pid}}' $CONTAINER)
    CONNECTIONS=$(sudo nsenter -t $PID -n netstat | grep -w $SERVER_PORT | grep ESTABLISHED | wc -l)
    STAMP=$(date +'%Y-%m-%d:%H.%M:%S')
    echo "STARTUPLOG-$STAMP-CONNECTIONS: $CONNECTIONS"

    if [ $CONNECTIONS -gt 0 ]; then
        COUNT=0
    else
        COUNT=$(expr $COUNT + 1)
    fi
    echo "STARTUPLOG-$STAMP-COUNT: $COUNT"
    
    if [ $COUNT -gt $IDLE_COUNT ]; then
        echo "STARTUPLOG-$STAMP------------Shutting down"
        sudo docker compose --file $GITPATH/game-server/compose.yaml down
        sudo poweroff
        break
    fi

    sleep $CHECK_INTERVAL
done
