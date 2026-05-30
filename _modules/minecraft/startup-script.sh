#!/bin/bash
echo "-----startup-script-output-begin"

# Minecraft Java Edition (CurseForge) — idle shutdown via RCON list on port 25575.

CHECK_INTERVAL=60
IDLE_COUNT=15
COUNT=0
RESTART_COUNT=0
FIRST_RUN=false

GAME_NAME=minecraft
RCON_PORT=25575
RCON_OTHER_ARGS=""
RCON_PW_FILE=server.properties
RCON_PW_FILE_PATH=.
RCON_PW_VAR=rcon.password
RCON_PLAYER_CHECK=list
RCON_PLAYER_CHECK_GREP="grep -oE 'There are [0-9]+' | grep -oE '[0-9]+'"
RCON_LIVE_TEST=list
RCON_LIVE_TEST_GREP="grep -E 'players online|There are'"
RCON_COMMANDS=""
RCON_RELOAD=""
SERVER_RESTART_COUNT=0

RCON_PW=$(curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_PW" -H "Metadata-Flavor: Google")
SERVER_PASSWORD=$(curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/SERVER_PASSWORD" -H "Metadata-Flavor: Google")
RCON_PW_VAR_LINE="rcon.password=${RCON_PW}"
EXEC_COMMANDS="sed -i 's|^server-password=.*|server-password=${SERVER_PASSWORD}|g' ./server.properties"

install_minecraft_env_from_metadata() {
  local dest="$1"
  local script_dir
  script_dir="$(dirname "$dest")"
  if [ -x "$script_dir/install-minecraft-env.sh" ]; then
    bash "$script_dir/install-minecraft-env.sh" "$dest"
  else
    echo "-----startup-script-output-ERROR: install-minecraft-env.sh missing in $script_dir"
    exit 1
  fi
}

STANDARD_REPO=/home/game-server/igetit41-docker-game-server
FLAT_REPO=/home/game-server
if [ -f "$STANDARD_REPO/_modules/minecraft/compose.yaml" ]; then
  REPO_ROOT=$STANDARD_REPO
elif [ -f "$FLAT_REPO/_modules/minecraft/compose.yaml" ]; then
  REPO_ROOT=$FLAT_REPO
else
  REPO_ROOT=$STANDARD_REPO
fi

MODULE_DIR="$REPO_ROOT/_modules/$GAME_NAME"
COMPOSE_FILE="$MODULE_DIR/compose.yaml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "-----startup-script-output-first-run"
    FIRST_RUN=true
    RESTART_COUNT=$SERVER_RESTART_COUNT
    echo "-----startup-script-output-RESTART_COUNT-$RESTART_COUNT"

    sudo apt update -y
    sudo apt install -y net-tools jq

    echo "-----startup-script-output-add-user"
    useradd -m --shell /sbin/nologin game-server
    passwd -d game-server
    usermod -a -G sudo game-server
    cd /home/game-server

    echo "-----startup-script-output-install-docker"
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo service docker start
    sudo usermod -a -G docker game-server
    newgrp docker

    echo "-----startup-script-output-clone-repo"
    sudo -H -u game-server bash -c 'git clone https://github.com/igetit41/igetit41-docker-game-server'
    sudo git config --global --add safe.directory "$REPO_ROOT"

    sudo chmod +x "$REPO_ROOT/_modules"/*.sh 2>/dev/null || true
    sudo chmod +x "$MODULE_DIR"/*.sh 2>/dev/null || true
    sudo chmod +x "$REPO_ROOT"/*.sh 2>/dev/null || true
    sudo cp "$REPO_ROOT/_modules/game-server.service" /etc/systemd/system/game-server.service

    MODULE_DIR="$REPO_ROOT/_modules/$GAME_NAME"
    install_minecraft_env_from_metadata "$MODULE_DIR/minecraft.env"

    echo "-----startup-script-output-start-server"
    sudo systemctl daemon-reload
    sudo systemctl enable game-server
    sudo systemctl restart game-server
fi

if [ -f "$STANDARD_REPO/_modules/$GAME_NAME/compose.yaml" ]; then
  REPO_ROOT=$STANDARD_REPO
elif [ -f "$FLAT_REPO/_modules/$GAME_NAME/compose.yaml" ]; then
  REPO_ROOT=$FLAT_REPO
fi
MODULE_DIR="$REPO_ROOT/_modules/$GAME_NAME"
COMPOSE_FILE="$MODULE_DIR/compose.yaml"

if [ -f "$COMPOSE_FILE" ] && [ ! -f /etc/systemd/system/game-server.service ]; then
    echo "-----startup-script-output-install-systemd-missed-first-run"
    sudo chmod +x "$REPO_ROOT/_modules"/*.sh 2>/dev/null || true
    sudo chmod +x "$MODULE_DIR"/*.sh 2>/dev/null || true
    sudo chmod +x "$REPO_ROOT"/*.sh 2>/dev/null || true
    sudo git config --global --add safe.directory "$REPO_ROOT" 2>/dev/null || true
    sudo cp "$REPO_ROOT/_modules/game-server.service" /etc/systemd/system/game-server.service
    install_minecraft_env_from_metadata "$MODULE_DIR/minecraft.env"
    sudo systemctl daemon-reload
    sudo systemctl enable game-server
    sudo systemctl restart game-server
fi

RCON_CHECK=$(echo "$(sudo docker exec -i game-server ls 2>/dev/null)" | grep -E rcon)
echo "-----startup-script-output-RCON_CHECK-$RCON_CHECK"

LOOP_VAR=0
while [[ "$RCON_CHECK" == "" ]]; do
    LOOP_VAR="$(($LOOP_VAR + 1))"
    echo "-----startup-script-output-LOOP_VAR-$LOOP_VAR"
    echo "-----startup-script-output-waiting-for-server"
    SERVER_CHECK1=$(echo "$(sudo docker ps)" | grep -E game-server)
    echo "-----startup-script-output-SERVER_CHECK1-$SERVER_CHECK1"
    SERVER_CHECK2=$(sudo docker exec -i game-server pwd 2>/dev/null)
    echo "-----startup-script-output-SERVER_CHECK2-$SERVER_CHECK2"

    if [[ "$SERVER_CHECK1" == *game-server* ]] && [[ "$SERVER_CHECK2" == /data ]]; then
        echo "-----startup-script-output-installing-rcon"
        echo $(sudo docker exec -i game-server curl -c x -L --insecure --output rcon-0.10.3-amd64_linux.tar.gz "https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz")
        echo $(sudo docker exec -i game-server tar -xvzf rcon-0.10.3-amd64_linux.tar.gz)
    else
        echo "-----startup-script-output-sleep4-$CHECK_INTERVAL"
        sleep $CHECK_INTERVAL
    fi

    RCON_CHECK=$(echo "$(sudo docker exec -i game-server ls 2>/dev/null)" | grep -E rcon)
    echo "-----startup-script-output-RCON_CHECK-$RCON_CHECK"
done

RCON_FILE_CHECK=$(echo "$(sudo docker exec -i game-server ls $RCON_PW_FILE_PATH 2>/dev/null)" | grep -E $RCON_PW_FILE)
echo "-----startup-script-output-RCON_FILE_CHECK-$RCON_FILE_CHECK"

PASSWORD_CHECK=$(echo "$(sudo docker exec -i game-server cat $RCON_PW_FILE_PATH/$RCON_PW_FILE 2>/dev/null)" | grep -E $RCON_PW_VAR)
echo "-----startup-script-output-PASSWORD_CHECK-$PASSWORD_CHECK"

LOOP_VAR=0
while [[ "$RCON_FILE_CHECK" == "" ]] || [[ "$PASSWORD_CHECK" != *$RCON_PW* ]]; do
    LOOP_VAR="$(($LOOP_VAR + 1))"
    echo "-----startup-script-output-LOOP_VAR-$LOOP_VAR"

    if [[ "$RCON_FILE_CHECK" == *$RCON_PW_FILE* ]]; then
        echo "-----startup-script-output-set-rcon-password"
        UPDATE_PASSWORD=$(sudo docker exec -i game-server bash -c "sed -i 's|^.*$RCON_PW_VAR.*|$RCON_PW_VAR_LINE|g' $RCON_PW_FILE_PATH/$RCON_PW_FILE")
        echo "-----startup-script-output-UPDATE_PASSWORD: $UPDATE_PASSWORD"
    else
        echo "-----startup-script-output-sleep4-$CHECK_INTERVAL"
        sleep $CHECK_INTERVAL
    fi

    RCON_FILE_CHECK=$(echo "$(sudo docker exec -i game-server ls $RCON_PW_FILE_PATH 2>/dev/null)" | grep -E $RCON_PW_FILE)
    echo "-----startup-script-output-RCON_FILE_CHECK-$RCON_FILE_CHECK"
    PASSWORD_CHECK=$(echo "$(sudo docker exec -i game-server cat $RCON_PW_FILE_PATH/$RCON_PW_FILE 2>/dev/null)" | grep -E $RCON_PW_VAR)
    echo "-----startup-script-output-PASSWORD_CHECK-$PASSWORD_CHECK"
done

while [[ $RESTART_COUNT -gt "0" ]]; do
    echo "-----startup-script-output-game-server-restart"
    RESTART_OUTPUT=$(sudo docker restart game-server)
    RESTART_COUNT="$(($RESTART_COUNT - 1))"
    echo "-----startup-script-output-RESTART_COUNT-$RESTART_COUNT"
    echo "-----startup-script-output-RESTART_OUTPUT-$RESTART_OUTPUT"
    sleep $CHECK_INTERVAL

    GAMESERVER_RUNNING=$(echo "$(sudo docker exec -i game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:$RCON_PORT -p $RCON_PW $RCON_OTHER_ARGS "$RCON_LIVE_TEST")" | bash -c "$RCON_LIVE_TEST_GREP")
    echo "-----startup-script-output-GAMESERVER_RUNNING-$GAMESERVER_RUNNING"

    LOOP_VAR=0
    while [[ "$GAMESERVER_RUNNING" == "" ]]; do
        LOOP_VAR="$(($LOOP_VAR + 1))"
        echo "-----startup-script-output-LOOP_VAR-$LOOP_VAR"
        sleep $CHECK_INTERVAL
        GAMESERVER_RUNNING=$(echo "$(sudo docker exec -i game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:$RCON_PORT -p $RCON_PW $RCON_OTHER_ARGS "$RCON_LIVE_TEST")" | bash -c "$RCON_LIVE_TEST_GREP")
        echo "-----startup-script-output-GAMESERVER_RUNNING-$GAMESERVER_RUNNING"
    done
done

GAMESERVER_RUNNING=$(echo $(sudo docker exec -i game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:$RCON_PORT -p $RCON_PW $RCON_OTHER_ARGS "$RCON_LIVE_TEST") | bash -c "$RCON_LIVE_TEST_GREP")
echo "-----startup-script-output-GAMESERVER_RUNNING-$GAMESERVER_RUNNING"

LOOP_VAR=0
while [[ "$GAMESERVER_RUNNING" == "" ]]; do
    LOOP_VAR="$(($LOOP_VAR + 1))"
    echo "-----startup-script-output-LOOP_VAR-$LOOP_VAR"
    sleep $CHECK_INTERVAL
    GAMESERVER_RUNNING=$(echo $(sudo docker exec -i game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:$RCON_PORT -p $RCON_PW $RCON_OTHER_ARGS "$RCON_LIVE_TEST") | bash -c "$RCON_LIVE_TEST_GREP")
    echo "-----startup-script-output-GAMESERVER_RUNNING-$GAMESERVER_RUNNING"
done

if [[ -n "$EXEC_COMMANDS" ]]; then
    echo "-----startup-script-output-exec-commands-begin"
    IFS_OLD=$IFS
    IFS=';' read -ra EXEC_CMDS <<< "$EXEC_COMMANDS"
    for EXEC_ONE in "${EXEC_CMDS[@]}"; do
        [[ -z "$EXEC_ONE" ]] && continue
        echo "-----startup-script-output-EXEC_COMMAND: $EXEC_ONE"
        EXEC_COMMAND_OUTPUT=$(sudo docker exec -i game-server bash -c "$EXEC_ONE" 2>&1)
        EXEC_COMMAND_EC=$?
        echo "-----startup-script-output-EXEC_COMMAND_EXIT: $EXEC_COMMAND_EC"
        echo "-----startup-script-output-EXEC_COMMAND_OUTPUT: $EXEC_COMMAND_OUTPUT"
    done
    IFS=$IFS_OLD
    echo "-----startup-script-output-exec-commands-end"
fi

while true; do
    PLAYERS1=$(sudo docker exec -i game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:$RCON_PORT -p $RCON_PW $RCON_OTHER_ARGS "$RCON_PLAYER_CHECK")
    PLAYERS2=$(echo "$PLAYERS1" | bash -c "$RCON_PLAYER_CHECK_GREP")
    if [[ -z "$PLAYERS2" ]]; then
        PLAYERS2=$(echo "$PLAYERS1" | grep -oE '[0-9]+' | head -n1)
    fi
    PLAYERS=$(echo "$PLAYERS2" | tr -cd '[:digit:]')
    echo "-----startup-script-output-player-check rcon=\"$(echo "$PLAYERS1" | tr '\n\r' ' ')\" filtered=\"$PLAYERS2\""
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
        sudo docker compose --file "$COMPOSE_FILE" down
        sudo poweroff
        break
    fi

    RCON_CHECK=$(echo "$(sudo docker exec -i game-server ls 2>/dev/null)" | grep -E rcon)
    if [[ "$RCON_CHECK" == "" ]]; then
        echo "-----startup-script-output-installing-rcon"
        echo $(sudo docker exec -i game-server curl -c x -L --insecure --output rcon-0.10.3-amd64_linux.tar.gz "https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz")
        echo $(sudo docker exec -i game-server tar -xvzf rcon-0.10.3-amd64_linux.tar.gz)
    fi

    echo "-----startup-script-output-sleep3-$CHECK_INTERVAL"
    sleep $CHECK_INTERVAL
done
