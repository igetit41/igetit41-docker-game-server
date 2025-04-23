

output "game_name" {
    value = "zomboid"
}

output "firewall_tcp" {
    value = ["16262-16272", "27015"]
}

output "firewall_udp" {
    value = ["8766-8767", "16261-16272", "27015"]
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

output "rcon_player_check_proc" {
    value = "| grep -Eo '[0-9]+' | head -1"
}

output "rcon_live_test" {
    value = "help"
}

output "rcon_live_test_proc" {
    value = "| grep createhorde"
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
