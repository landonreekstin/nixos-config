# ~/nixos-config/modules/nixos/hardware/peripherals.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.hardware.peripherals;
  user = config.customConfig.user.name;

  # Override ckb-next to disable dbusmenu (requires removed dbusmenu-qt5 in 25.11)
  ckb-next-fixed = pkgs.ckb-next.overrideAttrs (oldAttrs: {
    cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [ "-DUSE_DBUS_MENU=0" ];
  });

  # Script to set ckb-next lighting via the daemon's command pipe.
  # Waits for the ckb-next GUI process to appear and load its saved profile,
  # then applies the color saved in ~/.cache/ckb-color-state. Falls through
  # after 30s if the GUI is not running. Defaults to index 0 (radar green)
  # at 80% brightness if no state file exists.
  #
  # Color palette must stay in sync with century-series/ckb-scripts.nix:
  #   0=39ff14 (RADAR), 1=ff7a1a (AMBER), 2=cc0000 (RED), 3=00c8b4 (MIG)
  ckbLightingScript = pkgs.writeShellScript "ckb-next-set-lighting" ''
    # Wait for the ckb-next GUI to start (max 30s, 300ms polling).
    # NixOS wraps binaries so the process comm is ".ckb-next-wrapp", not "ckb-next".
    # Use pgrep -a (full cmdline) and exclude the daemon to detect the GUI.
    i=0
    while ! ${pkgs.procps}/bin/pgrep -a ckb-next | grep -qv daemon; do
      sleep 0.3
      i=$((i + 1))
      if [ "$i" -ge 100 ]; then break; fi  # fall through if GUI not running
    done
    # Wait for the GUI to finish connecting to the daemon and restoring its profile.
    # The process appears quickly but profile restoration takes a few seconds.
    sleep 6

    COLORS=("39ff14" "ff7a1a" "cc0000" "00c8b4")
    STATE_FILE="$HOME/.cache/ckb-color-state"
    [ ! -f "$STATE_FILE" ] && echo "0:80" > "$STATE_FILE"
    STATE=$(cat "$STATE_FILE")
    IDX="''${STATE%%:*}"
    BRIGHT="''${STATE##*:}"
    [[ "$IDX" =~ ^[0-3]$ ]]         || IDX=0
    [[ "$BRIGHT" =~ ^[0-9]+$ ]] && [ "$BRIGHT" -le 100 ] || BRIGHT=80

    CMD_PIPE=$(ls /dev/input/ckb*/cmd 2>/dev/null | grep -v '/ckb0/' | head -1)
    if [ -z "$CMD_PIPE" ]; then
      echo "ckb-next-set-lighting: no device cmd pipe found" >&2
      exit 1
    fi
    # Scale each RGB channel by brightness (avoids relying on the `brightness`
    # CMD pipe command which is unreliable after an `rgb` command).
    COLOR="''${COLORS[$IDX]}"
    R=$(( 0x''${COLOR:0:2} * BRIGHT / 100 ))
    G=$(( 0x''${COLOR:2:2} * BRIGHT / 100 ))
    B=$(( 0x''${COLOR:4:2} * BRIGHT / 100 ))
    SCALED=$(printf "%02x%02x%02x" "$R" "$G" "$B")
    echo "rgb $SCALED" > "$CMD_PIPE"
  '';

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
    hardware.ckb-next = lib.mkIf cfg.ckb-next.enable {
      enable = true;
      package = ckb-next-fixed;
    };

    # === Systemd service to turn off ckb-next lights on shutdown ===
    systemd.services.ckb-next-off = lib.mkIf cfg.ckb-next.enable {
      description = "Stop ckb-next daemon to turn off keyboard lights on shutdown";

      # This service is wanted by the targets that run during shutdown/reboot.
      wantedBy = [ "poweroff.target" "reboot.target" "halt.target" ];

      # Define the service itself
      serviceConfig = {
        Type = "oneshot"; # It runs a single command and exits.
        RemainAfterExit = true; # Considers the service "active" after the command runs.

        # The command to execute: `systemctl stop ckb-next-daemon.service`
        # Using the full package path is robust.
        ExecStart = "${pkgs.systemd}/bin/systemctl stop ckb-next.service";
      };
    };

    # === User-level service to apply declarative lighting after session starts ===
    # Fires at graphical-session.target; the script waits for the ckb-next GUI
    # to appear and load its saved profile before overriding with the declared color.
    systemd.user.services.ckb-next-set-lighting = lib.mkIf cfg.ckb-next.enable {
      description = "Apply ckb-next keyboard color after graphical session starts";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ckbLightingScript;
      };
    };

    # === Input Remapper for Key/Mouse Mapping ===
    services.input-remapper = lib.mkIf cfg.input-remapper.enable {
      enable = true;
      package = pkgs.unstable.input-remapper;
    };

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
      optionals cfg.openrgb.enable [ unstable.openrgb-with-all-plugins ]
      # Razer
      ++ optionals cfg.openrazer.enable [ openrazer-daemon polychromatic ]
      # Corsair
      ++ optionals cfg.ckb-next.enable [ ckb-next-fixed ]
      # Logitech
      ++ optionals cfg.solaar.enable [ solaar ]
      # Input Remapper
      ++ optionals cfg.input-remapper.enable [ unstable.input-remapper ]
      # Asus
      ++ optionals cfg.asus.enable [ asusctl ];

  };
}