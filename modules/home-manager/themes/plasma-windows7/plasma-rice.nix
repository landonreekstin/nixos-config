{ pkgs, lib, customConfig, inputs, ...}:

let
    # Check if KDE, home-manager, and Plasma Windows 7 theme are enabled for the host
    plasmaWindows7Condition = (customConfig.programs.kde.enable && customConfig.homeManager.enable && customConfig.homeManager.themes.kde == "windows7");

    # Correctly fetch the theme source using a stable git tag
    aerothemeplasma = pkgs.fetchgit {
      url = "https://gitgud.io/wackyideas/AeroThemePlasma.git";
      # Use the stable tag for version 6.3.4 instead of a specific commit
      rev = "6.3.4";
      # This is a placeholder. The build will fail and give you the correct hash.
      sha256 = "sha256-PGWpLKXanZ+miN9dE0+SThTAGutFdHMMRmCNcD5myx8=";
    };

in
{
    imports = [
        inputs.plasma-manager.homeManagerModules.plasma-manager
    ];

    config = lib.mkIf (plasmaWindows7Condition) {
        # Install Kvantum engine to render the theme
        home.packages = with pkgs; [
            libsForQt5.qtstyleplugin-kvantum
        ];

        # Link files from the fetched theme into the correct locations
        home.file = {
            ".config/Kvantum/Aero".source = "${aerothemeplasma}/Kvantum/Aero";
            ".local/share/color-schemes/Aero.colors".source = "${aerothemeplasma}/color-schemes/Aero.colors";
            ".local/share/aurorae/themes/Aero".source = "${aerothemeplasma}/aurorae/themes/Aero";
            ".local/share/plasma/desktoptheme/Aero".source = "${aerothemeplasma}/plasma/desktoptheme/Aero";
            ".local/share/icons/Windows-7-icons".source = "${aerothemeplasma}/icons/Windows-7-icons";

            # Configure Kvantum to use the new theme
            ".config/Kvantum/kvantum.kvconfig".text = ''
                [General]
                theme=Aero
            '';
        };

        # Tell plasma-manager to use the new themes by their names
        programs.plasma = {
            enable = true;
            workspace = {
                # We are setting the components individually instead of using a global lookAndFeel
                theme = "Aero"; # Plasma Style for panels and widgets
                colorScheme = "Aero";
                iconTheme = "Windows-7-icons";
                windowDecorations = {
                  theme = "Aero";
                  library = "org.kde.kwin.aurorae"; # Set the engine for the window decorations
                };
            };
            # Add this new section to define your panel
            panels = [
              {
                # You can also set location = "top"; height = 36; etc. here if you wish
                widgets = [
                  "org.kde.plasma.kickoff"          # The standard Application Launcher (Start Menu)
                  "org.kde.plasma.icontasks"        # The Task Manager for open/pinned apps
                  "org.kde.plasma.marginsseparator" # A flexible separator
                  "org.kde.plasma.systemtray"       # The System Tray for network, volume, etc.
                  "org.kde.plasma.digitalclock"     # The Clock
                  "org.kde.plasma.showdesktop"      # The "Show Desktop" button
                ];
              }
            ];
        };

        # Set the Application Style for other Qt apps (Dolphin, etc.) to use Kvantum
        qt.style = {
            name = "kvantum";
            package = pkgs.libsForQt5.qtstyleplugin-kvantum;
        };
    };
}
