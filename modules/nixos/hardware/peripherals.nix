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

    # === Touchpad Gesture Engine ===
    # Enable the service. The configuration will be created separately below.
    services.touchegg.enable = lib.mkIf (cfg.touchpad != null) true;

    # Declaratively create the touchegg configuration file.
    # This is the correct way to configure it, since a 'config' option doesn't exist.
    environment.etc."touchegg/touchegg.conf" = lib.mkIf (cfg.touchpad != null) {
      text = ''
        <touchegg>
          <touchscreen>
            <!-- A default touchscreen config is required, even if you don't have one -->
            <application name="All">
              <gesture type="SWIPE" fingers="3" direction="UP">
                <action type="SEND_KEYS">Super</action>
              </gesture>
            </application>
          </touchscreen>
          
          <touchpad>
            <application name="All">
              <!-- 3-finger swipe up for Activities/Overview -->
              <gesture type="SWIPE" fingers="3" direction="UP">
                <action type="SEND_KEYS">KEY_LEFTMETA</action>
              </gesture>
              
              <!-- 3-finger swipe down to switch windows -->
              <gesture type="SWIPE" fingers="3" direction="DOWN">
                <action type="SEND_KEYS">KEY_LEFTALT+KEY_TAB</action>
              </gesture>

              <!-- 4-finger swipes for workspace switching -->
              <gesture type="SWIPE" fingers="4" direction="LEFT">
                <action type="SEND_KEYS">KEY_LEFTCTRL+KEY_LEFTALT+KEY_LEFT</action>
              </gesture>
              <gesture type="SWIPE" fingers="4" direction="RIGHT">
                <action type="SEND_KEYS">KEY_LEFTCTRL+KEY_LEFTALT+KEY_RIGHT</action>
              </gesture>
            </application>
          </touchpad>
        </touchegg>
      '';
    };
    # === Conditionally add the Touchegg Flatpak GUI ===
    # This contributes to the list defined in your host's default.nix.
    # The NixOS module system wuchill merge them automatically.
    customConfig.packages.flatpak.packages = with lib.lists;
      optionals (cfg.touchpad != null) [
        "com.github.joseexposito.touche"
      ];

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
      ++ optionals cfg.asus.enable [ asusctl ]
      # Touchpad Gestures
      ++ optionals (cfg.touchpad != null) [ touchegg ];

  };
}