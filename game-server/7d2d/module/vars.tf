
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
    #value = "whitelist add D3F1L3;whitelist add 76561198031491305"
    value = ""
}

output "rcon_reload" {
    value = ""
}

output "exec_commands" {
    #value = "sed -i 's|^.*ServerPassword.*|        <property name=\"ServerPassword\" value=\"${var.server_password}\"/>|g' ./serverfiles/sdtdserver.xml;sed -i 's|^.*EACEnabled.*|        <property name=\"EACEnabled\" value=\"false\"/>|g' ./serverfiles/sdtdserver.xml;sed -i 's|^.*<!-- GAMEPLAY -->.*|        <!-- GAMEPLAY -->\n        <property name=\"RecipeFilter\" value=\"0\"/>\n        <property name=\"StarterQuestEnabled\" value=\"true\"/>\n        <property name=\"WanderingHordeFrequency\" value=\"16\"/>\n        <property name=\"WanderingHordeRange\" value=\"8\"/>\n        <property name=\"WanderingHordeEnemyCount\" value=\"10\"/>\n        <property name=\"WanderingHordeEnemyRange\" value=\"10\"/>\n        <property name=\"POITierLootScale\" value=\"0\"/>|g' ./serverfiles/sdtdserver.xml;sed -i 's|^.*<configuration>.*|<configuration>\n        <dllmap dll=\"dl\" target=\"libdl.so.2\"/>|g' ./serverfiles/7DaysToDieServer_Data/MonoBleedingEdge/etc/mono/config"
    value = "sed -i 's|^.*ServerPassword.*|        <property name=\"ServerPassword\" value=\"${var.server_password}\"/>|g' ./serverfiles/sdtdserver.xml;sed -i 's|^.*EACEnabled.*|        <property name=\"EACEnabled\" value=\"false\"/>|g' ./serverfiles/sdtdserver.xml;sed -i 's|^.*<configuration>.*|<configuration>\n        <dllmap dll=\"dl\" target=\"libdl.so.2\"/>|g' ./serverfiles/7DaysToDieServer_Data/MonoBleedingEdge/etc/mono/config"
}

output "server_restart_count" {
    value = "0"
}

output "rcon_port" {
    value = "8081"
}
