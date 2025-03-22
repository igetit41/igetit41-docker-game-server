#!/bin/bash
echo "-----startup-script-output-begin"

# Troubleshooting
#tail -100  /var/log/syslog | grep game-server
#sudo docker logs game-server
#
#sudo docker compose --file /home/game-server/igetit41-docker-game-server/game-server/compose.yaml up -d
#sudo docker compose --file /home/game-server/igetit41-docker-game-server/game-server/compose.yaml ps
#sudo docker compose --file /home/game-server/igetit41-docker-game-server/game-server/compose.yaml down


echo "-----startup-script-output-get-RCON_PW"
export RCON_PW=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_PW" -H "Metadata-Flavor: Google")
echo $RCON_PW

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

if [ -d /home/game-server/igetit41-docker-game-server ]; then
    echo "-----startup-script-output-pull-origin"
    cd /home/game-server

    sudo -H -u game-server bash -c 'git -C /home/game-server/igetit41-docker-game-server reset --hard'
    sudo -H -u game-server bash -c 'git -C /home/game-server/igetit41-docker-game-server pull origin main'

    sudo chmod +x /home/game-server/igetit41-docker-game-server/game-server/*.sh
    sudo chmod +x /home/game-server/igetit41-docker-game-server/*.sh
    sudo cp /home/game-server/igetit41-docker-game-server/game-server/game-server.service /etc/systemd/system/game-server.service

    echo "-----startup-script-output-start-server"
    sudo systemctl daemon-reload
    sudo systemctl restart game-server

    until [ "`sudo docker inspect -f {{.State.Running}} game-server`"=="true" ]; do
        sleep 0.1;
    done;
    
    sudo /home/game-server/igetit41-docker-game-server/rcon-startup.sh

    # Main loop
    while true; do
        PLAYERS=$(sudo /home/game-server/igetit41-docker-game-server/player-check.sh)
        STAMP=$(date +'%Y-%m-%d:%H.%M:%S')
        echo "-----startup-script-output-$STAMP-PLAYERS: $PLAYERS"

        if [ $PLAYERS -gt 0 ]; then
            COUNT=0
        else
            COUNT=$(expr $COUNT + 1)
        fi
        echo "-----startup-script-output-$STAMP-COUNT: $COUNT"
        
        if [ $COUNT -gt $IDLE_COUNT ]; then
            echo "-----startup-script-output-$STAMP-shutting-down"
            sudo docker compose --file /home/game-server/igetit41-docker-game-server/game-server/compose.yaml down
            sudo poweroff
            break
        fi

        sleep $CHECK_INTERVAL
    done
else
    echo "-----startup-script-output-first-run"

    sudo apt update -y
    sudo apt install net-tools

    echo "-----startup-script-output-add-user"
    #sudo deluser conntrack-exporter
    useradd -m --shell /sbin/nologin game-server
    passwd -d game-server
    usermod -a -G sudo game-server
    cd /home/game-server

    #Install Docker
    echo "-----startup-script-output-install-docker"
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
    echo "-----startup-script-output-clone-repo"
    sudo -H -u game-server bash -c 'git clone https://github.com/igetit41/igetit41-docker-game-server'
    sudo git config --global --add safe.directory /home/game-server/igetit41-docker-game-server

    sudo chmod +x /home/game-server/igetit41-docker-game-server/game-server/*.sh
    sudo chmod +x /home/game-server/igetit41-docker-game-server/*.sh
    sudo cp /home/game-server/igetit41-docker-game-server/game-server/game-server.service /etc/systemd/system/game-server.service

    echo "-----startup-script-output-start-server"
    sudo systemctl daemon-reload
    sudo systemctl enable game-server
    sudo systemctl restart game-server

    WAITING_FOR_CONTAINER=true

    while $WAITING_FOR_CONTAINER; do
        echo "-----startup-script-output-waiting-for-server"
        sleep 1;
        SERVER_CHECK1=$(sudo docker ps | grep game-server)
        if [[ $SERVER_CHECK1 == *"game-server"* ]]; then
            SERVER_CHECK2=$(sudo docker exec -it game-server pwd)
            if [[ $SERVER_CHECK2 == *"/home"* ]]; then
                echo "-----startup-script-output-done-waiting"
                WAITING_FOR_CONTAINER=false

                echo "-----startup-script-output-dockering-1"
                sudo docker exec -it game-server ls

                echo "-----startup-script-output-dockering-2"
                echo $(sudo docker exec -it game-server ls)

                echo "-----startup-script-output-dockering-3"
                sudo docker exec -it game-server mkdir testdir1

                echo "-----startup-script-output-dockering-4"
                echo $(sudo docker exec -it game-server mkdir testdir2)

                echo "-----startup-script-output-dockering-5"
                DOCKER_OP=$(sudo docker exec -it game-server mkdir testdir3)
                echo $DOCKER_OP


                echo "-----startup-script-output-dockering-6"
                echo $(sudo docker exec -it game-server curl -c x -L --insecure --output rcon-0.10.3-amd64_linux.tar.gz "https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz")

                echo "-----startup-script-output-dockering-7"
                echo $(sudo docker exec -it game-server tar -xvzf rcon-0.10.3-amd64_linux.tar.gz)
            fi
        fi
    done
    
    while true; do
        echo "-----startup-script-output-script-finished"
        sleep $CHECK_INTERVAL
    done
fi
