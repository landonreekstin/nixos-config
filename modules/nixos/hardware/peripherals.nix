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
      ++ optionals cfg.input-remapper.enable [ input-remapper ];

  };
}