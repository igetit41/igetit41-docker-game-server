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

## References

- [gorcon/rcon-cli](https://github.com/gorcon/rcon-cli) (used by the startup script inside the game container where applicable)
- [Danixu/project-zomboid-server-docker](https://github.com/Danixu/project-zomboid-server-docker) (Zomboid image basis)
- [PZ wiki – admin commands](https://pzwiki.net/wiki/Admin_commands)
- [vinanrra/Docker-7DaysToDie](https://github.com/vinanrra/Docker-7DaysToDie) (7DTD stack reference)
