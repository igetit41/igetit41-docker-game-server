#!/bin/bash
# Smalland usage check: online players → stdout integer.
#
# Evidence from Saved/docker logs (2026-07-26):
#   - Real join: Login request → Join succeeded: Name
#   - While online: "Got the name form the Session Name" about every 5 minutes
#   - Quit: no UNet Close / RemoteAddr leave line we could find
#   - NotifyAcceptingConnection alone is NOT in-world (Accept spam during load → false 1)
#
# Method: unique player names seen in Join succeeded / Session pulse within ONLINE_TTL.

CONTAINER="${SMALLAND_CONTAINER:-game-server}"
# >5m pulse interval; 7m TTL so one missed pulse after quit clears the player.
ONLINE_TTL_SECS="${SMALLAND_ONLINE_TTL_SECS:-420}"

rm -f /var/tmp/smalland-online-players

if ! sudo docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "-----usage-check-smalland count=0 (no-container)" >&2
  echo 0
  exit 0
fi

LOGS=$(sudo docker logs --since "${ONLINE_TTL_SECS}s" "$CONTAINER" 2>/dev/null || true)

COUNT=$(printf '%s\n' "$LOGS" | awk '
  /Join succeeded:/ {
    name = $0
    sub(/.*Join succeeded:[[:space:]]*/, "", name)
    sub(/[[:space:]]+$/, "", name)
    if (name != "") online[name] = 1
    next
  }
  /Got the name form the Session / {
    name = $0
    sub(/.*Got the name form the Session[[:space:]]+/, "", name)
    sub(/[[:space:]]+$/, "", name)
    if (name != "") online[name] = 1
    next
  }
  END {
    n = 0
    for (a in online) n++
    print n + 0
  }
')

echo "-----usage-check-smalland count=$COUNT ttl=${ONLINE_TTL_SECS}s" >&2
echo "$COUNT"
