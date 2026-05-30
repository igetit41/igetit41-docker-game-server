#!/bin/bash
# Install _modules/minecraft/minecraft.env from MINECRAFT_ENV_B64 instance metadata.
# Terraform sets metadata at apply time from the local gitignored minecraft.env (never committed).

set -e

DEST="${1:?destination path required}"

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
chmod 600 "$DEST"
if id game-server &>/dev/null; then
  chown game-server:game-server "$DEST" 2>/dev/null || true
fi

echo "-----minecraft-env-installed"
