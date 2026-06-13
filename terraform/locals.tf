
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

variable "WAKE_STRING" {
  type      = string
  sensitive = true
  validation {
    condition     = can(regex("^[A-Za-z0-9]+$", var.WAKE_STRING)) && length(var.WAKE_STRING) >= 8
    error_message = "WAKE_STRING must be alphanumeric and at least 8 characters."
  }
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
  game_env_file      = module.vars.game_env_file
  game_api_key_var   = module.vars.game_api_key_var
  game_env_path      = local.game_env_file != "" ? "${path.module}/../_modules/${module.vars.game_name}/${local.game_env_file}" : ""

  game_env_raw = local.game_env_path != "" && fileexists(local.game_env_path) ? replace(file(local.game_env_path), "\r\n", "\n") : ""
  game_env_lines = local.game_env_raw != "" ? split("\n", local.game_env_raw) : []

  game_api_key_line = local.game_api_key_var != "" ? one([
    for line in local.game_env_lines : trimspace(line)
    if startswith(trimspace(line), "${local.game_api_key_var}=")
  ]) : ""

  game_api_key_stripped = local.game_api_key_var != "" ? trimspace(replace(local.game_api_key_line, "${local.game_api_key_var}=", "")) : ""
  game_api_key_raw      = local.game_api_key_var != "" ? replace(replace(local.game_api_key_stripped, "'", ""), "\"", "") : ""

  game_env_body = local.game_api_key_var != "" ? join("\n", [
    for line in local.game_env_lines : line
    if !startswith(trimspace(line), "${local.game_api_key_var}=")
  ]) : local.game_env_raw

  game_env_b64     = local.game_env_path != "" && fileexists(local.game_env_path) ? base64encode(local.game_env_body) : ""
  game_api_key_b64 = length(local.game_api_key_raw) > 0 ? base64encode(local.game_api_key_raw) : ""
}
