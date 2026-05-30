
resource "terraform_data" "minecraft_env_required" {
  count = module.vars.game_name == "minecraft" ? 1 : 0

  lifecycle {
    precondition {
      condition     = fileexists(local.minecraft_env_path)
      error_message = "Create _modules/minecraft/minecraft.env from minecraft.env.example (gitignored) before terraform apply."
    }
    precondition {
      condition     = length(local.cf_api_key_raw) > 0
      error_message = "CF_API_KEY must be set in _modules/minecraft/minecraft.env before terraform apply."
    }
  }
}
