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

provider "google" {
  project = local.project_id
}
