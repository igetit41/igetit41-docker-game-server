#!/bin/bash
# Valheim usage check: STATUS_HTTP status.json → stdout integer player_count.
# Image: lloesche/valheim-server with STATUS_HTTP=true (compose binds 127.0.0.1:80).

STATUS_URL="${VALHEIM_STATUS_URL:-http://127.0.0.1:80/status.json}"
CONTAINER="${VALHEIM_CONTAINER:-game-server}"

if ! sudo docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "-----usage-check-valheim count=0 (no-container)" >&2
  echo 0
  exit 0
fi

RAW=$(curl -sf --max-time 5 "$STATUS_URL" 2>/dev/null || true)
if [ -z "$RAW" ]; then
  # Fallback: read file written inside the container (same payload as HTTP).
  RAW=$(sudo docker exec "$CONTAINER" cat /opt/valheim/htdocs/status.json 2>/dev/null || true)
fi

if [ -z "$RAW" ]; then
  echo "-----usage-check-valheim count=0 (no-status)" >&2
  echo 0
  exit 0
fi

if command -v jq >/dev/null 2>&1; then
  PLAYERS=$(printf '%s' "$RAW" | jq -r '.player_count // 0' 2>/dev/null || echo 0)
else
  PLAYERS=$(printf '%s' "$RAW" | grep -oE '"player_count"[[:space:]]*:[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | head -n1)
fi

PLAYERS=$(printf '%s' "$PLAYERS" | tr -cd '[:digit:]')
if ! [[ $PLAYERS =~ ^[0-9]+$ ]]; then
  PLAYERS=0
fi

echo "-----usage-check-valheim count=$PLAYERS" >&2
echo "$PLAYERS"
