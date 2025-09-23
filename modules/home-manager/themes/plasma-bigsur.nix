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
      overrideConfig = cfg.homeManager.themes.plasmaOverride or {};

      workspace = {
        lookAndFeel = "org.kde.whitesur.dark";
        iconTheme = "WhiteSur-dark";
        cursor.theme = "WhiteSur-cursors";
        wallpaper = cfg.homeManager.themes.wallpaper;
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

      panels = [
        # 1. Top Bar
        {
          location = "top";
          height = 32; # A thin top bar
          widgets = [
            # Global Menu provides File, Edit, View, etc. for the active app
            "org.kde.plasma.appmenu"
            "org.kde.plasma.panelspacer" # Pushes widgets to the right
            "org.kde.plasma.systemtray"
            "org.kde.plasma.digitalclock"
          ];
        }
        # 2. Bottom Dock
        {
          location = "bottom";
          height = 56;
          floating = true; # Makes the panel float like a dock
          alignment = "center";
          widgets = [
            "org.kde.plasma.panelspacer" # Left spacer to center the task manager
            {
              # Icon-Only Task Manager is the heart of a dock
              iconTasks = {
                launchers = [
                  "applications:org.kde.dolphin.desktop"
                  "applications:chromium.desktop"
                  "applications:systemsettings.desktop"
                ];
              };
            }
            "org.kde.plasma.panelspacer" # Right spacer
          ];
        }
      ];
    };

    # 4. Configure the Kvantum engine to use the WhiteSur theme internally.
    #    This part is still necessary.
    xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=WhiteSur-Dark
    '';

    # 5. Configure GTK applications for a consistent look.
    gtk = {
      enable = true;
      theme.name = "WhiteSur-dark-solid";
      iconTheme.name = "WhiteSur-dark";
      cursorTheme.name = "WhiteSur-cursors";
    };
  };
}