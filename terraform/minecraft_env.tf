
resource "terraform_data" "minecraft_env_required" {
  count = module.vars.game_name == "minecraft" ? 1 : 0

  lifecycle {
    precondition {
      condition     = fileexists(local.minecraft_env_path)
      error_message = "Create _modules/minecraft/minecraft.env from minecraft.env.example (gitignored) before terraform apply."
    }
  }
}
