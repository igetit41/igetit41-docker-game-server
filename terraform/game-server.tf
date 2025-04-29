
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
    ports    = module.vars.firewall_tcp
  }

  allow {
    protocol = "udp"
    ports    = module.vars.firewall_udp
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
      size                  = 100
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
    enable-osconfig        = "TRUE"
    GAME_NAME              = module.vars.game_name
    RCON_PW                = module.vars.rcon_pw
    RCON_OTHER_ARGS        = module.vars.rcon_other_args
    RCON_PORT              = module.vars.rcon_port
    RCON_PW_VAR            = module.vars.rcon_pw_var
    RCON_PW_VAR_LINE      = module.vars.rcon_pw_var_line
    RCON_PW_FILE           = module.vars.rcon_pw_file
    RCON_PW_FILE_PATH      = module.vars.rcon_pw_file_path
    RCON_PLAYER_CHECK      = module.vars.rcon_player_check
    RCON_PLAYER_CHECK_GREP = module.vars.rcon_player_check_grep
    RCON_LIVE_TEST         = module.vars.rcon_live_test
    RCON_LIVE_TEST_GREP    = module.vars.rcon_live_test_grep
    RCON_COMMANDS          = module.vars.rcon_commands
    RCON_RELOAD            = module.vars.rcon_reload
    EXEC_COMMANDS          = module.vars.exec_commands
    SERVER_RESTART_COUNT   = module.vars.server_restart_count
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



