
variable "server_password" { type = string }

variable "rcon_password" { type = string }

output "game_name" {
    value = "zomboid"
}

output "firewall_tcp" {
    value = ["16262-16272", "27015"]
}

output "firewall_udp" {
    value = ["8766-8767", "16261-16272", "27015"]
}

output "rcon_compatible" {
    value = "true"
}

output "rcon_pw" {
    value = "${var.rcon_password}"
}

output "rcon_other_args" {
    value = ""
}

output "rcon_pw_var" {
    value = "RCONPassword"
}

output "rcon_pw_var_line" {
    value = "RCONPassword=${var.rcon_password}"
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
    value = ""
}

output "rcon_live_test" {
    value = "help"
}

output "rcon_live_test_grep" {
    value = "grep -Eo createhorde"
}

output "rcon_commands" {
    value = "['setaccesslevel D3F1L3 admin']"
}

output "rcon_reload" {
    value = "[\"reloadlua './Zomboid/Server/channel27_SandboxVars.lua'\"]"
}

output "exec_commands" {
    value = "['sed -i \"s/    CharacterFreePoints = 0,/    CharacterFreePoints = 4,/g\" ./Zomboid/Server/channel27_SandboxVars.lua', 'sed -i \"s/    StarterKit = false,/    StarterKit = true,/g\" ./Zomboid/Server/channel27_SandboxVars.lua']"
}

output "server_restart_count" {
    value = "3"
}

output "rcon_port" {
    value = "27015"
}
