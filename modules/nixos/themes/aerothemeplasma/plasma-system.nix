{
  config,
  pkgs,
  lib,
  ...
}:

let
  aerothemeCondition = (lib.elem "kde" config.customConfig.desktop.environments
    && config.customConfig.homeManager.themes.kde == "windows7-alt");
in {
  config = lib.mkIf aerothemeCondition {
  nixpkgs.overlays = [
    (final: prev: let
      # Build packages using prev (before overlay) to avoid recursion
      aerothemePkgs = prev.callPackage ./aerothemeplasma.nix {
        originalLibplasma = prev.kdePackages.libplasma;
      };
    in {
      kdePackages =
        prev.kdePackages;
      # Make aerotheme packages available in the final package set
      inherit (aerothemePkgs) decoration smodsnap smodglow startupfeedback aeroglassblur aeroglide aerothemeplasma aerothemeplasma-git seventasks sevenstart desktopcontainment volume notifications;
    })
  ];

  # Rest of your configuration remains unchanged
  environment.sessionVariables = {
    QT_PLUGIN_PATH = "${pkgs.aerothemeplasma}/lib/qt-6/plugins:${pkgs.decoration}/lib/qt-6/plugins:${pkgs.sevenstart}/lib/qt-6/plugins:${pkgs.volume}/lib/qt-6/plugins:${lib.makeSearchPath "lib/qt-6/plugins" [pkgs.kdePackages.qtmultimedia]}:$QT_PLUGIN_PATH";
    QML2_IMPORT_PATH = "${pkgs.aerothemeplasma}/lib/qt-6/qml:${pkgs.desktopcontainment}/lib/qt-6/qml:${lib.makeSearchPath "lib/qt-6/qml" [pkgs.kdePackages.qtmultimedia pkgs.kdePackages.qtvirtualkeyboard pkgs.kdePackages.qtsvg]}:$QML2_IMPORT_PATH";
    QML_DISABLE_DISTANCEFIELD = "1";
  };

  environment.systemPackages = with pkgs; [
    decoration
    smodsnap
    smodglow
    startupfeedback
    aeroglassblur
    aeroglide
    (lib.hiPrio aerothemeplasma) # High priority to override default KDE files
    seventasks
    sevenstart
    desktopcontainment
    volume
    notifications
    # kcmloader # temporarily disabled due to build issues

    kdePackages.qtstyleplugin-kvantum
    kdePackages.plasma5support
    kdePackages.kdeplasma-addons
    kdePackages.sddm-kcm
    kdePackages.plasma-browser-integration
    kdePackages.partitionmanager
    kdePackages.qttools
    kdePackages.qtvirtualkeyboard
    kdePackages.qt5compat
    kdePackages.plasma-wayland-protocols
    kdePackages.extra-cmake-modules
    kdePackages.qtbase
    kdePackages.qtquick3d
    kdePackages.qtquicktimeline
    kdePackages.qtquick3dphysics
    kdePackages.qtdeclarative

    shared-mime-info
    kdePackages.kitemmodels
    kdePackages.kitemviews
    kdePackages.knewstuff
    kdePackages.kcmutils
    kdePackages.plasma-workspace
  ];

  system.activationScripts.updateMimeDatabase = lib.stringAfter ["etc"] ''
    mkdir -p /etc/xdg/mime/packages
    ${pkgs.shared-mime-info}/bin/update-mime-database /etc/xdg/mime
  '';

  services.desktopManager.plasma6 = {
    enable = true;
    enableQt5Integration = false;
  };
  services.xserver = {
    enable = true;
  };
  services.displayManager.sddm = {
    enable = true;
    theme = if config.customConfig.desktop.displayManager.sddm.theme == "sddm-windows7" then "sddm-theme-mod" else config.customConfig.desktop.displayManager.sddm.theme;
    
    # Fix QtMultimedia missing error by providing necessary packages
    extraPackages = [
      pkgs.kdePackages.qtmultimedia
      pkgs.kdePackages.qtsvg
      pkgs.kdePackages.qtvirtualkeyboard
    ];
    
    # Ensure startup sound can play by removing startup file before each session
    setupScript = ''
      rm -f /tmp/sddm.startup
    '';
    
    settings = {
      General = {
        HideShells = "/run/current-system/sw/bin/nologin";
        HideUsers = "nixbld1,nixbld2,nixbld3,nixbld4,nixbld5,nixbld6,nixbld7,nixbld8,nixbld9,nixbld10,nixbld11,nixbld12,nixbld13,nixbld14,nixbld15,nixbld16,nixbld17,nixbld18,nixbld19,nixbld20,nixbld21,nixbld22,nixbld23,nixbld24,nixbld25,nixbld26,nixbld27,nixbld28,nixbld29,nixbld30,nixbld31,nixbld32";
      };
      Theme = {
        CursorTheme = "aero-drop";
        forceUserSelect = "true";
        enableStartup = "false";
        playSound = "true";
      };
    };
  };

  fonts = {
    packages = with pkgs; [
      corefonts
      vistafonts
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        sansSerif = ["Segoe UI"];
        serif = ["Segoe UI"];
        monospace = ["Hack"];
      };
    };
  };
  }; # close config block
}