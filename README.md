# igetit41-docker-game-server

Terraform on **Google Cloud** provisions a single **Compute Engine** VM (static IP, firewall rules, game-specific instance metadata). On first boot, the VM installs Docker, clones this repo, and runs **Docker Compose** from `_modules/<game>/compose.yaml`. A systemd unit can pull the latest `main` and restart the stack (`_modules/game-server.sh`). After idle `poweroff`, a **Cloud Run wake** form (`wake-service/`, `terraform/wake.tf`) starts the VM; players connect to the static IP.

## Supported games

| Game | Compose path | Terraform module (`_modules/.../module`) |
|------|----------------|-----------------------------------------------|
| **Valheim (Thunderstore RtDMMO)** | `_modules/valheim/` | Yes (default in `terraform/locals.tf`) |
| Smalland | `_modules/smalland/` | Yes |
| Minecraft (CurseForge modpack) | `_modules/minecraft/` | Yes |
| Project Zomboid | `_modules/zomboid/` | Yes |
| 7 Days to Die | `_modules/7d2d/` | Yes |
| Enshrouded | `_modules/enshrouded/` | No (Compose only) |

The active game is chosen by the `module "vars"` `source` in `terraform/locals.tf`. That module supplies `game_name`, firewall ports, and optional RCON metadata. **Smalland**, **Minecraft**, **Zomboid**, and **Valheim** use per-module `startup-script.sh`, `game-server.sh`, and `usage-check.sh` under `_modules/<game>/`.

Per-game images and env vars live in each `compose.yaml`. Edit the `# Changes Section` in that file when switching games or changing server settings. Do not commit real passwords; use placeholders locally and inject secrets via your normal process.

### Valheim (Thunderstore RtDMMO)

Default stack: [lloesche/valheim-server](https://github.com/lloesche/valheim-server-docker) with [Soloredis RtDMMO](https://thunderstore.io/c/valheim/p/Soloredis/RtDMMO/) (`BEPINEX=true`, `CROSSPLAY=false`). `_modules/valheim/install-thunderstore-pack.sh` downloads the pack and dependencies into `config/bepinex/` on boot.

**Secrets stay in gitignored local files.**

| Secret | Local file (gitignored) |
|--------|-------------------------|
| Join password | `terraform/terraform.tfvars` (`SERVER_PASSWORD` → `SERVER_PASS`) |
| Server name / pack pin | `_modules/valheim/valheim.env` |

Players (PC and Steam Deck) install the same pack with r2modman or Gale. Wake is unchanged: Cloud Run form starts VM `game-server`.

World/config persist in `_modules/valheim/config/` and `_modules/valheim/data/` on the VM.

### Minecraft (CurseForge)

The default stack uses [itzg/minecraft-server](https://github.com/itzg/docker-minecraft-server) with `TYPE=AUTO_CURSEFORGE`.

**Secrets stay in gitignored local files** — nothing sensitive is committed to the repo.

| Secret | Local file (gitignored) |
|--------|-------------------------|
| Join + RCON passwords | `terraform/terraform.tfvars` |
| CurseForge API key + modpack settings | `_modules/minecraft/minecraft.env` |

**Deploy (single command after local setup):**

1. Copy `minecraft.env.example` → `minecraft.env` and set `CF_API_KEY`, modpack URL, memory, etc.
2. Copy `terraform.tfvars.example` → `terraform.tfvars` and set GCP + password values
3. `terraform apply` from `terraform/`

Terraform reads the active module's env file at apply time into `GAME_ENV_B64` and optional `GAME_API_KEY_B64` metadata. `game-server.sh` writes those to disk (also sourced from `startup-script.sh` on first boot). No manual SCP or SSH steps.

World data persists in `_modules/minecraft/data/` on the VM.

## Terraform

From `terraform/`:

**Recommended:** copy `terraform.tfvars.example` to `terraform.tfvars`, edit values, and run `terraform init` / `terraform apply`. Terraform loads `terraform.tfvars` automatically from the working directory. That file is listed in `.gitignore` so secrets stay off the remote.

**Alternative:** set the same inputs with environment variables (`TF_VAR_PROJECT_ID`, `TF_VAR_PROJECT_NUM`, etc.).

`SERVER_PASSWORD` and `RCON_PASSWORD` are marked `sensitive` in Terraform so they are redacted in normal plan/apply output. Both are passed into the active game module; not every game uses both (e.g. Minecraft Java has no join password). Switch games by changing only the `module "vars"` `source` in `terraform/locals.tf`. A `terraform.tfvars` file is still plaintext on disk; for stricter control use a secret manager and inject via CI or `TF_VAR_*`.

State file path is configured in `terraform/providers.tf` (`backend "local"`).

### Ops Agent (Cloud Logging)

`terraform/ops_agent.tf` enables **`osconfig.googleapis.com`** and applies the official **`ops-agent-policy`** module so VM Manager installs **Google Cloud Ops Agent** on instances in the game-server zone that carry the label **`goog-ops-agent-policy=enabled`** (set on `google_compute_instance.game_server`). The VM already sets **`enable-osconfig=TRUE`** in metadata. After `terraform apply`, allow several minutes for install, then use **Logs Explorer** (filter by instance / `resource.type="gce_instance"`) to view shipped logs.

## Future development

Idle detection and auto-shutdown today live in a long-running loop inside GCE **`startup-script.sh`** (RCON `list` / game-specific checks, then `docker compose down` and `poweroff`). Compared to a separate **systemd unit** (similar to Jellyfin’s `jellyfin-auto-shutdown.service` + `ss`-based checks in another repo), the game-server approach is harder to operate and tune. Possible follow-ups:

- **Dedicated systemd service** for idle shutdown only: `Restart=always`, logs under `journalctl -u …`, enable/disable without re-running the full startup script.
- **Keep RCON (or game-native) player queries** as the idle signal—they match “no one playing” better than raw socket counts on game UDP/TCP ports.
- **Optional wall-clock idle** (“minutes since last non-zero player count”) as an alternative or complement to consecutive empty **`COUNT`** intervals (`CHECK_INTERVAL` × `IDLE_COUNT`).
- **Dedicated service account + IAM** for the game VM (instead of the default compute service account), with least-privilege bindings—similar to workload-specific SAs on other GCP projects.
- **Startup script robustness:** `set -e` (or equivalent fail-fast behavior) and centralized boot logging (e.g. `tee` to `/var/log/startup-script.log`) so failures surface clearly and logs are easy to find on the instance.
- **Metadata-driven tuning from Terraform:** pass idle-related values such as **`CHECK_INTERVAL`** / **`IDLE_COUNT`** (or wall-clock equivalents) through instance metadata instead of hardcoding them in `startup-script.sh`; optionally extend to other knobs (e.g. image/branch hints) for parity with metadata-driven config on other stacks.
- **Server-agnostic Terraform + per-game config files:** keep root **`terraform.tfvars`** (or equivalent) limited to **project/infra** inputs (`PROJECT_ID`, region, machine type, which game module). Put **game-specific** settings (server name, modpack URL, join passwords, RCON, etc.) in **`_modules/<game>/`** as a **committed example** (e.g. `server.config.example.yaml` and/or `server.auto.tfvars.example`) plus a **gitignored local file** users copy and fill in; load via **`yamldecode(file(...))`**, **`-var-file=...`**, or a typed **`game_config`** object. Align or generate **`compose.yaml`** from that source of truth so credentials are not only hardcoded in compose.

## References

- [gorcon/rcon-cli](https://github.com/gorcon/rcon-cli) (used by the startup script inside the game container where applicable)
- [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server) (Minecraft image; CurseForge modpack support)
- [CurseForge API keys](https://console.curseforge.com/)
- [vinanrra/Docker-7DaysToDie](https://github.com/vinanrra/Docker-7DaysToDie) (7DTD stack reference)
- [lloesche/valheim-server-docker](https://github.com/lloesche/valheim-server-docker)
- [Soloredis RtDMMO](https://thunderstore.io/c/valheim/p/Soloredis/RtDMMO/)
