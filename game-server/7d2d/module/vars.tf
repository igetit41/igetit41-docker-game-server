

output "game_name" {
    value = "7d2d"
}

output "firewall_tcp" {
    value = ["26900", "27015"]
}

output "firewall_udp" {
    value = ["26900-26902", "27015"]
}

output "rcon_pw" {
    value = "groovyfunky"
}

output "rcon_pw_var" {
    value = "RCONPassword="
}

output "rcon_pw_file" {
    value = "channel27.ini"
}

output "rcon_pw_file_path" {
    value = "./Zomboid/Server"
}

output "rcon_player_check" {
    value = "players"
}

output "rcon_player_check_grep" {
    value = "tr -cd '[:digit:].'"
}

output "rcon_live_test" {
    value = "help"
}

output "rcon_live_test_grep" {
    value = "grep -Eo help"
}

output "rcon_commands" {
    value = "['setaccesslevel D3F1L3 admin']"
}

output "rcon_reload" {
    value = "reloadlua './Zomboid/Server/channel27_SandboxVars.lua'"
}

output "exec_commands" {
    value = "['sed -i \"s/    CharacterFreePoints = 0,/    CharacterFreePoints = 4,/g\" ./Zomboid/Server/channel27_SandboxVars.lua', 'sed -i \"s/    StarterKit = false,/    StarterKit = true,/g\" ./Zomboid/Server/channel27_SandboxVars.lua']"
}

output "server_restart_count" {
    value = "3"
}
