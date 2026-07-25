#!/bin/bash
# Shared idle policy only. Expects CHECK_INTERVAL, IDLE_COUNT, COMPOSE_FILE, USAGE_CHECK.

COUNT="${COUNT:-0}"

while true; do
  PLAYERS=$("$USAGE_CHECK" 2>/dev/null | tr -cd '[:digit:]' | head -n1)
  STAMP=$(date +'%Y-%m-%d:%H.%M:%S')
  echo "-----startup-script-output-$STAMP-PLAYERS: $PLAYERS"

  if ! [[ $PLAYERS =~ ^[0-9]+$ ]]; then
    PLAYERS=0
  fi

  if [[ $PLAYERS -gt 0 ]]; then
    COUNT=0
  else
    COUNT=$((COUNT + 1))
  fi
  echo "-----startup-script-output-$STAMP-COUNT: $COUNT"

  if [ "$COUNT" -gt "$IDLE_COUNT" ]; then
    echo "-----startup-script-output-$STAMP-shutting-down"
    sudo docker compose --file "$COMPOSE_FILE" down
    sudo poweroff
    break
  fi

  echo "-----startup-script-output-sleep-$CHECK_INTERVAL"
  sleep "$CHECK_INTERVAL"
done
