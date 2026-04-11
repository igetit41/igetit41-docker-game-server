# Installs Google Cloud Ops Agent on game-server via OS Config / VM Manager.
# Requires instance label goog-ops-agent-policy=enabled and metadata enable-osconfig=TRUE.

resource "google_project_service" "osconfig" {
  project            = local.project_id
  service            = "osconfig.googleapis.com"
  disable_on_destroy = false
}

module "game_server_ops_agent_policy" {
  source  = "terraform-google-modules/cloud-operations/google//modules/ops-agent-policy"
  version = "~> 0.5.1"

  assignment_id = "game-server-ops-agent"
  zone          = format("%s%s", local.region, "-a")
  project       = local.project_id

  agents_rule = {
    package_state = "installed"
    version       = "latest"
  }

  instance_filter = {
    all = false
    inclusion_labels = [{
      labels = { "goog-ops-agent-policy" = "enabled" }
    }]
  }

  depends_on = [google_project_service.osconfig]
}
