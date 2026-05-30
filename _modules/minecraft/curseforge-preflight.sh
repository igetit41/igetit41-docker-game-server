#!/bin/bash
# Verify CurseForge API access before starting the container.
# Avoids hammering the API on a restart loop (CloudFront blocks the VM IP for ~1 hour).

set -e

SECRET="${1:?secret file path required}"

if [ ! -r "$SECRET" ]; then
  echo "ERROR: CurseForge API key file not readable: $SECRET"
  exit 1
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Accept: application/json" \
  -H "x-api-key: $(tr -d '\n' < "$SECRET")" \
  "https://api.curseforge.com/v1/games/432" || true)

if [ "$HTTP_CODE" = "200" ]; then
  echo "-----curseforge-preflight-ok"
  exit 0
fi

echo "-----curseforge-preflight-failed HTTP ${HTTP_CODE:-000}"
echo "CurseForge API unreachable or rate-limited. Stop the container and wait before retrying."
exit 1
