
resource "terraform_data" "game_env_required" {
  count = module.vars.game_env_file != "" ? 1 : 0

  lifecycle {
    precondition {
      condition     = fileexists(local.game_env_path)
      error_message = "Create _modules/${module.vars.game_name}/${module.vars.game_env_file} from the module's .env.example (gitignored) before terraform apply."
    }
    precondition {
      condition     = module.vars.game_api_key_var == "" || length(local.game_api_key_raw) > 0
      error_message = "${module.vars.game_api_key_var} must be set in the module env file before terraform apply."
    }
  }
}
