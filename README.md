# igetit41-docker-game-server

Change the ```# Changes Section``` to match each game. Rename compose file to swap game.

For the Steam Workshop list subscribe to the mods you want, put them into a collection, get that collection using the method here: https://steamcommunity.com/sharedfiles/filedetails

Remember to open the required ports in your firewall.

env vars before terraform apply:

export TF_VAR_PROJECT_ID=<your project id>
export TF_VAR_PROJECT_NUM=<your project number>
export TF_VAR_REGION=<your region>
export TF_VAR_MACHINE_TYPE=<server machine type>
export TF_VAR_SERVER_PASSWORD=<server password>
export TF_VAR_RCON_PASSWORD=<rcon password>



https://github.com/gorcon/rcon-cli

https://github.com/Danixu/project-zomboid-server-docker
https://pzwiki.net/wiki/Admin_commands

https://github.com/vinanrra/Docker-7DaysToDie
https://7daystodie.fandom.com/wiki/Command_Console

