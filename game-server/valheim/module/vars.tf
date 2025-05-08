
variable "server_password" { type = string }

variable "rcon_password" { type = string }

locals {
    rcon_pw_file_path = "./serverfiles"
    rcon_pw_file = "sdtdserver.xml"
}

output "game_name" {
    value = "valheim"
}

output "firewall_tcp" {
    value = []
}

output "firewall_udp" {
    value = ["2456-2458"]
}

output "rcon_compatible" {
    value = "false"
}

output "rcon_pw" {
    value = "${var.rcon_password}"
}

output "rcon_other_args" {
    value = ""
}

output "rcon_pw_var" {
    value = "TelnetPassword"
}

output "rcon_pw_var_line" {
    value = "        <property name=\"TelnetPassword\" value=\"${var.rcon_password}\"/>"
}

output "rcon_pw_file" {
    value = "${local.rcon_pw_file}"
}

output "rcon_pw_file_path" {
    value = "${local.rcon_pw_file_path}"
}

output "rcon_player_check" {
    value = "listplayerids"
}

output "rcon_player_check_grep" {
    value = "grep -E Total"
}

output "rcon_live_test" {
    value = "help"
}

output "rcon_live_test_grep" {
    value = "grep -Eo spawnairdrop"
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
    value = "8081"
}
