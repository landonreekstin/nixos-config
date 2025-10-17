# ~/nixos-config/modules/nixos/hardware/peripherals.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.hardware.peripherals;
  user = config.customConfig.user.name;

in
{
  config = lib.mkIf cfg.enable {

    # === OpenRGB for RGB Lighting Control ===
    services.hardware.openrgb.enable = lib.mkIf cfg.openrgb.enable true;

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
     # === Systemd SYSTEM service to set Asus keyboard backlight at Display Manager ===
    systemd.services.set-asus-aura-dm = lib.mkIf cfg.asus.enable {
      description = "Set Asus keyboard backlight to static white at Display Manager";

      # This service is wanted by the display manager, so it starts with it.
      wantedBy = [ "display-manager.service" ];
      
      # Crucially, ensure this runs AFTER both asusd and the DM are ready.
      after = [ "display-manager.service" "asusd.service" ];

      # Define the service itself
      serviceConfig = {
        Type = "oneshot"; # It's a one-off command.
        
        # The command to execute. It runs as root by default.
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
      optionals cfg.openrgb.enable [ openrgb-with-all-plugins ]
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