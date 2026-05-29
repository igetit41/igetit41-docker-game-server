
variable "server_password" { type = string }

variable "rcon_password" { type = string }

output "game_name" {
  value = "minecraft"
}

output "firewall_tcp" {
  value = ["25565"]
}

output "firewall_udp" {
  value = []
}

output "rcon_compatible" {
  value = "true"
}

output "rcon_pw" {
  value = var.rcon_password
}

output "rcon_other_args" {
  value = ""
}

output "rcon_pw_var" {
  value = "rcon.password"
}

output "rcon_pw_var_line" {
  value = "rcon.password=${var.rcon_password}"
}

output "rcon_pw_file" {
  value = "server.properties"
}

output "rcon_pw_file_path" {
  value = "."
}

output "rcon_player_check" {
  value = "list"
}

output "rcon_player_check_grep" {
  value = "grep -oE 'There are [0-9]+' | grep -oE '[0-9]+'"
}

output "rcon_live_test" {
  value = "list"
}

output "rcon_live_test_grep" {
  value = "grep -E 'players online|There are'"
}

output "rcon_commands" {
  value = ""
}

output "rcon_reload" {
  value = ""
}

output "exec_commands" {
  value = "sed -i 's|^server-password=.*|server-password=${var.server_password}|g' ./server.properties"
}

output "server_restart_count" {
  value = "0"
}

output "rcon_port" {
  value = "25575"
}
