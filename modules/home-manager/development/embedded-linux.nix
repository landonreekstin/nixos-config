# ~/nixos-config/modules/home-manager/development/embedded-linux.nix
{ lib, pkgs, customConfig, ... }: # Note: We now take `customConfig` as an argument

let
  # Correctly check if the NixOS profile is enabled using the passed-in `customConfig`.
  cfg = customConfig.profiles.development.embedded-linux;
in
{
  config = lib.mkIf cfg.enable {
    # Declaratively create the .envrc file in the embedded-linux directory
    # This will automatically create the directory if it doesn't exist
    home.file."embedded-linux/.envrc".text = ''
      # Managed by your NixOS config. Activates the unified embedded dev shell.
      use flake ~/nixos-config#embedded-linux
    '';
  };
}