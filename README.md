# igetit41-docker-game-server

Change the ```# Changes Section``` to match each game. Rename compose file to swap game.

For the Steam Workshop list subscribe to the mods you want, put them into a collection, get that collection using the method here: https://steamcommunity.com/sharedfiles/filedetails

Remember to open the required ports in your firewall.

env vars before gcloud commands:

export TF_VAR_PROJECT_ID=<your project id>
export TF_VAR_PROJECT_NUM=<your project number>
export TF_VAR_REGION=<your region>
export TF_VAR_GAME_PORTS_TCP=<tcp ports>
export TF_VAR_GAME_PORTS_UDP=<udp ports>
export TF_VAR_MACHINE_TYPE=<server machine type>

