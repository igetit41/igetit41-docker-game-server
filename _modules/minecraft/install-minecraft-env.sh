#!/bin/bash
# Install _modules/minecraft/minecraft.env from MINECRAFT_ENV_B64 instance metadata.
# Terraform sets metadata at apply time from the local gitignored minecraft.env (never committed).
#
# CF_API_KEY is written to cf-api-key.secret (CF_API_KEY_FILE) — Docker Compose mangles $
# in env_file values; a raw file avoids quoting/escaping entirely.

set -e

DEST="${1:?destination path required}"
SECRET="$(dirname "$DEST")/cf-api-key.secret"

B64=$(curl -sf \
  "http://metadata.google.internal/computeMetadata/v1/instance/attributes/MINECRAFT_ENV_B64" \
  -H "Metadata-Flavor: Google" || true)

if [ -z "$B64" ]; then
  echo "ERROR: MINECRAFT_ENV_B64 missing from instance metadata."
  echo "Ensure _modules/minecraft/minecraft.env exists locally and run terraform apply."
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
echo "$B64" | base64 -d > "$DEST"
sed -i 's/\r$//' "$DEST"

cf_key=""
if grep -q '^CF_API_KEY=' "$DEST"; then
  # cut/sed only — never assign the key through bash double-quotes ($P, $10, etc. expand)
  cf_key=$(grep -m1 '^CF_API_KEY=' "$DEST" | cut -d= -f2- | sed -e "s/^['\"]//" -e "s/['\"]$//")
  sed -i '/^CF_API_KEY=/d' "$DEST"
fi

if [ -z "$cf_key" ]; then
  echo "ERROR: CF_API_KEY missing from minecraft.env metadata."
  exit 1
fi

printf '%s' "$cf_key" > "$SECRET"

chmod 600 "$DEST"
# itzg/minecraft-server runs as uid 1000 — secret is bind-mounted into the container
chmod 400 "$SECRET"
chown 1000:1000 "$SECRET"
if id game-server &>/dev/null; then
  chown game-server:game-server "$DEST" 2>/dev/null || true
fi

echo "-----minecraft-env-installed"
