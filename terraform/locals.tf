
variable "PROJECT_ID" { type = string }
variable "PROJECT_NUM" { type = string }
variable "REGION" { type = string }
variable "MACHINE_TYPE" { type = string }

variable "SERVER_PASSWORD" {
  type      = string
  sensitive = true
}

variable "RCON_PASSWORD" {
  type      = string
  sensitive = true
}

module "vars" {
  source = "../_modules/minecraft/module"
  #source = "../_modules/zomboid/module"
  #source = "../_modules/7d2d/module"
  #source = "../_modules/valheim/module"
  server_password = var.SERVER_PASSWORD
  rcon_password   = var.RCON_PASSWORD
}

locals {
  project_id         = var.PROJECT_ID
  project_num        = var.PROJECT_NUM
  region             = var.REGION
  machine_type       = var.MACHINE_TYPE
  minecraft_env_path = "${path.module}/../_modules/minecraft/minecraft.env"

  # Parse CF_API_KEY at apply time; deliver as base64 metadata so the VM never
  # parses $ characters through bash or Docker env_file.
  minecraft_env_raw   = replace(file(local.minecraft_env_path), "\r\n", "\n")
  minecraft_env_lines = split("\n", local.minecraft_env_raw)
  cf_api_key_line = one([
    for line in local.minecraft_env_lines : trimspace(line)
    if startswith(trimspace(line), "CF_API_KEY=")
  ])
  cf_api_key_stripped = trimspace(replace(local.cf_api_key_line, "CF_API_KEY=", ""))
  cf_api_key_raw      = replace(replace(local.cf_api_key_stripped, "'", ""), "\"", "")
  minecraft_env_body = join("\n", [
    for line in local.minecraft_env_lines : line
    if !startswith(trimspace(line), "CF_API_KEY=")
  ])

  minecraft_metadata = module.vars.game_name == "minecraft" ? {
    MINECRAFT_ENV_B64 = base64encode(local.minecraft_env_body)
    CF_API_KEY_B64    = base64encode(local.cf_api_key_raw)
  } : {}
}
