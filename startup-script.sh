#!/bin/bash
echo "-----startup-script-output-begin"

# Troubleshooting
#tail -100  /var/log/syslog | grep game-server
#sudo docker logs game-server
#
#sudo docker compose --file /home/game-server/igetit41-docker-game-server/game-server/compose.yaml up -d
#sudo docker compose --file /home/game-server/igetit41-docker-game-server/game-server/compose.yaml ps
#sudo docker compose --file /home/game-server/igetit41-docker-game-server/game-server/compose.yaml down

# Define interval between checks for player activity (in seconds)
CHECK_INTERVAL=60

# Max Idle Intervals
IDLE_COUNT=15

# Count Idle Intervals
COUNT=0

RESTART_COUNT=0

FIRST_RUN=false

RCON_PW=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_PW" -H "Metadata-Flavor: Google")
RCON_PORT=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_PORT" -H "Metadata-Flavor: Google")
RCON_PW_VAR=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_PW_VAR" -H "Metadata-Flavor: Google")
RCON_PW_VAR_LINE1=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_PW_VAR_LINE1" -H "Metadata-Flavor: Google")
RCON_PW_VAR_LINE2=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_PW_VAR_LINE2" -H "Metadata-Flavor: Google")
RCON_PW_FILE=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_PW_FILE" -H "Metadata-Flavor: Google")
RCON_PW_FILE_PATH=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_PW_FILE_PATH" -H "Metadata-Flavor: Google")
RCON_PLAYER_CHECK=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_PLAYER_CHECK" -H "Metadata-Flavor: Google")
RCON_PLAYER_CHECK_GREP=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_PLAYER_CHECK_GREP" -H "Metadata-Flavor: Google")
RCON_LIVE_TEST=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_LIVE_TEST" -H "Metadata-Flavor: Google")
RCON_LIVE_TEST_GREP=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_LIVE_TEST_GREP" -H "Metadata-Flavor: Google")
RCON_COMMANDS=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_COMMANDS" -H "Metadata-Flavor: Google")
EXEC_COMMANDS=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/EXEC_COMMANDS" -H "Metadata-Flavor: Google")
RCON_RELOAD=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_RELOAD" -H "Metadata-Flavor: Google")
SERVER_RESTART_COUNT=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/SERVER_RESTART_COUNT" -H "Metadata-Flavor: Google")

if [ ! -d /home/game-server/igetit41-docker-game-server ]; then
    echo "-----startup-script-output-first-run"
    FIRST_RUN=true
    RESTART_COUNT=$SERVER_RESTART_COUNT
    echo "-----startup-script-output-RESTART_COUNT-$RESTART_COUNT"

    echo "-----startup-script-output-RCON_PW: $RCON_PW"
    echo "-----startup-script-output-RCON_PLAYER_CHECK: $RCON_PLAYER_CHECK"
    echo "-----startup-script-output-RCON_LIVE_TEST: $RCON_LIVE_TEST"
    echo "-----startup-script-output-RCON_COMMANDS: $RCON_COMMANDS"
    echo "-----startup-script-output-EXEC_COMMANDS: $EXEC_COMMANDS"
    echo "-----startup-script-output-RCON_RELOAD: $RCON_RELOAD"

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
fi

RCON_CHECK=$(echo "$(sudo docker exec -i game-server ls)" | grep -E rcon)
echo "-----startup-script-output-RCON_CHECK-$RCON_CHECK"

LOOP_VAR=0
while [[ "$RCON_CHECK" == "" ]]; do
    LOOP_VAR="$(($LOOP_VAR + 1))"
    echo "-----startup-script-output-LOOP_VAR-$LOOP_VAR"
    echo "-----startup-script-output-waiting-for-server"
    SERVER_CHECK1=$(echo "$(sudo docker ps)" | grep -E game-server)
    echo "-----startup-script-output-SERVER_CHECK1-$SERVER_CHECK1"
    SERVER_CHECK2=$(sudo docker exec -i game-server pwd)
    echo "-----startup-script-output-SERVER_CHECK2-$SERVER_CHECK2"
    
    if [[ "$SERVER_CHECK1" == *game-server* ]] && [[ "$SERVER_CHECK2" == /home* ]]; then
        echo "-----startup-script-output-installing-rcon"
        echo $(sudo docker exec -i game-server curl -c x -L --insecure --output rcon-0.10.3-amd64_linux.tar.gz "https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz")
        echo $(sudo docker exec -i game-server tar -xvzf rcon-0.10.3-amd64_linux.tar.gz)

    else
        echo "-----startup-script-output-sleep4-$CHECK_INTERVAL"
        sleep $CHECK_INTERVAL
    fi

    RCON_CHECK=$(echo "$(sudo docker exec -i game-server ls)" | grep -E rcon)
    echo "-----startup-script-output-RCON_CHECK-$RCON_CHECK"
done

RCON_FILE_CHECK=$(echo "$(sudo docker exec -i game-server ls $RCON_PW_FILE_PATH)" | grep -E $RCON_PW_FILE)
echo "-----startup-script-output-RCON_FILE_CHECK-$RCON_FILE_CHECK"

PASSWORD_CHECK=$(echo "$(sudo docker exec -i game-server cat $RCON_PW_FILE_PATH/$RCON_PW_FILE)" | grep -E $RCON_PW_VAR)
#PASSWORD_CHECK=$(sudo docker exec -i game-server cat $RCON_PW_FILE_PATH/$RCON_PW_FILE | grep $RCON_PW_VAR)
echo "-----startup-script-output-PASSWORD_CHECK-$PASSWORD_CHECK"

LOOP_VAR=0
while [[ "$RCON_FILE_CHECK" == "" ]] || [[ "$PASSWORD_CHECK" != *$RCON_PW* ]]; do
    LOOP_VAR="$(($LOOP_VAR + 1))"
    echo "-----startup-script-output-LOOP_VAR-$LOOP_VAR"

    if [[ "$RCON_FILE_CHECK" == *$RCON_PW_FILE* ]]; then
        echo "-----startup-script-output-set-rcon-password"

        REMOVE_EMPTY_PASSWORD=$(sudo docker exec -i game-server bash -c "sed -i \"s|$RCON_PW_VAR|$RCON_PW_VAR_LINE1$RCON_PW$RCON_PW_VAR_LINE2|g\" $RCON_PW_FILE_PATH/$RCON_PW_FILE")
        #REMOVE_EMPTY_PASSWORD=$(sudo docker exec -i game-server cat $RCON_PW_FILE_PATH/$RCON_PW_FILE | grep -v $RCON_PW_VAR > $RCON_PW_FILE_PATH/$RCON_PW_FILE)
        echo "-----startup-script-output-REMOVE_EMPTY_PASSWORD: $REMOVE_EMPTY_PASSWORD"

        #ADD_NEW_PASSWORD=$(sudo docker exec -i game-server bash -c "echo '$RCON_PW_VAR_LINE1$RCON_PW$RCON_PW_VAR_LINE2' >> $RCON_PW_FILE_PATH/$RCON_PW_FILE")
        #echo "-----startup-script-output-ADD_NEW_PASSWORD: $ADD_NEW_PASSWORD"
        #sudo docker exec -i game-server sed -i "s/$RCON_PW_VAR/$RCON_PW_VAR$RCON_PW/g" $RCON_PW_FILE_PATH/$RCON_PW_FILE
    else
        echo "-----startup-script-output-sleep4-$CHECK_INTERVAL"
        sleep $CHECK_INTERVAL
    fi
    
    RCON_FILE_CHECK=$(echo "$(sudo docker exec -i game-server ls $RCON_PW_FILE_PATH)" | grep -E $RCON_PW_FILE)
    echo "-----startup-script-output-RCON_FILE_CHECK-$RCON_FILE_CHECK"

    PASSWORD_CHECK=$(echo "$(sudo docker exec -i game-server cat $RCON_PW_FILE_PATH/$RCON_PW_FILE)" | grep -E $RCON_PW_VAR)
    #PASSWORD_CHECK=$(sudo docker exec -i game-server cat $RCON_PW_FILE_PATH/$RCON_PW_FILE | grep $RCON_PW_VAR)
    echo "-----startup-script-output-PASSWORD_CHECK-$PASSWORD_CHECK"
done

while [[ $RESTART_COUNT -gt "0" ]]; do
    echo "-----startup-script-output-game-server-restart"
    #RESTART_OUTPUT=$(sudo systemctl restart game-server)
    RESTART_OUTPUT=$(sudo docker restart game-server)

    RESTART_COUNT="$(($RESTART_COUNT - 1))"
    echo "-----startup-script-output-RESTART_COUNT-$RESTART_COUNT"
    echo "-----startup-script-output-RESTART_OUTPUT-$RESTART_OUTPUT"

    echo "-----startup-script-output-sleep2-$CHECK_INTERVAL"
    sleep $CHECK_INTERVAL
    
    GAMESERVER_RUNNING=$(echo "$(sudo docker exec -i game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:$RCON_PORT -p $RCON_PW "$RCON_LIVE_TEST")" | $RCON_LIVE_TEST_GREP)
    echo "-----startup-script-output-GAMESERVER_RUNNING-$GAMESERVER_RUNNING"
    
    LOOP_VAR=0
    while [[ "$GAMESERVER_RUNNING" == "" ]]; do
        LOOP_VAR="$(($LOOP_VAR + 1))"
        echo "-----startup-script-output-LOOP_VAR-$LOOP_VAR"

        echo "-----startup-script-output-sleep3-$CHECK_INTERVAL"
        sleep $CHECK_INTERVAL
    
        GAMESERVER_RUNNING=$(echo "$(sudo docker exec -i game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:$RCON_PORT -p $RCON_PW "$RCON_LIVE_TEST")" | $RCON_LIVE_TEST_GREP)
        echo "-----startup-script-output-GAMESERVER_RUNNING-$GAMESERVER_RUNNING"
    done
done

if [[ "$FIRST_RUN" != "true" ]]; then
    for COMMAND in $RCON_COMMANDS;
    do
        echo "-----startup-script-output-RCON_COMMANDS2: $COMMAND"
        sudo docker exec -i game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:$RCON_PORT -p $RCON_PW "$COMMAND"
    done
    
    for COMMAND in $EXEC_COMMANDS;
    do
        echo "-----startup-script-output-EXEC_COMMANDS2: $COMMAND"
        sudo docker exec -i game-server $COMMAND
    done
    
    for COMMAND in $RCON_RELOAD;
    do
        echo "-----startup-script-output-RCON_RELOAD2: $COMMAND"
        sudo docker exec -i game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:$RCON_PORT -p $RCON_PW "$COMMAND"
    done
fi
    
GAMESERVER_RUNNING=$(echo $(sudo docker exec -i game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:$RCON_PORT -p $RCON_PW "$RCON_LIVE_TEST") | $RCON_LIVE_TEST_GREP)
echo "-----startup-script-output-GAMESERVER_RUNNING-$GAMESERVER_RUNNING"

LOOP_VAR=0
while [[ "$GAMESERVER_RUNNING" == "" ]]; do
    LOOP_VAR="$(($LOOP_VAR + 1))"
    echo "-----startup-script-output-LOOP_VAR-$LOOP_VAR"

    echo "-----startup-script-output-sleep2-$CHECK_INTERVAL"
    sleep $CHECK_INTERVAL
    
    GAMESERVER_RUNNING=$(echo $(sudo docker exec -i game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:$RCON_PORT -p $RCON_PW "$RCON_LIVE_TEST") | $RCON_LIVE_TEST_GREP)
    echo "-----startup-script-output-GAMESERVER_RUNNING-$GAMESERVER_RUNNING"
done

# Main loop
while true; do
    echo "-----startup-script-output-player-check"
    #PLAYERS=$(sudo /home/game-server/igetit41-docker-game-server/player-check.sh)
    PLAYERS=$(echo $(sudo docker exec -i game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:$RCON_PORT -p $RCON_PW "$RCON_PLAYER_CHECK") | $RCON_PLAYER_CHECK_GREP)
    #PLAYERS=$(sudo docker exec -i game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:$RCON_PORT -p $RCON_PW $RCON_PLAYER_CHECK)
    STAMP=$(date +'%Y-%m-%d:%H.%M:%S')
    echo "-----startup-script-output-$STAMP-PLAYERS: $PLAYERS"
    
    if ! [[ $PLAYERS =~ ^[0-9]+$ ]]; then
        PLAYERS=0
    fi

    if [[ $PLAYERS -gt "0" ]]; then
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

    echo "-----startup-script-output-sleep3-$CHECK_INTERVAL"
    sleep $CHECK_INTERVAL
done
