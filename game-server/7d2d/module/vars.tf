
variable "server_password" { type = string }

output "game_name" {
    value = "7d2d"
}

output "firewall_tcp" {
    value = ["26900"]
}

output "firewall_udp" {
    value = ["26900-26902"]
}

output "rcon_pw" {
    value = "groovyfunky"
}

output "rcon_other_args" {
    value = "-t telnet"
}

output "rcon_pw_var" {
    value = "TelnetPassword"
}

output "rcon_pw_var_line1" {
    value = "        <property name='TelnetPassword'                                 value='"
}

output "rcon_pw_var_line2" {
    value = "'/>"
}

output "rcon_pw_file" {
    value = "sdtdserver.xml"
}

output "rcon_pw_file_path" {
    value = "./serverfiles"
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
    value = "['whitelist add D3F1L3', 'whitelist add 76561198031491305']"
}

output "rcon_reload" {
    value = "[]"
}

output "exec_commands" {
    value = "['sed -i \"s|^.*ServerPassword.*|        <property name='ServerPassword'                                 value='${var.server_password}'/>|g\" ./serverfiles/sdtdserver.xml']"
}

output "server_restart_count" {
    value = "3"
}

output "rcon_port" {
    value = "8081"
}
