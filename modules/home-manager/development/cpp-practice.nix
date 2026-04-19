# ~/nixos-config/modules/home-manager/development/cpp-practice.nix
{ lib, config, customConfig, ... }:

let
  cfg = customConfig.profiles.development.cpp-practice;
  envrcContent = ''
    # Managed by your NixOS config. Activates the C++ practice dev shell.
    use flake ~/nixos-config#cpp-practice
  '';
in
{
  config = lib.mkIf cfg.enable {
    home.activation.createCppPracticeEnvrc = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.home.homeDirectory}/cpp_practice"
      envrc_path="${config.home.homeDirectory}/cpp_practice/.envrc"
      envrc_content=${lib.escapeShellArg envrcContent}

      if [ ! -f "$envrc_path" ] || [ "$(cat "$envrc_path")" != "$envrc_content" ]; then
        [ -L "$envrc_path" ] && rm "$envrc_path"
        echo "$envrc_content" > "$envrc_path"
      fi
    '';
  };
}
