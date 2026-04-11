# igetit41-docker-game-server

Terraform on **Google Cloud** provisions a single **Compute Engine** VM (static IP, firewall rules, game-specific instance metadata). On first boot, the VM installs Docker, clones this repo, and runs **Docker Compose** from `game-server/<game>/compose.yaml`. A systemd unit can pull the latest `main` and restart the stack (`game-server/game-server.sh`).

## Supported games

| Game | Compose path | Terraform module (`game-server/.../module`) |
|------|----------------|-----------------------------------------------|
| Valheim | `game-server/valheim/` | Yes |
| Project Zomboid | `game-server/zomboid/` | Yes (default in `terraform/providers_locals.tf`) |
| 7 Days to Die | `game-server/7d2d/` | Yes |
| Minecraft | `game-server/minecraft/` | No (Compose only; add your own firewall if you use Terraform) |
| Enshrouded | `game-server/enshrouded/` | No (Compose only) |

The active game is chosen by the `module "vars"` `source` in `terraform/providers_locals.tf`. That module supplies `game_name` (folder name under `game-server/`), firewall ports, and RCON-related metadata consumed by `startup-script.sh`.

Per-game images and env vars live in each `compose.yaml`. Edit the `# Changes Section` (or equivalent) in that file when switching games or changing server settings. Do not commit real passwords; use placeholders locally and inject secrets via your normal process.

Project Zomboid can load **Steam Workshop** items via `WORKSHOP_IDS` in `game-server/zomboid/compose.yaml`. To build a list from a Workshop collection, see [Steam Workshop collections](https://steamcommunity.com/sharedfiles/filedetails).

## Terraform

From `terraform/`:

**Recommended:** copy `terraform.tfvars.example` to `terraform.tfvars`, edit values, and run `terraform init` / `terraform apply`. Terraform loads `terraform.tfvars` automatically from the working directory. That file is listed in `.gitignore` so secrets stay off the remote.

**Alternative:** set the same inputs with environment variables (`TF_VAR_PROJECT_ID`, `TF_VAR_PROJECT_NUM`, etc.).

`SERVER_PASSWORD` and `RCON_PASSWORD` are marked `sensitive` in Terraform so they are redacted in normal plan/apply output. A `terraform.tfvars` file is still plaintext on disk; for stricter control use a secret manager and inject via CI or `TF_VAR_*`.

State file path is configured in `terraform/providers_locals.tf` (`backend "local"`).

### Ops Agent (Cloud Logging)

`terraform/ops_agent.tf` enables **`osconfig.googleapis.com`** and applies the official **`ops-agent-policy`** module so VM Manager installs **Google Cloud Ops Agent** on instances in the game-server zone that carry the label **`goog-ops-agent-policy=enabled`** (set on `google_compute_instance.game_server`). The VM already sets **`enable-osconfig=TRUE`** in metadata. After `terraform apply`, allow several minutes for install, then use **Logs Explorer** (filter by instance / `resource.type="gce_instance"`) to view shipped logs.

## Future development

Idle detection and auto-shutdown today live in a long-running loop inside GCE **`startup-script.sh`** (RCON `players` / game-specific checks, then `docker compose down` and `poweroff`). Compared to a separate **systemd unit** (similar to Jellyfin’s `jellyfin-auto-shutdown.service` + `ss`-based checks in another repo), the game-server approach is harder to operate and tune. Possible follow-ups:

- **Dedicated systemd service** for idle shutdown only: `Restart=always`, logs under `journalctl -u …`, enable/disable without re-running the full startup script.
- **Keep RCON (or game-native) player queries** as the idle signal—they match “no one playing” better than raw socket counts on game UDP/TCP ports.
- **Harden player-count parsing** for Zomboid (e.g. explicit `rcon_player_check_grep` / less brittle than stripping digits from arbitrary RCON text when the game updates).
- **Optional wall-clock idle** (“minutes since last non-zero player count”) as an alternative or complement to consecutive empty **`COUNT`** intervals (`CHECK_INTERVAL` × `IDLE_COUNT`).
- **Dedicated service account + IAM** for the game VM (instead of the default compute service account), with least-privilege bindings—similar to workload-specific SAs on other GCP projects.
- **Startup script robustness:** `set -e` (or equivalent fail-fast behavior) and centralized boot logging (e.g. `tee` to `/var/log/startup-script.log`) so failures surface clearly and logs are easy to find on the instance.
- **Metadata-driven tuning from Terraform:** pass idle-related values such as **`CHECK_INTERVAL`** / **`IDLE_COUNT`** (or wall-clock equivalents) through instance metadata instead of hardcoding them in `startup-script.sh`; optionally extend to other knobs (e.g. image/branch hints) for parity with metadata-driven config on other stacks.
- **Server-agnostic Terraform + per-game config files:** keep root **`terraform.tfvars`** (or equivalent) limited to **project/infra** inputs (`PROJECT_ID`, region, machine type, which game module). Put **game-specific** settings (server name, Steam branch, **`WORKSHOP_IDS`**, join/admin passwords, RCON, etc.) in **`_modules/<game>/`** as a **committed example** (e.g. `server.config.example.yaml` and/or `server.auto.tfvars.example`) plus a **gitignored local file** users copy and fill in; load via **`yamldecode(file(...))`**, **`-var-file=...`**, or a typed **`game_config`** object. Align or generate **`compose.yaml`** from that source of truth so credentials are not only hardcoded in compose.

## References

- [gorcon/rcon-cli](https://github.com/gorcon/rcon-cli) (used by the startup script inside the game container where applicable)
- [Danixu/project-zomboid-server-docker](https://github.com/Danixu/project-zomboid-server-docker) (Zomboid image basis)
- [PZ wiki – admin commands](https://pzwiki.net/wiki/Admin_commands)
- [vinanrra/Docker-7DaysToDie](https://github.com/vinanrra/Docker-7DaysToDie) (7DTD stack reference)
