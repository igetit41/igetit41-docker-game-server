#!/bin/bash
# Minecraft usage check: RCON list → print online player count (integer only).

RCON_PORT="${RCON_PORT:-25575}"
RCON_OTHER_ARGS="${RCON_OTHER_ARGS:-}"
RCON_BIN="./rcon-0.10.3-amd64_linux/rcon"
RCON_PLAYER_CHECK="${RCON_PLAYER_CHECK:-list}"
RCON_PLAYER_CHECK_GREP="${RCON_PLAYER_CHECK_GREP:-grep -oE 'There are [0-9]+' | grep -oE '[0-9]+'}"

if [ -z "${RCON_PW:-}" ]; then
  RCON_PW=$(curl -sf \
    "http://metadata.google.internal/computeMetadata/v1/instance/attributes/RCON_PW" \
    -H "Metadata-Flavor: Google" || true)
fi

ensure_rcon() {
  local check
  check=$(sudo docker exec -i game-server ls 2>/dev/null | grep -E rcon || true)
  if [[ "$check" == "" ]]; then
    echo "-----usage-check-installing-rcon" >&2
    sudo docker exec -i game-server curl -c x -L --insecure --output rcon-0.10.3-amd64_linux.tar.gz \
      "https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz" >/dev/null
    sudo docker exec -i game-server tar -xzf rcon-0.10.3-amd64_linux.tar.gz >/dev/null
  fi
}

ensure_rcon

RAW=$(sudo docker exec -i game-server "$RCON_BIN" -a "127.0.0.1:$RCON_PORT" -p "$RCON_PW" $RCON_OTHER_ARGS "$RCON_PLAYER_CHECK" 2>/dev/null || true)
FILTERED=$(echo "$RAW" | bash -c "$RCON_PLAYER_CHECK_GREP" || true)
if [[ -z "$FILTERED" ]]; then
  FILTERED=$(echo "$RAW" | grep -oE '[0-9]+' | head -n1)
fi
PLAYERS=$(echo "$FILTERED" | tr -cd '[:digit:]')
echo "-----usage-check-rcon raw=\"$(echo "$RAW" | tr '\n\r' ' ')\" filtered=\"$FILTERED\"" >&2

if ! [[ $PLAYERS =~ ^[0-9]+$ ]]; then
  PLAYERS=0
fi
echo "$PLAYERS"
