#!/bin/bash
# Project Zomboid
PLAYERS=$(sudo docker exec -it game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:27015 -p $RCON_PW players | grep -Eo '[0-9]+' | head -1)
echo $PLAYERS
