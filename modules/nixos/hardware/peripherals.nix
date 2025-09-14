# ~/nixos-config/modules/nixos/hardware/peripherals.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.hardware.peripherals;

in
{
  config = lib.mkIf cfg.enable {

    # === Enable General Peripheral Support ===
    services.hardware.openrgb.enable = cfg.openrgb.enable or false; # Enable OpenRGB for RGB control

    # === Enable Razer Device Support ===
    hardware.openrazer = lib.mkIf cfg.openrazer.enable {
        enable = true; # Enable OpenRazer for Razer device support
        users = [ config.customConfig.user.name ]; # Ensure OpenRazer runs for the user
    };

    users.users.${config.customConfig.user.name}.extraGroups = lib.mkIf cfg.openrazer.enable [
      "plugdev" # Add user to plugdev group for OpenRazer
      "openrazer"
    ];

    # === Enable Corsair Device Support ===
    hardware.ckb-next.enable = cfg.ckb-next.enable or false;

    # === Install Peripheral Management Tools ===
    environment.systemPackages = with pkgs; [
        #openrgb
        solaar
        openrazer-daemon
        polychromatic
        input-remapper
    ];

  };
}