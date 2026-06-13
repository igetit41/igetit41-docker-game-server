output "game_server_ip" {
  value = google_compute_address.game_server_ip.address
}

output "ssh_iap_command" {
  value = format(
    "gcloud compute ssh %s --zone=%s --project=%s --tunnel-through-iap",
    google_compute_instance.game_server.name,
    google_compute_instance.game_server.zone,
    local.project_id
  )
}

output "wake_url" {
  description = "Stable HTTPS URL for the wake page (Cloud Run)."
  value       = google_cloud_run_v2_service.wake.uri
}
