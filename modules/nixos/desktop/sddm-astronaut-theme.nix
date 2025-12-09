# ~/nixos-config/modules/nixos/desktop/sddm-astronaut-theme.nix
{ config, pkgs, lib, ... }:

let
  dmCfg = config.customConfig.desktop.displayManager;
  sddmCfg = dmCfg.sddm;
  customThemeCfg = sddmCfg.customTheme;

  sddmAstronautThemeEnabled = (dmCfg.enable)
                            && (dmCfg.type == "sddm")
                            && (sddmCfg.theme == "sddm-astronaut");

  sddmScreensaverEnabled = sddmAstronautThemeEnabled && sddmCfg.screensaver.enable;

  finalSddmAstronautPackage =
    if customThemeCfg.enable then
      let
        # We use the simple and reliable pkgs.writeText function.
        # It takes a filename and a string, and returns a store path.
        customThemeConfFile = pkgs.writeText "custom.conf" config.sddm-astronaut.customThemeContent;
      in
      pkgs.sddm-astronaut.overrideAttrs (oldAttrs: {
        postPatch = ''
          echo "Injecting custom sddm-astronaut theme files..."
          mkdir -p ./Themes
          mkdir -p ./Backgrounds
          # This cp command will now work perfectly.
          cp ${customThemeConfFile} ./Themes/custom.conf
          cp ${customThemeCfg.wallpaper} ./Backgrounds/${builtins.baseNameOf customThemeCfg.wallpaper}
        '';

        installPhase = ''
          runHook preInstall
          
          local basePath="$out/share/sddm/themes/sddm-astronaut-theme"
          mkdir -p "$basePath"
          
          cp -r ./* "$basePath"
          
          echo "Forcing metadata to use custom.conf..."
          sed -i "s|^ConfigFile=Themes/.*\\.conf$|ConfigFile=Themes/custom.conf|" "$basePath/metadata.desktop"
          
          runHook postInstall
        '';
      })
    else
      pkgs.sddm-astronaut.override (
        lib.optionalAttrs (sddmCfg.embeddedTheme != null) {
          embeddedTheme = sddmCfg.embeddedTheme;
        }
      );

  qmlPaths = with pkgs.kdePackages; lib.makeSearchPath "lib/qt-6/qml" [ qtmultimedia qtvirtualkeyboard qtsvg ];

  # 2. Define the GStreamer plugins needed for video playback (MP4, etc.)
  gstreamerPlugins = with pkgs.gst_all_1; [
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav # Provides codecs like H.264
  ];

  # 3. Create the search path that GStreamer uses to find its plugins
  gstPath = lib.makeSearchPath "lib/gstreamer-1.0" gstreamerPlugins;

  # Create the search path for Qt to find its backend plugins (like the multimedia backend)
  qtPluginPath = lib.makeSearchPath "lib/qt-6/plugins" [
    pkgs.kdePackages.qtmultimedia
  ];
in
{
  imports = [ ./custom-sddm-theme.nix ];

  config = lib.mkIf sddmAstronautThemeEnabled {
    services.displayManager.sddm = {
      theme = "sddm-astronaut-theme";
      extraPackages = [ finalSddmAstronautPackage ];
    };
    environment.systemPackages = [ finalSddmAstronautPackage ];

    systemd.user.services.sddm-screensaver = lib.mkIf sddmScreensaverEnabled {
      wantedBy = [ "graphical-session.target" ];
      script = ''
        ${pkgs.swayidle}/bin/swayidle \
          timeout ${toString (sddmCfg.screensaver.timeout * 60)} \
            '${pkgs.kdePackages.sddm}/bin/sddm-greeter-qt6 --test-mode --theme ${finalSddmAstronautPackage}/share/sddm/themes/sddm-astronaut-theme & echo $! > /tmp/sddm_greeter.pid' \
          resume \
            'if [ -f /tmp/sddm_greeter.pid ]; then kill $(cat /tmp/sddm_greeter.pid); rm -f /tmp/sddm_greeter.pid; fi'
      '';
      serviceConfig = {
        Environment = [
          "QML2_IMPORT_PATH=${qmlPaths}"
          "GST_PLUGIN_SYSTEM_PATH=${gstPath}"
          "QT_PLUGIN_PATH=${qtPluginPath}"
        ];
        Restart = "always";
        RestartSec = "10";
      };
    };
  };
}