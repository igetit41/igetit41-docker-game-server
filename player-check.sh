#!/bin/bash
# Project Zomboid
RCON_PW=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_PW" -H "Metadata-Flavor: Google")

PLAYERS=$(sudo docker exec -i game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:27015 -p $RCON_PW players | grep -Eo '[0-9]+' | head -1)
echo $PLAYERS
