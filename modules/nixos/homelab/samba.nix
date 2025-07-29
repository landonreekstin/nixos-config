# ~/nixos-config/modules/nixos/homelab/samba.nix
{ config, lib, ... }:

let
  # Pull the customConfig settings into a local variable for easier access.
  cfg = config.customConfig.homelab.samba;
in
{

  # The actual NixOS configuration that will be applied if the module is enabled.
  config = lib.mkIf cfg.enable {
    # Enable the main Samba service
    services.samba = {
      enable = true;
      # Automatically open the necessary firewall ports for Samba.
      openFirewall = true;

      # Define the shared folders.
      shares = {
        # We'll name our main share "storage"
        storage = {
          # This share points to the Btrfs RAID1 mount point we planned.
          path = "/mnt/storage";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no"; # Users must log in
          # This is the key to avoiding permission issues.
          # All files created via the share will be owned by your main user.
          "force user" = config.customConfig.user.name;
        };
      };
    };

    # This service helps with network discovery on Windows machines.
    services.samba-wsdd = {
      enable = true;
      openFirewall = true;
    };
  };
}