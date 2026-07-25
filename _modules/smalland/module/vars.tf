variable "server_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "rcon_password" {
  type      = string
  default   = ""
  sensitive = true
}

output "game_name" {
  value = "smalland"
}

output "game_env_file" {
  value = "smalland.env"
}

output "game_api_key_var" {
  value = ""
}

output "firewall_tcp" {
  value = ["7777", "7778"]
}

output "firewall_udp" {
  value = ["7777", "7778"]
}

output "rcon_compatible" {
  value = "false"
}

output "rcon_pw" {
  value = var.rcon_password
}

output "rcon_other_args" {
  value = ""
}

output "rcon_pw_var" {
  value = ""
}

output "rcon_pw_var_line" {
  value = ""
}

output "rcon_pw_file" {
  value = ""
}

output "rcon_pw_file_path" {
  value = ""
}

output "rcon_player_check" {
  value = ""
}

output "rcon_player_check_grep" {
  value = ""
}

output "rcon_live_test" {
  value = ""
}

output "rcon_live_test_grep" {
  value = ""
}

output "rcon_commands" {
  value = ""
}

output "rcon_reload" {
  value = ""
}

output "exec_commands" {
  value = ""
}

output "server_restart_count" {
  value = "0"
}

output "rcon_port" {
  value = ""
}
