# ~/nixos-config/modules/nixos/profiles/htpc.nix
#
# HTPC / Living Room Console Profile
#
# Turns a machine into a dedicated HTPC that boots directly into Steam Big
# Picture (gamescope session).  Controller and TV-remote first.  Optional
# HDMI-CEC, virtual keyboard, and controller wake-from-sleep support.
#
# Usage in a host config:
#   customConfig.profiles.htpc = {
#     enable          = true;
#     autoLogin.enable = true;
#     cec.enable      = true;
#     cec.powerOnTv   = true;
#     controllerWake.enable = true;
#     virtualKeyboard.enable = true;
#   };
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.profiles.htpc;
  userName = config.customConfig.user.name;

  # Script executed by the CEC power-on service.  Waits a few seconds for the
  # display to be ready before issuing the "power on" CEC command.
  cecPowerOnScript = pkgs.writeShellScript "htpc-cec-tv-on" ''
    sleep 5
    echo "on ${toString cfg.cec.hdmiPort}" | ${pkgs.libcec}/bin/cec-client -s -d 1
  '';
in
{
  config = lib.mkIf cfg.enable {

    # =========================================================================
    # Auto-login to the gamescope Steam session
    # =========================================================================
    # When autoLogin is enabled the display manager skips the greeter and
    # drops straight into Steam Big Picture.  The defaultSession must match
    # the session name installed by programs.steam.gamescopeSession.
    services.displayManager = lib.mkIf cfg.autoLogin.enable {
      autoLogin = {
        enable = true;
        user = userName;
      };
      defaultSession = "steam"; # gamescope session name in this nixpkgs version
    };

    # =========================================================================
    # Gamescope output preference
    # =========================================================================
    # Prefer HDMI output so Steam Big Picture renders on the TV rather than
    # the laptop's built-in panel.  Users can override this in the host config
    # via programs.steam.gamescopeSession.args if needed.
    programs.steam.gamescopeSession.args = lib.mkDefault [
      "--prefer-output" "HDMI-A-1,eDP-1"
    ];

    # =========================================================================
    # Jellyfin Media Player
    # =========================================================================
    # Native 10-foot TV UI, controller-friendly.  Add to Steam as a non-Steam
    # app so it appears in Steam Big Picture.
    environment.systemPackages = lib.flatten [
      pkgs.jellyfin-media-player

      # CEC packages (when enabled)
      (lib.optionals cfg.cec.enable [
        pkgs.libcec    # Steam Big Picture uses libcec automatically when present
        pkgs.v4l-utils # provides cec-ctl for manual CEC testing / debugging
      ])

      # Virtual keyboard (when enabled)
      (lib.optionals cfg.virtualKeyboard.enable [
        pkgs.wvkbd  # lightweight Wayland on-screen keyboard
      ])
    ];

    # =========================================================================
    # HDMI-CEC
    # =========================================================================
    # Load uinput so cec-client can create a virtual input device for remote
    # keypresses if needed in the future.
    boot.kernelModules = lib.mkIf cfg.cec.enable [ "uinput" ];

    # Add user to input group for uinput access.
    users.users.${userName}.extraGroups = lib.mkIf cfg.cec.enable
      (lib.mkMerge [
        (lib.mkIf config.users.users.${userName}.isNormalUser [ "input" ])
      ]);

    # CEC TV power-on: fires once at session login to wake the TV.
    # Uses default.target so it runs regardless of whether the session
    # properly advertises graphical-session.target (gamescope may not).
    systemd.user.services.htpc-cec-tv-on = lib.mkIf (cfg.cec.enable && cfg.cec.powerOnTv) {
      description = "Power on TV via HDMI-CEC on HTPC session start";
      wantedBy = [ "default.target" ];
      after = [ "default.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = cecPowerOnScript;
        Restart = "no";
        # Don't block login if the CEC adapter isn't ready.
        RemainAfterExit = false;
      };
    };

    # =========================================================================
    # Controller wake from suspend
    # =========================================================================
    # This udev rule enables USB wakeup for every USB host controller / device
    # as it is added.  When the system suspends, any USB HID device (gamepad,
    # remote) with wakeup enabled can resume it.
    #
    # IMPORTANT: the BIOS must also have "USB Wake Support" enabled and
    # "ErP mode" disabled for this to work.
    services.udev.extraRules = lib.mkIf cfg.controllerWake.enable ''
      # HTPC: enable wakeup from suspend for USB input devices (gamepads, remotes)
      ACTION=="add", SUBSYSTEM=="usb", DRIVER=="usb", ATTR{power/wakeup}="enabled"
    '';

  };
}
