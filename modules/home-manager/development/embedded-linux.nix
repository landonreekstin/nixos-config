# ~/nixos-config/modules/home-manager/development/embedded-linux.nix
{ config, lib, pkgs, customConfig, ... }:

let
  # We check if the corresponding NixOS profile is enabled.
  # The 'config' here refers to the final, merged NixOS configuration.
  cfg = customConfig.profiles.development.embedded-linux;
in
{
  # This entire Home Manager module will only be active if the NixOS profile is enabled.
  config = lib.mkIf cfg.enable {

    # The `home.file` option declaratively manages files in your home directory.
    # The keys create the file path relative to ~, and parent directories are
    # created automatically. This will not touch any other files in the directories.

    home.file."embedded-linux/bbb/.envrc" = {
      # The content of the file.
      text = ''
        # This file is managed by Home Manager.
        # Local changes will be overwritten on the next `nixos-rebuild switch`.
        use flake ~/nixos-config#embedded-bbb
      '';
    };

    home.file."embedded-linux/qemu/.envrc" = {
      text = ''
        # This file is managed by Home Manager.
        # Local changes will be overwritten on the next `nixos-rebuild switch`.
        use flake ~/nixos-config#embedded-qemu
      '';
    };
  };
}