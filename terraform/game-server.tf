
data "google_compute_network" "default" {
  name    = "default"
  project = local.project_id
}

resource "google_compute_firewall" "game-server" {
  name          = "game-server"
  network       = data.google_compute_network.default.name
  project       = local.project_id
  target_tags   = ["game-server"]
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = local.firewall_tcp
  }

  allow {
    protocol = "udp"
    ports    = local.firewall_udp
  }
}

resource "google_compute_address" "game_server_ip" {
  name         = "game-server"
  address_type = "EXTERNAL"
  project      = local.project_id
  region       = local.region
}

resource "google_compute_instance" "game_server" {
  name         = "game-server"
  machine_type = local.machine_type
  zone         = format("%s%s", local.region, "-a")
  project      = local.project_id

  tags = ["game-server"]

  boot_disk {
    initialize_params {
      labels                = {}
      resource_manager_tags = {}
      #image                 = "ubuntu-os-cloud/ubuntu-2004-lts"
      image                 = "ubuntu-os-cloud/ubuntu-2004-focal-v20250313"
      size                  = 20
      type                  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = format("%s%s%s%s%s","/projects/", local.project_id, "/regions/", local.region, "/subnetworks/default")
    access_config {
      nat_ip       = google_compute_address.game_server_ip.address
      network_tier = "STANDARD"
    }
  }

  metadata = {
    enable-osconfig = "TRUE"
    RCON_PW         = "groovyfunky"
  }

  metadata_startup_script = "${file("../startup-script.sh")}"

  service_account {
    email  = format("%s%s", local.project_num, "-compute@developer.gserviceaccount.com")
    scopes = [
        "https://www.googleapis.com/auth/devstorage.read_only",
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring.write",
        "https://www.googleapis.com/auth/service.management.readonly",
        "https://www.googleapis.com/auth/servicecontrol",
        "https://www.googleapis.com/auth/trace.append",
      ]
  }
}



