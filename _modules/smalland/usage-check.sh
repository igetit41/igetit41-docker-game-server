#!/bin/bash
# Smalland usage check: docker log join/leave → online count (stdout = integer only).
# Joins observed: NotifyAcceptingConnection ... IP:port ; Join succeeded: Name
# Leaves: any Close-ish line carrying IP:port (calibrate further after a real disconnect)

STATE_FILE="${SMALLAND_USAGE_STATE:-/var/tmp/smalland-online-players}"
WINDOW_SECS="${SMALLAND_LOG_WINDOW_SECS:-90}"

touch "$STATE_FILE"
declare -A online=()
while IFS= read -r id || [ -n "$id" ]; do
  id=${id//$'\r'/}
  id=$(printf '%s' "$id" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -n "$id" ] && online["$id"]=1
done < "$STATE_FILE"

LOGS=$(sudo docker logs game-server --since "${WINDOW_SECS}s" 2>/dev/null || true)

# Join: connection accept → remote IP:port (tolerant of "from" / "from:")
while IFS= read -r addr; do
  [ -n "$addr" ] && online["$addr"]=1
done < <(echo "$LOGS" | grep NotifyAcceptingConnection | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+')

# Join: successful join → player name
while IFS= read -r name; do
  name=$(printf '%s' "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -n "$name" ] && online["name:$name"]=1
done < <(echo "$LOGS" | grep 'Join succeeded:' | sed 's/.*Join succeeded://')

# Leave: connection teardown → remote IP:port
while IFS= read -r addr; do
  [ -n "$addr" ] && unset "online[$addr]" 2>/dev/null || true
done < <(echo "$LOGS" | grep -iE 'UNetConnection::Close|Closing|Cleaned up' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+')

: > "$STATE_FILE"
for key in "${!online[@]}"; do
  printf '%s\n' "$key" >> "$STATE_FILE"
done

COUNT=${#online[@]}
echo "-----usage-check-smalland count=$COUNT" >&2
echo "$COUNT"
