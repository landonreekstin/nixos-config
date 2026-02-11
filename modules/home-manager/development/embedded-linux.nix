# ~/nixos-config/modules/home-manager/development/embedded-linux.nix
{ lib, pkgs, config, customConfig, ... }:

let
  cfg = customConfig.profiles.development.embedded-linux;
  envrcContent = ''
    # Managed by your NixOS config. Activates the unified embedded dev shell.
    use flake ~/nixos-config#embedded-linux
  '';
in
{
  config = lib.mkIf cfg.enable {
    # Use activation script to copy (not symlink) the .envrc file
    # This allows direnv to update timestamps on the file
    home.activation.createEmbeddedLinuxEnvrc = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.home.homeDirectory}/embedded-linux"
      envrc_path="${config.home.homeDirectory}/embedded-linux/.envrc"
      envrc_content=${lib.escapeShellArg envrcContent}

      # Only update if content differs (preserves user modifications)
      if [ ! -f "$envrc_path" ] || [ "$(cat "$envrc_path")" != "$envrc_content" ]; then
        # Remove symlink if it exists (from old config)
        [ -L "$envrc_path" ] && rm "$envrc_path"
        echo "$envrc_content" > "$envrc_path"
      fi
    '';
  };
}