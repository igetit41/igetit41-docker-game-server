#!/bin/bash

sudo git config --global --add safe.directory '*'

sudo git -C $GITPATH reset --hard
sudo git -C $GITPATH pull origin main

sudo chmod +x $GITPATH/game_server/game_server.sh

sudo cp $GITPATH/game_server/game_server.service /etc/systemd/system/game_server.service

sudo systemctl daemon-reload
sudo systemctl restart game_server

# Define interval between checks for player activity (in seconds)
CHECK_INTERVAL=60

# Max Idle Intervals
IDLE_COUNT=15

# Count Idle Intervals
COUNT=0

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
        sudo docker compose --file $GITPATH/game_server/compose.yaml down
        sudo poweroff
        break
    fi

    sleep $CHECK_INTERVAL
done
