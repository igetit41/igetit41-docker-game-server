#!/bin/bash
# Smalland usage check: online players → stdout integer.
# Rebuild from docker logs since this container start (no sticky state file).
# Join: NotifyAcceptingConnection (IP:port). Leave: Close/Closing/Cleaned-up with IP:port.
# Do not also count Join succeeded names (that double-counted one player).

CONTAINER="${SMALLAND_CONTAINER:-game-server}"

STARTED=$(sudo docker inspect -f '{{.State.StartedAt}}' "$CONTAINER" 2>/dev/null || true)
if [ -z "$STARTED" ] || [ "$STARTED" = "<no value>" ]; then
  echo "-----usage-check-smalland count=0 (no-container)" >&2
  echo 0
  exit 0
fi

# Drop legacy sticky set from older builds (host path survives poweroff).
rm -f /var/tmp/smalland-online-players

LOGS=$(sudo docker logs --since "$STARTED" "$CONTAINER" 2>/dev/null || true)

COUNT=$(printf '%s\n' "$LOGS" | awk '
  BEGIN { IGNORECASE = 1 }
  /NotifyAcceptingConnection/ {
    if (match($0, /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+/)) {
      online[substr($0, RSTART, RLENGTH)] = 1
    }
    next
  }
  /UNetConnection::Close|Closing|Cleaned up/ {
    if (match($0, /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+/)) {
      delete online[substr($0, RSTART, RLENGTH)]
    }
  }
  END {
    n = 0
    for (a in online) n++
    print n + 0
  }
')

echo "-----usage-check-smalland count=$COUNT since=$STARTED" >&2
echo "$COUNT"
