#!/bin/bash
# Update Smalland DS from Steam on every start (no validate — keep wake latency low when current).
set -euo pipefail

echo "-----smalland-entrypoint-update-begin"
"${STEAMCMDDIR}/steamcmd.sh" \
  +force_install_dir "${STEAMAPPDIR}" \
  +login anonymous \
  +app_update "${STEAMAPPID}" \
  +quit
echo "-----smalland-entrypoint-update-done"

cd "${STEAMAPPDIR}"
exec /bin/bash /start-server.sh
