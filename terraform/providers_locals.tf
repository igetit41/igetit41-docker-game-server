terraform {
  required_version = "1.5.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.10.0"
    }
  }

  backend "local" {
    path = "../../tfstates/game-server.tfstate"
  }
}

variable "PROJECT_ID" { type = string }
variable "PROJECT_NUM" { type = string }
variable "REGION" { type = string }
variable "MACHINE_TYPE" { type = string }
variable "SERVER_PASSWORD" { type = string }

module "vars" {
  #source = "../game-server/zomboid/module"
  source = "../game-server/7d2d/module"
  server_password = var.SERVER_PASSWORD
}

locals {
  project_id   = var.PROJECT_ID
  project_num  = var.PROJECT_NUM
  region       = var.REGION
  machine_type = var.MACHINE_TYPE
}

provider "google" {
  project = local.project_id
}
