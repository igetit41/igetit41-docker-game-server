#!/bin/bash
echo "-----startup-script-output-begin"

CHECK_INTERVAL=60
IDLE_COUNT=15
COUNT=0
FIRST_RUN=false

GAME_NAME=valheim

STANDARD_REPO=/home/game-server/igetit41-docker-game-server
FLAT_REPO=/home/game-server
if [ -f "$STANDARD_REPO/_modules/valheim/compose.yaml" ]; then
  REPO_ROOT=$STANDARD_REPO
elif [ -f "$FLAT_REPO/_modules/valheim/compose.yaml" ]; then
  REPO_ROOT=$FLAT_REPO
else
  REPO_ROOT=$STANDARD_REPO
fi

MODULE_DIR="$REPO_ROOT/_modules/$GAME_NAME"
COMPOSE_FILE="$MODULE_DIR/compose.yaml"
USAGE_CHECK="$MODULE_DIR/usage-check.sh"

wait_for_apt() {
  local n=0
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
     || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 \
     || fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    n=$((n + 1))
    echo "-----startup-script-output-waiting-for-apt-$n"
    sleep 5
    if [ "$n" -gt 60 ]; then
      echo "-----startup-script-output-apt-lock-timeout"
      return 1
    fi
  done
  return 0
}

# First-run = Docker missing (bootstrap may already have cloned the repo).
if ! command -v docker >/dev/null 2>&1; then
    echo "-----startup-script-output-first-run"
    FIRST_RUN=true

    wait_for_apt
    sudo apt update -y
    wait_for_apt
    sudo apt install -y net-tools jq git curl unzip

    echo "-----startup-script-output-add-user"
    if ! id game-server >/dev/null 2>&1; then
      useradd -m --shell /sbin/nologin game-server
      passwd -d game-server
      usermod -a -G sudo game-server
    fi
    cd /home/game-server

    echo "-----startup-script-output-install-docker"
    wait_for_apt
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    wait_for_apt
    sudo apt-get update -y
    wait_for_apt
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo service docker start
    sudo usermod -a -G docker game-server
    if ! command -v docker >/dev/null 2>&1; then
      echo "-----startup-script-output-docker-install-failed"
      exit 1
    fi

    echo "-----startup-script-output-clone-repo"
    if [ ! -d "$STANDARD_REPO/.git" ]; then
      sudo -H -u game-server bash -c 'git clone https://github.com/igetit41/igetit41-docker-game-server'
    fi
    sudo git config --global --add safe.directory "$REPO_ROOT"

    sudo chmod +x "$REPO_ROOT/_modules"/*.sh 2>/dev/null || true
    sudo chmod +x "$MODULE_DIR"/*.sh 2>/dev/null || true
    sudo chmod +x "$REPO_ROOT"/*.sh 2>/dev/null || true
    sudo cp "$REPO_ROOT/_modules/game-server.service" /etc/systemd/system/game-server.service

    MODULE_DIR="$REPO_ROOT/_modules/$GAME_NAME"
    USAGE_CHECK="$MODULE_DIR/usage-check.sh"
    # shellcheck source=/dev/null
    source "$MODULE_DIR/game-server.sh"
    install_env_from_metadata "$MODULE_DIR/valheim.env"

    SERVER_PASSWORD=$(curl -sf \
      "http://metadata.google.internal/computeMetadata/v1/instance/attributes/SERVER_PASSWORD" \
      -H "Metadata-Flavor: Google" || true)
    if [ -n "$SERVER_PASSWORD" ]; then
      if grep -qE '^SERVER_PASS=' "$MODULE_DIR/valheim.env"; then
        sed -i "s|^SERVER_PASS=.*|SERVER_PASS=${SERVER_PASSWORD}|" "$MODULE_DIR/valheim.env"
      else
        printf 'SERVER_PASS=%s\n' "$SERVER_PASSWORD" >> "$MODULE_DIR/valheim.env"
      fi
    fi

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
USAGE_CHECK="$MODULE_DIR/usage-check.sh"

if [ -f "$COMPOSE_FILE" ] && [ ! -f /etc/systemd/system/game-server.service ]; then
    echo "-----startup-script-output-install-systemd-missed-first-run"
    sudo chmod +x "$REPO_ROOT/_modules"/*.sh 2>/dev/null || true
    sudo chmod +x "$MODULE_DIR"/*.sh 2>/dev/null || true
    sudo chmod +x "$REPO_ROOT"/*.sh 2>/dev/null || true
    sudo git config --global --add safe.directory "$REPO_ROOT" 2>/dev/null || true
    sudo cp "$REPO_ROOT/_modules/game-server.service" /etc/systemd/system/game-server.service
    # shellcheck source=/dev/null
    source "$MODULE_DIR/game-server.sh"
    install_env_from_metadata "$MODULE_DIR/valheim.env"
    sudo systemctl daemon-reload
    sudo systemctl enable game-server
    sudo systemctl restart game-server
fi

# Root refreshes the unit every boot (game-server user has no sudo).
if [ -f "$REPO_ROOT/_modules/game-server.service" ]; then
  echo "-----startup-script-output-refresh-game-server-unit"
  sudo cp "$REPO_ROOT/_modules/game-server.service" /etc/systemd/system/game-server.service
  sudo systemctl daemon-reload
  sudo systemctl enable game-server
  sudo systemctl restart game-server
fi

echo "-----startup-script-output-waiting-for-valheim"
LOOP_VAR=0
while true; do
  LOOP_VAR=$((LOOP_VAR + 1))
  # Ensure the unit is running (Thunderstore sync can take several minutes before compose up).
  if [ -f /etc/systemd/system/game-server.service ] \
      && ! systemctl is-active --quiet game-server; then
    echo "-----startup-script-output-starting-game-server-unit"
    sudo systemctl start game-server || true
  fi
  UNIT_STATE=$(systemctl is-active game-server 2>/dev/null || echo unknown)
  CONTAINER_UP=$(sudo docker ps --filter name=^game-server$ --format '{{.Status}}' 2>/dev/null || true)
  STATUS_OK=""
  if curl -sf --max-time 5 "http://127.0.0.1:80/status.json" >/dev/null 2>&1; then
    STATUS_OK=http
  elif sudo docker exec game-server test -f /opt/valheim/htdocs/status.json 2>/dev/null; then
    STATUS_OK=file
  fi
  echo "-----startup-script-output-LOOP_VAR-$LOOP_VAR unit=$UNIT_STATE container=${CONTAINER_UP:-missing} status=${STATUS_OK:-none}"
  if [ -n "$CONTAINER_UP" ] && [ -n "$STATUS_OK" ]; then
    echo "-----startup-script-output-GAMESERVER_RUNNING-status-$STATUS_OK"
    break
  fi
  sleep "$CHECK_INTERVAL"
done

sudo chmod +x "$USAGE_CHECK" "$REPO_ROOT/_modules/idle-loop.sh" 2>/dev/null || true
# shellcheck source=/dev/null
source "$REPO_ROOT/_modules/idle-loop.sh"
