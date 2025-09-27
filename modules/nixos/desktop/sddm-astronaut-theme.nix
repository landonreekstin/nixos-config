# ~/nixos-config/modules/nixos/desktop/sddm-astronaut-theme.nix
{ config, pkgs, lib, customConfig, ... }:

let
  dmCfg = config.customConfig.desktop.displayManager;
  sddmCfg = dmCfg.sddm;

  sddmAstronautThemeEnabled = (dmCfg.enable)
                            && (dmCfg.type == "sddm")
                            && (sddmCfg.theme == "sddm-astronaut");

  sddmScreensaverEnabled = sddmAstronautThemeEnabled && sddmCfg.screensaver.enable;

  sddm-astronaut-custom = pkgs.sddm-astronaut.override {
    embeddedTheme = sddmCfg.embeddedTheme;
  };

  # Combine all necessary Qt QML paths into one variable
  qmlPaths = with pkgs.kdePackages; lib.makeSearchPath "lib/qt-6/qml" [
    qtmultimedia
    qtsvg
    qtvirtualkeyboard
  ];
in
{
  config = lib.mkIf sddmAstronautThemeEnabled {
    # === Part 1: SDDM Theming Configuration (Unchanged) ===
    services.displayManager.sddm = {
      theme = "sddm-astronaut-theme";
      extraPackages = with pkgs; [
        sddm-astronaut-custom
        kdePackages.qtmultimedia
        kdePackages.qtsvg
        kdePackages.qtvirtualkeyboard
      ];
    };

    environment.systemPackages = [
      sddm-astronaut-custom
    ];

    # === Part 2: Definitive Idle Service with Correct Process Control ===
    systemd.user.services.sddm-screensaver = lib.mkIf sddmScreensaverEnabled {
      wantedBy = [ "graphical-session.target" ];
      
      # This script correctly backgrounds the greeter and uses a PID file to kill it.
      # The '-w' flag is NOT present, which is critical.
      script = ''
        ${pkgs.swayidle}/bin/swayidle \
          timeout ${toString (sddmCfg.screensaver.timeout * 60)} \
            '${pkgs.kdePackages.sddm}/bin/sddm-greeter-qt6 --test-mode --theme ${sddm-astronaut-custom}/share/sddm/themes/sddm-astronaut-theme & echo $! > /tmp/sddm_greeter.pid' \
          resume \
            'if [ -f /tmp/sddm_greeter.pid ]; then kill $(cat /tmp/sddm_greeter.pid); rm -f /tmp/sddm_greeter.pid; fi'
      '';

      serviceConfig = {
        # The QML Import Path is still essential and correct.
        Environment = "QML2_IMPORT_PATH=${qmlPaths}";
        Restart = "always";
        RestartSec = "10";
      };
    };
  };
}