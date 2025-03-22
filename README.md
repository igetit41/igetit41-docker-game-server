# igetit41-docker-game-server

Change the ```# Changes Section``` to match each game. Rename compose file to swap game.

For the Steam Workshop list subscribe to the mods you want, put them into a collection, get that collection using the method here: https://steamcommunity.com/sharedfiles/filedetails

Remember to open the required ports in your firewall.

env vars before gcloud commands:

export PROJECT_NAME=<your project name>
export PROJECT_ID=<your project id>
export STARTUP_FILE_PATH=<path to startup script>
export REGION=<your region>
export RCON_PW=<admin password>
export TARGET_TAG=<admin password>
export GAME_PORTS=<admin password>

gcloud commands:

gcloud compute firewall-rules create $TARGET_TAG \ 
--project=$PROJECT_NAME \ 
--direction=INGRESS \ 
--priority=1000 \ 
--network=default \ 
--action=ALLOW \ 
--rules=$GAME_PORTS \ 
--target-tags=$TARGET_TAG

gcloud compute instances create game-server \ 
--project=$PROJECT_NAME \ 
--zone=$REGION-a \ 
--machine-type=e2-highmem-4 \ 
--network-interface=network-tier=STANDARD,stack-type=IPV4_ONLY,subnet=default \ 
--metadata=enable-osconfig=TRUE,RCON_PW="$RCON_PW" \ 
--maintenance-policy=MIGRATE \ 
--provisioning-model=STANDARD \ 
--service-account=$PROJECT_ID-compute@developer.gserviceaccount.com \ 
--scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \ 
--tags=$TARGET_TAG \ 
--create-disk=auto-delete=yes,boot=yes,device-name=game-server,disk-resource-policy=projects/$PROJECT_NAME/regions/$REGION/resourcePolicies/default-schedule-1,image=projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20250313,mode=rw,size=20,type=pd-balanced \ 
--no-shielded-secure-boot \ 
--shielded-vtpm \ 
--shielded-integrity-monitoring \ 
--labels=goog-ops-agent-policy=v2-x86-template-1-4-0,goog-ec-src=vm_add-gcloud \ 
--reservation-affinity=any \ 
--metadata-from-file=startup-script=$STARTUP_FILE_PATH

