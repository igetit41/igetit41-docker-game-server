

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
  source = "../_modules/zomboid/module"
  #source = "../_modules/7d2d/module"
  #source = "../_modules/valheim/module"
  server_password = var.SERVER_PASSWORD
  rcon_password   = var.RCON_PASSWORD
}

locals {
  project_id   = var.PROJECT_ID
  project_num  = var.PROJECT_NUM
  region       = var.REGION
  machine_type = var.MACHINE_TYPE
}