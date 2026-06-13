# Cloud Run wake page: enter wake string → start game-server VM when TERMINATED.
# URL is the stable Cloud Run URI (no custom domain or extra static IP).

data "archive_file" "wake_source" {
  type        = "zip"
  source_dir  = "${path.module}/../wake-service"
  output_path = "${path.module}/.wake-source.zip"
}

locals {
  game_server_zone = format("%s%s", local.region, "-a")
  wake_image         = "${local.region}-docker.pkg.dev/${local.project_id}/wake-service/wake:${data.archive_file.wake_source.output_sha}"
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

resource "google_storage_bucket" "wake_source" {
  name                        = "${local.project_id}-wake-source"
  location                    = local.region
  project                     = local.project_id
  uniform_bucket_level_access = true
  force_destroy               = true

  depends_on = [google_project_service.wake_apis]
}

resource "google_storage_bucket_object" "wake_source" {
  name   = "wake-${data.archive_file.wake_source.output_sha}.zip"
  bucket = google_storage_bucket.wake_source.name
  source = data.archive_file.wake_source.output_path
}

resource "google_storage_bucket_iam_member" "cloudbuild_wake_source" {
  bucket = google_storage_bucket.wake_source.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${local.project_num}@cloudbuild.gserviceaccount.com"
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

resource "google_cloud_run_v2_service" "wake" {
  name     = "game-server-wake"
  location = local.region
  project  = local.project_id

  invoker_iam_disabled = true

  build_config {
    source {
      storage_source {
        bucket = google_storage_bucket.wake_source.name
        object = google_storage_bucket_object.wake_source.name
      }
    }
    image_uri = local.wake_image
  }

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
    google_artifact_registry_repository.wake,
    google_storage_bucket_object.wake_source,
    google_secret_manager_secret_iam_member.wake_sa,
    google_project_iam_member.wake,
  ]

  lifecycle {
    ignore_changes = [
      client,
      client_version,
    ]
  }
}
