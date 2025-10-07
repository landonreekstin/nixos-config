# ~/nixos-config/modules/home-manager/themes/plasma-bigsur.nix
{ lib, pkgs, config, customConfig, ... }:

let
  cfg = customConfig;
  isKdeEnabled = lib.elem "kde" cfg.desktop.environments;
  isThemeSelected = cfg.homeManager.themes.kde == "bigsur";
in
{
  # This entire module is activated by the custom option in your host config
  config = lib.mkIf (isKdeEnabled && isThemeSelected) {

    # 1. Install the theme packages. The Kvantum engine package is now
    #    handled automatically by the `qt.style` option below.
    home.packages = with pkgs; [
      whitesur-kde
      whitesur-icon-theme
      whitesur-cursors
      whitesur-gtk-theme
      inter # font similar to San Francisco
      kdePackages.sierra-breeze-enhanced
    ];

    # 2. Enable Qt support in Home Manager and set the style to Kvantum.
    #    This is the correct, high-level way you discovered. It installs the
    #    package and sets the environment variables.
    qt = {
      enable = true;
      style = {
        name = "kvantum";
        package = pkgs.kdePackages.qtstyleplugin-kvantum;
      };
    };

    fonts.fontconfig.enable = true;

    # 3. Use plasma-manager to apply the global theme, icons, and cursors.
    programs.plasma = {
      enable = true;
      overrideConfig = cfg.homeManager.themes.plasmaOverride;

      workspace.lookAndFeel = "com.github.vinceliuice.WhiteSur-alt";
      workspace.wallpaper = cfg.homeManager.themes.wallpaper;

      configFile."kwinrc"."Compositing" = {
        Enabled = true;
        Backend = "OpenGL";
      };
     
      # While qt.style sets the environment variable, explicitly setting this
      # in KDE's config file ensures Plasma itself is aware of the change.
      configFile."kdeglobals"."General" = {
        widgetStyle = "kvantum";
      };

      fonts = {
        general     = { family = "Inter"; pointSize = 10; };
        fixedWidth  = { family = "monospace"; pointSize = 10; };
        small       = { family = "Inter"; pointSize = 8; };
        toolbar     = { family = "Inter"; pointSize = 10; };
        menu        = { family = "Inter"; pointSize = 10; };
        windowTitle = { family = "Inter"; pointSize = 10; };
      };

      kwin = {
        # This ensures the blur effect itself is turned on
        effects.blur.enable = true;
        effects.blur.strength = 7;

        #effects.translucency.enable = true;
      };

      panels = [
        # Top Panel
        {
          location = "top";
          height = 32; # A good default height for a top bar

          widgets = [
            # --- Left Side ---
            # The theme will likely make this look like the Apple logo
            "org.kde.plasma.kickoff"
            "org.kde.plasma.appmenu"
            # This spacer pushes everything after it to the right
            "org.kde.plasma.panelspacer"

            # --- Right Side (in order from left to right) ---
            "org.kde.plasma.notifications"
            
            # System Tray with specific items always shown
            {
              systemTray.items.shown = [
                "org.kde.plasma.volume"
                "org.kde.plasma.bluetooth"
                "org.kde.plasma.powerdevil"       # Handles Brightness & Power
                "org.kde.plasma.displayconfiguration"
                "org.kde.plasma.networkmanagement"
              ];
            }
            
            "org.kde.plasma.digitalclock"
          ];
        }
        # 2. Bottom Dock
        {
          location = "bottom";
          height = 56;
          floating = true; # Makes the panel float like a dock
          alignment = "center";
          lengthMode = "fit";

          widgets = [
            {
              # Icon-Only Task Manager is the heart of a dock
              iconTasks = {
                launchers = [
                  "applications:org.kde.konsole.desktop"
                  "applications:systemsettings.desktop"
                  "applications:org.kde.dolphin.desktop"
                  "applications:chromium-browser.desktop" # Corrected name
                  "applications:net.lutris.Lutris.desktop"
                  "applications:com.heroicgameslauncher.hgl.desktop"
                  "applications:steam.desktop"

                  # --- Flatpaks with Correct Syntax ---
                  "applications:com.discordapp.Discord.desktop"
                  "applications:com.spotify.Client.desktop"
                ];
              };
            }
            "org.kde.plasma.marginsseparator"
            "org.kde.plasma.trash"
          ];
        }
      ];
    };

    # 4. Configure the Kvantum engine to use the WhiteSur theme internally.
    #    This part is still necessary.
    xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=WhiteSur-Light
    '';
  };
}