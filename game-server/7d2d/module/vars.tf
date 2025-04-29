
variable "server_password" { type = string }

variable "rcon_password" { type = string }

locals {
    #rcon_pw_file_path = "./serverfiles/7DaysToDieServer_Data/.."
    rcon_pw_file_path = "./serverfiles"
    rcon_pw_file = "sdtdserver.xml"
}

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
    value = "${var.rcon_password}"
}

output "rcon_other_args" {
    value = "-t telnet"
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
    #value = "whitelist add D3F1L3;whitelist add 76561198031491305"
    value = ""
}

output "rcon_reload" {
    value = ""
}

output "exec_commands" {
    #value = "sed -i 's|^.*ServerName.*|        <property name=\"ServerName\" value=\"game-server\"/>|g' ${local.rcon_pw_file_path}/${local.rcon_pw_file};sed -i 's|^.*ServerPassword.*|        <property name=\"ServerPassword\" value=\"${var.server_password}\"/>|g' ${local.rcon_pw_file_path}/${local.rcon_pw_file};sed -i 's|^.*BloodMoonFrequency.*|        <property name=\"BloodMoonFrequency\" value=\"0\"/>|g' ${local.rcon_pw_file_path}/${local.rcon_pw_file};sed -i 's|^.*EACEnabled.*|        <property name=\"EACEnabled\" value=\"false\"/>|g' ${local.rcon_pw_file_path}/${local.rcon_pw_file};sed -i 's|^.*<configuration>.*|<configuration> <dllmap dll=\"dl\" target=\"libdl.so.2\"/>|g' ./serverfiles/7DaysToDieServer_Data/MonoBleedingEdge/etc/mono/config;sed -i 's|^.*RecipeFilter.*| |g' ${local.rcon_pw_file_path}/${local.rcon_pw_file};sed -i 's|^.*StarterQuestEnabled.*| |g' ${local.rcon_pw_file_path}/${local.rcon_pw_file};sed -i 's|^.*WanderingHordeFrequency.*| |g' ${local.rcon_pw_file_path}/${local.rcon_pw_file};sed -i 's|^.*WanderingHordeRange.*| |g' ${local.rcon_pw_file_path}/${local.rcon_pw_file};sed -i 's|^.*WanderingHordeEnemyCount.*| |g' ${local.rcon_pw_file_path}/${local.rcon_pw_file};sed -i 's|^.*WanderingHordeEnemyRange.*| |g' ${local.rcon_pw_file_path}/${local.rcon_pw_file};sed -i 's|^.*<property name=\"DeathPenalty\" value=\"3\"/>.*| |g' ${local.rcon_pw_file_path}/${local.rcon_pw_file};sed -i 's|^.*POITierLootScale.*| |g' ${local.rcon_pw_file_path}/${local.rcon_pw_file}"
    value = "sed -i 's|^.*ServerName.*|        <property name=\"ServerName\" value=\"game-server\"/>|g' ${local.rcon_pw_file_path}/${local.rcon_pw_file};sed -i 's|^.*ServerPassword.*|        <property name=\"ServerPassword\" value=\"${var.server_password}\"/>|g' ${local.rcon_pw_file_path}/${local.rcon_pw_file};sed -i 's|^.*BloodMoonFrequency.*|        <property name=\"BloodMoonFrequency\" value=\"0\"/>|g' ${local.rcon_pw_file_path}/${local.rcon_pw_file}"
}

output "server_restart_count" {
    value = "0"
}

output "rcon_port" {
    value = "8081"
}
