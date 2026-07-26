#!/bin/bash
# Smalland usage check: one online id per connection (IP:port) → stdout integer.
# Join: NotifyAcceptingConnection (IP:port). Do not also count Join succeeded names (double-counts one player).
# Leave: Close/Closing/Cleaned-up lines carrying IP:port (calibrate further after a real disconnect).

STATE_FILE="${SMALLAND_USAGE_STATE:-/var/tmp/smalland-online-players}"
WINDOW_SECS="${SMALLAND_LOG_WINDOW_SECS:-90}"

touch "$STATE_FILE"
declare -A online=()
while IFS= read -r id || [ -n "$id" ]; do
  id=${id//$'\r'/}
  id=$(printf '%s' "$id" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  # Drop legacy name: keys from earlier double-count builds
  [[ "$id" == name:* ]] && continue
  [ -n "$id" ] && online["$id"]=1
done < "$STATE_FILE"

LOGS=$(sudo docker logs game-server --since "${WINDOW_SECS}s" 2>/dev/null || true)

while IFS= read -r addr; do
  [ -n "$addr" ] && online["$addr"]=1
done < <(echo "$LOGS" | grep NotifyAcceptingConnection | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+')

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
