#!/bin/bash
# Thin GCE metadata loader. Pulls main, then execs module startup-script from the repo.
# One terraform apply to install this; later startup/idle changes ride on git + reboot.
echo "-----bootstrap-startup-begin"

REPO_URL=https://github.com/igetit41/igetit41-docker-game-server.git
STANDARD_REPO=/home/game-server/igetit41-docker-game-server

GAME_NAME=$(curl -sf \
  "http://metadata.google.internal/computeMetadata/v1/instance/attributes/GAME_NAME" \
  -H "Metadata-Flavor: Google" || true)
GAME_NAME=${GAME_NAME:-minecraft}

if ! command -v git >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y git
fi

if ! id game-server >/dev/null 2>&1; then
  useradd -m --shell /sbin/nologin game-server
  passwd -d game-server || true
fi

if [ ! -d "$STANDARD_REPO/.git" ]; then
  echo "-----bootstrap-startup-clone"
  sudo -H -u game-server bash -c "cd /home/game-server && git clone '${REPO_URL}'"
fi

echo "-----bootstrap-startup-pull"
git config --global --add safe.directory "$STANDARD_REPO" 2>/dev/null || true
sudo -H -u game-server git -C "$STANDARD_REPO" fetch origin main
sudo -H -u game-server git -C "$STANDARD_REPO" reset --hard origin/main

MODULE_START="$STANDARD_REPO/_modules/$GAME_NAME/startup-script.sh"
if [ ! -f "$MODULE_START" ]; then
  echo "-----bootstrap-startup-missing-$MODULE_START"
  exit 1
fi

chmod +x "$STANDARD_REPO/_modules"/*.sh 2>/dev/null || true
chmod +x "$STANDARD_REPO/_modules/$GAME_NAME"/*.sh 2>/dev/null || true

echo "-----bootstrap-startup-exec-$GAME_NAME"
exec /bin/bash "$MODULE_START"
