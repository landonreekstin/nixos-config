{ pkgs, lib, config, customConfig, inputs, ...}:

let
  plasmaWindows7Condition = (customConfig.programs.kde.enable && customConfig.homeManager.enable && customConfig.homeManager.themes.kde == "windows7");

  aerothemeplasma-src = pkgs.fetchgit {
    url = "https://gitgud.io/wackyideas/AeroThemePlasma.git";
    rev = "master";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  segoe-ui-font = pkgs.stdenv.mkDerivation {
      pname = "segoe-ui-font";
      version = "latest";
      src = pkgs.fetchurl {
          # This is the correct "raw" URL for the single font file
          url = "https://raw.githubusercontent.com/MauCariApa-com/windows-11-fonts/main/w11-fonts/segoeui.ttf";
          # As before, we must find the new hash.
          sha256 = "sha256-dPKz0MIM9zgOsSGgn9fN/cHM3RKgDbg8rsD+tItNufc=";
      };

      dontUnpack = true;

      # We don't need unzip anymore
      nativeBuildInputs = [ ]; 

      # The installPhase is now simpler
      installPhase = ''
          # Create the destination directory
          mkdir -p $out/share/fonts/truetype
          # Copy the downloaded font file ($src) to the destination, giving it the correct name
          install -m 644 $src $out/share/fonts/truetype/segoeui.ttf
      '';
  };

  aerotheme-kwin-decoration = pkgs.callPackage ./aerotheme-kwin-decoration.nix {
    # We pass the main theme source as an argument to our package function.
    inherit aerothemeplasma-src;
  };

  aerotheme-kwin-effect-aeroglide = pkgs.callPackage ./aerotheme-kwin-effect-aeroglide.nix {
    inherit aerothemeplasma-src;
    # By default, this builds for X11.
    # To build for Wayland, you would add: buildWithWayland = true;
    buildWithWayland = true;
  };

  aerotheme-kwin-effect-smodsnap = pkgs.callPackage ./aerotheme-kwin-effect-smodsnap.nix {
    inherit aerothemeplasma-src;
    smoddecoration = aerotheme-kwin-decoration;
  };

  aerotheme-kwin-effect-smodglow = pkgs.callPackage ./aerotheme-kwin-effect-smodglow.nix {
    inherit aerothemeplasma-src;
    smoddecoration = aerotheme-kwin-decoration;
  };

  aerotheme-kwin-effect-startupfeedback = pkgs.callPackage ./aerotheme-kwin-effect-startupfeedback.nix {
    inherit aerothemeplasma-src;
  };

  aerotheme-plasmoid-desktopcontainment = pkgs.callPackage ./aerotheme-plasmoid-desktopcontainment.nix {
    inherit aerothemeplasma-src;
  };

  aerotheme-plasmoid-seventasks = pkgs.callPackage ./aerotheme-plasmoid-seventasks.nix {
    inherit aerothemeplasma-src;
  };

  aerotheme-plasmoid-sevenstart = pkgs.callPackage ./aerotheme-plasmoid-sevenstart.nix {
    inherit aerothemeplasma-src;
  };

  aerotheme-polkit-agent = pkgs.callPackage ./aerotheme-polkit-agent.nix {
    inherit aerothemeplasma-src;
  };

  aerotheme-plasmoid-volume = pkgs.callPackage ./aerotheme-plasmoid-volume.nix {
    inherit aerothemeplasma-src;
  };

  # This is the new, safe asset package derivation
aerotheme-assets = pkgs.stdenv.mkDerivation {
  pname = "aerotheme-assets";
  version = "6.3.4";
  src = aerothemeplasma-src;

  nativeBuildInputs = [ pkgs.gnutar ]; # No need for unzip or coreutils

  dontConfigure = true;
  dontBuild = true;

  # This installPhase cherry-picks all the assets we need and nothing more.
  installPhase = ''
    runHook preInstall
    
    # Kvantum theme
    mkdir -p $out/share/Kvantum
    cp -r $src/misc/kvantum/Kvantum/. $out/share/Kvantum/

    # Sounds, Icons, Cursors, Mimetypes
    mkdir -p $out/share/sounds
    tar -xf $src/misc/sounds/sounds.tar.gz -C $out/share/sounds
    mkdir -p $out/share/icons
    tar -xf $src/misc/icons/*.tar.gz -C $out/share/icons
    tar -xf $src/misc/cursors/*.tar.gz -C $out/share/icons
    mkdir -p $out/share/mime/packages
    cp $src/misc/mimetype/*.xml $out/share/mime/packages/

    # Plasma assets: Color Scheme, Desktop Theme (Style), L&F, Layouts
    mkdir -p $out/share/color-schemes
    cp $src/plasma/color_scheme/*.colors $out/share/color-schemes/
    mkdir -p $out/share/plasma
    cp -r $src/plasma/desktoptheme/. $out/share/plasma/desktoptheme/
    cp -r $src/plasma/look-and-feel/. $out/share/plasma/look-and-feel/
    cp -r $src/plasma/layout-templates/. $out/share/plasma/layout-templates/

    # Install ONLY the non-compiled, QML-based plasmoids
    mkdir -p $out/share/plasma/plasmoids
    # This loop correctly installs the themed widgets that were missing before.
    for dir in $src/plasma/plasmoids/*; do
        local name=$(basename "$dir")
        if [[ "$name" != "src" && "$name" != "io.gitgud.wackyideas.desktopcontainment" && "$name" != "io.gitgud.wackyideas.seventasks" && "$name" != "io.gitgud.wackyideas.SevenStart" && "$name" != "io.gitgud.wackyideas.volume" ]]; then
            cp -r "$dir/." "$out/share/plasma/plasmoids/$name/"
        fi
    done
    
    runHook postInstall
  '';
};

  # Derivation to patch and build the libplasma component for defaulttooltip
  patched-libplasma = pkgs.stdenv.mkDerivation {
    pname = "patched-libplasma-for-aerotheme";
    version = "6.4.0";

    src = pkgs.fetchgit {
      url = "https://invent.kde.org/plasma/libplasma.git";
      rev = "v6.4.0";
      sha256 = "sha256-CgaPzmDu9Ji0fzDceQgpRD59xiVLeI3dSZhpGH2JOnY=";
    };

    dontWrapQtApps = true;

    postPatch = ''
      echo "Copying override files from AeroThemePlasma source..."
      cp ${aerothemeplasma-src}/misc/defaulttooltip/DefaultToolTip.qml ./src/declarativeimports/core/private/
      cp ${aerothemeplasma-src}/misc/defaulttooltip/tooltiparea.h ./src/declarativeimports/core/
      cp ${aerothemeplasma-src}/misc/defaulttooltip/tooltiparea.cpp ./src/declarativeimports/core/
      cp ${aerothemeplasma-src}/misc/defaulttooltip/tooltipdialog.cpp ./src/declarativeimports/core/
      cp ${aerothemeplasma-src}/misc/defaulttooltip/plasmawindow.cpp ./src/plasmaquick/
    '';

    # This is the corrected list of build-time tools.
    nativeBuildInputs = with pkgs; [ 
      cmake 
      ninja 
      pkg-config # The missing tool that finds wayland.xml
      wayland 
      wayland-protocols
      kdePackages.extra-cmake-modules 
    ];
    
    # This is the corrected list of libraries to link against.
    buildInputs = with pkgs; [
      wayland
      kdePackages.qtbase
      kdePackages.qtwayland
      kdePackages.kcmutils
      kdePackages.kconfig
      kdePackages.kcoreaddons
      kdePackages.kdeclarative
      kdePackages.ki18n
      kdePackages.kio
      kdePackages.kirigami
      kdePackages.knotifications
      kdePackages.kpackage
      kdePackages.ksvg
      kdePackages.kwindowsystem
      kdePackages.plasma-activities
      kdePackages.plasma-wayland-protocols
    ];

    # This flag is still essential to prevent RPATH errors later.
    cmakeFlags = [
      "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"
    ];
  };

in
{
  imports = [ inputs.plasma-manager.homeManagerModules.plasma-manager ];

  config = lib.mkIf (plasmaWindows7Condition) {
    systemd.user.services."plasma-polkit-agent" = {
      # This section remains the same
      serviceConfig = {
        # --- THE FIX IS HERE ---
        # Point to the correct path of the executable in the 'bin' directory
        ExecStart = "${aerotheme-polkit-agent}/bin/polkit-kde-authentication-agent-1";
      };
    };

    home.packages = with pkgs; [ 
      # --- COMPILED COMPONENTS ---
      aerotheme-kwin-decoration
      patched-libplasma
      aerotheme-kwin-effect-aeroglide
      aerotheme-kwin-effect-smodsnap
      aerotheme-kwin-effect-smodglow
      aerotheme-kwin-effect-startupfeedback
      aerotheme-plasmoid-desktopcontainment
      aerotheme-plasmoid-seventasks
      aerotheme-plasmoid-sevenstart
      aerotheme-plasmoid-volume
      aerotheme-polkit-agent
      aerotheme-assets

      # --- OTHER PACKAGES ---
      segoe-ui-font 
      kdePackages.qtstyleplugin-kvantum

      #kdePackages.libplasma
    ];

    # We can safely set self-contained variables here.
    home.sessionVariables = {
      QML_DISABLE_DISTANCEFIELD = "1";
    };
    
    home.file.".config/fontconfig/fonts.conf".source =
    "${aerothemeplasma-src}/misc/fontconfig/fonts.conf";

    # Custom branding for the Info Center
    home.file.".config/kdedefaults/kcm-about-distrorc".source =
      "${aerothemeplasma-src}/misc/branding/kcm-about-distrorc";
    home.file.".config/kdedefaults/kcminfo.png".source =
      "${aerothemeplasma-src}/misc/branding/kcminfo.png";


    # --- PLASMA MANAGER CONFIGURATION ---

    programs.plasma = {
      enable = true;
      overrideConfig = true;

      workspace = {
        theme = "Seven-Black"; # Plasma Style
        colorScheme = "AeroColorScheme1";
        iconTheme = "Windows 7 Aero";
        soundTheme = "Windows 7";
        lookAndFeel = "authui7"; # Applies lock screen
        cursor = {
          theme = "aero-drop";
          size = 24;
        };
        # This sets the SMOD window border theme
        windowDecorations = {
          library = "org.kde.kwin.aurorae";
          theme = "__aurorae__svg__smod";
        };
        wallpaper = ../../../../assets/wallpapers/windows7-wallpaper.jpg;
      };

      fonts = {
        general = { family = "Segoe UI"; pointSize = 9; };
        fixedWidth = { family = "Segoe UI"; pointSize = 9; };
        small = { family = "Segoe UI"; pointSize = 9; };
        toolbar = { family = "Segoe UI"; pointSize = 9; };
        menu = { family = "Segoe UI"; pointSize = 9; };
        windowTitle = { family = "Segoe UI"; pointSize = 9; weight = "bold"; };
      };

      # The panel configuration using the correct widget IDs from our built components
      panels = [{
        location = "bottom";
        height = 40;
        widgets = [
          "io.gitgud.wackyideas.SevenStart"
          "io.gitgud.wackyideas.seventasks"
          "org.kde.plasma.panelspacer" # Pushes subsequent items to the right

          # The INSTALL.md says to use a custom systray layout.
          # The theme provides custom plasmoids for these functions.
          "io.gitgud.wackyideas.volume"             # The custom "Sound Mixer"
          "io.gitgud.wackyideas.networkmanagement"  # The custom "Network Management"
          "io.gitgud.wackyideas.battery"            # The custom "Battery"
          "io.gitgud.wackyideas.keyboardlayout"

          "io.gitgud.wackyideas.digitalclocklite"
          "io.gitgud.wackyideas.win7showdesktop"
        ];
      }];

      # --- LOW-LEVEL CONFIGURATION USING `configFile` ---

      # This correctly disables the launch feedback cursor
      configFile."kdeglobals"."KDE"."LaunchFeedback" = "None";

      # This block sets KWin effects and the Alt-Tab switcher style
      configFile."kwinrc" = {
        "Plugins" = {
          "kwin4_effect_aero-glass-blurEnabled" = true;
          "kwin4_effect_desaturate-unresponsiveEnabled" = true;
          "smod-snapEnabled" = true;
          "smod-glowEnabled" = true;
          "seventasks-animationsEnabled" = true;
          "MinimizeAllEnabled" = true;
          "DimAdminModeEnabled" = true;
          "kwin4_effect_maximizeEnabled" = false;
          "kwin4_effect_dialogparentEnabled" = false;
          "backgroundcontrastEnabled" = false;
          "blurEnabled" = false;
          "diminactiveEnabled" = false;
        };
        "TabBox" = { "LayoutName" = "thumbnail_seven"; "ShowDesktop" = true; };
        "TabBox Alternative" = { "LayoutName" = "flipswitch"; };
      };

      # --- THE CORRECTED DESKTOP LAYOUT CONFIGURATION ---
      # This sets the containment plugin for the default desktop (usually ID 1).
      # This is the most robust *declarative* way to set this, but it is less
      # reliable than a manual change if you have a complex multi-screen setup.
      configFile."plasma-org.kde.plasma.desktop-appletsrc"."Containments/1"."plugin" = "io.gitgud.wackyideas.desktopcontainment";
    };
  };
}