# ~/nixos-config/modules/nixos/hardware/peripherals.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.hardware.peripherals;
  user = config.customConfig.user.name;

in
{
  config = lib.mkIf cfg.enable {

    # === OpenRGB for RGB Lighting Control ===
    services.hardware.openrgb = lib.mkIf cfg.openrgb.enable {
      enable = true;
      # Use the package from nixpkgs-unstable to get the secure dependency
      package = pkgs.unstable.openrgb-with-all-plugins;
    };

    # === OpenRazer for Razer Device Support ===
    hardware.openrazer = lib.mkIf cfg.openrazer.enable {
      enable = true;
      users = [ user ];
    };

    # === ckb-next for Corsair Device Support ===
    hardware.ckb-next.enable = lib.mkIf cfg.ckb-next.enable true;

    # === Input Remapper for Key/Mouse Mapping ===
    services.input-remapper.enable = lib.mkIf cfg.input-remapper.enable true;

    # === Asus ROG Laptop Control ===
    services.asusd = lib.mkIf cfg.asus.enable {
      enable = true;
      enableUserService = true;
    };
     # Systemd user service to set Asus keyboard backlight after login
    systemd.user.services.set-asus-aura = lib.mkIf cfg.asus.enable {
      description = "Set Asus keyboard backlight to static white after login";

      # This service is wanted by the graphical session, so it starts on login.
      wantedBy = [ "graphical-session.target" ];

      # Start after the graphical session is fully established.
      after = [ "graphical-session.target" ];

      # Define the service itself
      serviceConfig = {
        Type = "oneshot"; # It's a one-off command, not a long-running daemon.
        
        # Add a 5-second delay to ensure asusd is ready.
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
        
        # The command to execute. Using the full package path is robust.
        ExecStart = "${pkgs.asusctl}/bin/asusctl aura static -c ffffff";
      };
    };

    # === Add user to necessary peripheral groups ===
    # The 'input' group is not needed for input-remapper as the service runs as root.
    users.users.${user}.extraGroups = with lib.lists;
      optionals cfg.openrazer.enable [ "plugdev" "openrazer" ];

    # === Conditionally Install All Peripheral Management Packages ===
    # Explicitly lists all packages for clarity, based on their enable flags.
    environment.systemPackages = with pkgs; with lib.lists;
      # OpenRGB
      optionals cfg.openrgb.enable [ unstable.openrgb-with-all-plugins ]
      # Razer
      ++ optionals cfg.openrazer.enable [ openrazer-daemon polychromatic ]
      # Corsair
      ++ optionals cfg.ckb-next.enable [ ckb-next ]
      # Logitech
      ++ optionals cfg.solaar.enable [ solaar ]
      # Input Remapper
      ++ optionals cfg.input-remapper.enable [ input-remapper ]
      # Asus
      ++ optionals cfg.asus.enable [ asusctl ];

  };
}