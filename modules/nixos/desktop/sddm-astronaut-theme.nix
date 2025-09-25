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

    # === Part 2: Final Corrected Wayland Idle Service ===
    systemd.user.services.sddm-screensaver = lib.mkIf sddmScreensaverEnabled {
      wantedBy = [ "graphical-session.target" ];
      
      script = ''
        # The problematic '-w' flag has been REMOVED.
        # This allows swayidle's default behavior to terminate the process on activity.
        ${pkgs.swayidle}/bin/swayidle \
          timeout ${toString (sddmCfg.screensaver.timeout * 60)} \
            '${pkgs.kdePackages.sddm}/bin/sddm-greeter-qt6 --test-mode --theme ${sddm-astronaut-custom}/share/sddm/themes/sddm-astronaut-theme'
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