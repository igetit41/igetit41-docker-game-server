# Cloud Run wake page: enter wake string → start game-server VM when TERMINATED.
# URL is the stable Cloud Run URI (no custom domain or extra static IP).
#
# Image build uses Cloud Build during apply (requires gcloud CLI + credentials).
# google provider ~> 5.10 does not support build_config / invoker_iam_disabled on
# google_cloud_run_v2_service; public access uses roles/run.invoker for allUsers.

locals {
  game_server_zone = format("%s%s", local.region, "-a")
  wake_source_hash = sha256(join("", [
    filesha256("${path.module}/../wake-service/main.py"),
    filesha256("${path.module}/../wake-service/requirements.txt"),
    filesha256("${path.module}/../wake-service/Dockerfile"),
    filesha256("${path.module}/../wake-service/cloudbuild.yaml"),
  ]))
  wake_image = "${local.region}-docker.pkg.dev/${local.project_id}/wake-service/wake:${local.wake_source_hash}"
}

resource "google_project_service" "wake_apis" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
  ])

  project            = local.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_service_account" "wake" {
  account_id   = "game-server-wake"
  display_name = "Game Server Wake (Cloud Run)"
  project      = local.project_id

  depends_on = [google_project_service.wake_apis]
}

resource "google_project_iam_custom_role" "wake" {
  role_id     = "gameServerWake"
  title       = "Game Server Wake"
  description = "Start and inspect the game-server VM"
  permissions = [
    "compute.instances.get",
    "compute.instances.start",
  ]
  project = local.project_id
}

resource "google_project_iam_member" "wake" {
  project = local.project_id
  role    = google_project_iam_custom_role.wake.id
  member  = "serviceAccount:${google_service_account.wake.email}"
}

resource "google_secret_manager_secret" "wake" {
  secret_id = "game-server-wake-string"
  project   = local.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.wake_apis]
}

resource "google_secret_manager_secret_version" "wake" {
  secret      = google_secret_manager_secret.wake.id
  secret_data = var.WAKE_STRING
}

resource "google_secret_manager_secret_iam_member" "wake_sa" {
  secret_id = google_secret_manager_secret.wake.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.wake.email}"
}

resource "google_artifact_registry_repository" "wake" {
  repository_id = "wake-service"
  format        = "DOCKER"
  location      = local.region
  project       = local.project_id

  depends_on = [google_project_service.wake_apis]
}

resource "google_project_iam_member" "cloudbuild_wake" {
  for_each = toset([
    "roles/artifactregistry.writer",
    "roles/run.admin",
  ])

  project = local.project_id
  role    = each.key
  member  = "serviceAccount:${local.project_num}@cloudbuild.gserviceaccount.com"
}

resource "google_service_account_iam_member" "cloudbuild_wake_sa_user" {
  service_account_id = google_service_account.wake.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.project_num}@cloudbuild.gserviceaccount.com"
}

resource "terraform_data" "wake_image_build" {
  triggers_replace = {
    source_hash = local.wake_source_hash
    image       = local.wake_image
  }

  depends_on = [
    google_artifact_registry_repository.wake,
    google_project_iam_member.cloudbuild_wake,
  ]

  provisioner "local-exec" {
    command = join(" ", [
      "gcloud builds submit",
      abspath("${path.module}/../wake-service"),
      "--config=cloudbuild.yaml",
      "--substitutions=_IMAGE=${local.wake_image}",
      "--project=${local.project_id}",
      "--region=${local.region}",
      "--quiet",
    ])
  }
}

resource "google_cloud_run_v2_service" "wake" {
  name     = "game-server-wake"
  location = local.region
  project  = local.project_id

  ingress = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.wake.email

    containers {
      image = local.wake_image

      env {
        name  = "GCP_PROJECT"
        value = local.project_id
      }

      env {
        name  = "INSTANCE_ZONE"
        value = local.game_server_zone
      }

      env {
        name  = "INSTANCE_NAME"
        value = google_compute_instance.game_server.name
      }

      env {
        name = "WAKE_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.wake.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }
  }

  depends_on = [
    google_project_service.wake_apis,
    google_secret_manager_secret_iam_member.wake_sa,
    google_project_iam_member.wake,
    terraform_data.wake_image_build,
  ]

  lifecycle {
    ignore_changes = [
      client,
      client_version,
    ]
  }
}

resource "google_cloud_run_v2_service_iam_member" "wake_public" {
  project  = local.project_id
  location = google_cloud_run_v2_service.wake.location
  name     = google_cloud_run_v2_service.wake.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
