#!/bin/bash
# Install minecraft.env and cf-api-key.secret from instance metadata.
# Terraform base64-encodes both at apply time — the raw CurseForge key never
# passes through bash $ expansion or Docker env_file interpolation.

set -e

DEST="${1:?destination path required}"
SECRET="$(dirname "$DEST")/cf-api-key.secret"

ENV_B64=$(curl -sf \
  "http://metadata.google.internal/computeMetadata/v1/instance/attributes/MINECRAFT_ENV_B64" \
  -H "Metadata-Flavor: Google" || true)

KEY_B64=$(curl -sf \
  "http://metadata.google.internal/computeMetadata/v1/instance/attributes/CF_API_KEY_B64" \
  -H "Metadata-Flavor: Google" || true)

if [ -z "$ENV_B64" ]; then
  echo "ERROR: MINECRAFT_ENV_B64 missing from instance metadata."
  echo "Ensure _modules/minecraft/minecraft.env exists locally and run terraform apply."
  exit 1
fi

if [ -z "$KEY_B64" ]; then
  echo "ERROR: CF_API_KEY_B64 missing from instance metadata."
  echo "Ensure CF_API_KEY is set in minecraft.env and run terraform apply."
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
echo "$ENV_B64" | base64 -d > "$DEST"
echo "$KEY_B64" | base64 -d > "$SECRET"
sed -i 's/\r$//' "$DEST"

chmod 600 "$DEST"
chmod 400 "$SECRET"
chown 1000:1000 "$SECRET"
if id game-server &>/dev/null; then
  chown game-server:game-server "$DEST" 2>/dev/null || true
fi

echo "-----minecraft-env-installed"
