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
variable "GAME_PORTS_TCP" { type = list }
variable "GAME_PORTS_UDP" { type = list }

locals {
  project_id   = var.PROJECT_ID
  project_num  = var.PROJECT_NUM
  region       = var.REGION
  machine_type = var.MACHINE_TYPE
  firewall_tcp = var.GAME_PORTS_TCP
  firewall_udp = var.GAME_PORTS_UDP
}

provider "google" {
  project = local.project_id
}
