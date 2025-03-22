#!/bin/bash
# Project Zomboid
sudo docker exec -it game-server ./rcon-0.10.3-amd64_linux/rcon -a 127.0.0.1:27015 -p $RCON_PW setaccesslevel D3F1L3 admin
