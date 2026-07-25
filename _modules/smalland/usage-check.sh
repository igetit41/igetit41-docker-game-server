#!/bin/bash
# Smalland usage check: UE RemoteAddr join/leave → print online count.
# Calibrate: sudo docker logs game-server | grep -E 'NotifyAcceptingConnection|UNetConnection::Close'

STATE_FILE="${SMALLAND_USAGE_STATE:-/var/tmp/smalland-online-players}"
WINDOW_SECS="${SMALLAND_LOG_WINDOW_SECS:-90}"

touch "$STATE_FILE"
declare -A online=()
while IFS= read -r id || [ -n "$id" ]; do
  id=${id//$'\r'/}
  [ -n "$id" ] && online["$id"]=1
done < "$STATE_FILE"

LOGS=$(sudo docker logs game-server --since "${WINDOW_SECS}s" 2>/dev/null || true)

while IFS= read -r addr; do
  addr=${addr//$'\r'/}
  [ -n "$addr" ] && online["$addr"]=1
done < <(echo "$LOGS" | sed -n 's/.*NotifyAcceptingConnection accepted from //p' | sed 's/[[:space:]]*$//')

while IFS= read -r addr; do
  addr=${addr//$'\r'/}
  [ -n "$addr" ] && unset "online[$addr]" 2>/dev/null || true
done < <(echo "$LOGS" | grep 'UNetConnection::Close' | sed -n 's/.*RemoteAddr:[[:space:]]*\([^,]*\).*/\1/p')

: > "$STATE_FILE"
for key in "${!online[@]}"; do
  printf '%s\n' "$key" >> "$STATE_FILE"
done

COUNT=${#online[@]}
echo "-----usage-check-smalland count=$COUNT" >&2
echo "$COUNT"
