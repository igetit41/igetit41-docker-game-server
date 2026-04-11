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
