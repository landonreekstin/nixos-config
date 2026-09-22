{
  stdenv,
  lib,
  fetchzip,
  cmake,
  ninja,
  qt6,
  pkgs,
  makeWrapper,
  gnutar,
  originalLibplasma,
}: let
  # Upstream versions this repo against Plasma, not against itself: tags 6.3.4 /
  # 6.4.4 / 6.5.5, then branches Plasma/6.6 and Plasma/6.7. Each targets that
  # Plasma release's KWin and libplasma APIs, so this rev has to move whenever
  # nixpkgs moves Plasma — it is not a "bump when convenient" pin.
  #
  # 6.3.4 (what we pinned on nixos-25.11) does not compile against the Plasma
  # 6.6.6 in nixos-26.05: KWin 6.6 changed EffectsHandler::paintScreen's
  # signature (QRegion -> KWin::Region, Output* -> LogicalOutput*), so every
  # kwin/effects_cpp component failed with "marked 'override', but does not
  # override".
  #
  # 6.5.5 is the newest rev that still works for us, and it is deliberately NOT
  # the newest rev upstream has. From Plasma/6.6 onward upstream split itself
  # into several repositories — the KWin decoration, the C++ effects and the
  # libplasma patches now live in aeroshell-kwin-components / aeroshell-libplasma
  # / aeroshell-smod etc., and this repo's kwin/ and misc/libplasma directories
  # are simply gone. Moving to Plasma/6.6 therefore means packaging several new
  # upstreams, not bumping a rev; until someone does that, 6.5.5 is what keeps
  # the decoration and the glass effects in the build at all.
  #
  # Note: modules/nixos/themes/windows7-xfce/windows7-xfce-assets.nix pins the
  # same repo at 6.3.4 on purpose. It only extracts images and sounds, compiles
  # nothing, and moving it would change blaney-pc's XFCE look for no reason.
  themeRepo = pkgs.fetchgit {
    url = "https://gitgud.io/wackyideas/AeroThemePlasma.git";
    rev = "50af3b2fc22edbfc452472f7bb111d5584a31f05"; # tag 6.5.5
    sha256 = "sha256-AuQH8lIpG9nnneN48RATI7E8llBLK7YOkKjTOSW3hAM=";
  };

  aerothemeplasma-git = themeRepo;

  # --- The KWin half, which upstream moved out from under us ---
  #
  # Everything in AeroThemePlasma 6.5.5 builds against Plasma 6.6.6 except the
  # five C++ KWin effects, which fail on the same paintScreen/prePaintWindow
  # signature changes (QRegion -> KWin::Region, Output* -> LogicalOutput*, and
  # LogicalOutput losing highDynamicRange/brightnessSetting). They are only fixed
  # in the repositories upstream split them into for Plasma/6.6, so the effects
  # come from there while the rest of the theme stays on the 6.5.5 tag above.
  #
  # Both are version-locked to Plasma the same way themeRepo is: move them
  # together with it whenever nixpkgs moves Plasma.
  kwinComponentsRepo = pkgs.fetchgit {
    url = "https://gitgud.io/aeroshell/aeroshell-kwin-components.git";
    rev = "97cc934b54aa9b237a8b814cb86f93f7d33b5ebf"; # tag v6.6.5
    sha256 = "sha256-L1VJxpwsR2aUQ74MTz8BNgejNI23OTSZe2cvp+/w6NQ=";
  };

  # smodglow did not go to aeroshell-kwin-components with the other four; it
  # lives with the SMOD decoration instead. (We still build the decoration from
  # themeRepo — that one compiles fine on 6.5.5.)
  smodRepo = pkgs.fetchgit {
    url = "https://gitgud.io/aeroshell/smod.git";
    rev = "caa995773984f21928b16f0ba8e122887740bcbe"; # Plasma/6.6
    sha256 = "sha256-iW1WsQK23WyogiEKYQ8KegGqbatUBiAU4LE6VfrWeYE=";
  };

  commonNativeBuildInputs = [
    cmake
    ninja
    pkgs.kdePackages.extra-cmake-modules
    pkgs.kdePackages.wrapQtAppsHook
    pkgs.kdePackages.qttools.dev
    makeWrapper
  ];

  qt6Deps = with pkgs.kdePackages; [
    qtbase
    qtwayland
    qtsvg
    qtmultimedia
    qt5compat
    qtvirtualkeyboard
    qtdeclarative
    qttools
    pkgs.qt6.qtbase.dev
  ];

  kf6Deps = with pkgs.kdePackages; [
    karchive
    kwindowsystem
    kconfig
    kconfigwidgets
    kcoreaddons
    kguiaddons
    kiconthemes
    ki18n
    knotifications
    kio
    kauth
    kdecoration
    kcrash
    kglobalaccel
    kservice
    kwidgetsaddons
    kcompletion
    kxmlgui
    ksvg
    kcmutils
    kpackage
  ];

  kf6DevDeps = with pkgs.kdePackages; [
    kconfig.dev
    kcoreaddons.dev
    kwindowsystem.dev
    kdecoration.dev
    ki18n.dev
    kauth.dev
    kcrash.dev
    kglobalaccel.dev
    knotifications.dev
    kio.dev
    kservice.dev
    kcmutils.dev
    kxmlgui.dev
    kiconthemes.dev
  ];

  plasmaDeps = with pkgs.kdePackages; [
    plasma5support
    plasma-wayland-protocols
    kwin
    kwin.dev
    kirigami
    plasma-activities
    plasma-activities-stats
    libplasma
    libplasma.dev
  ];

  waylandDeps = with pkgs; [
    wayland
    wayland-protocols
    libepoxy
  ];

  x11Deps = with pkgs.xorg; [
    libX11
    libxcb
  ];

  commonCmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DBUILD_KF6=ON"
    "-DKWIN_BUILD_WAYLAND=ON"
    "-DCMAKE_INSTALL_PREFIX=$out"
    "-DKDE_INSTALL_PLUGINDIR=lib/qt-6/plugins" # it's qt-6 on Nix for some reason
    "-DKDE_INSTALL_QMLDIR=lib/qt-6/qml" # no idea why
    "-DKWIN_INCLUDE=${pkgs.kdePackages.kwin.dev}/include/kwin"
    "-DKPLUGINFACTORY_INCLUDE=${pkgs.kdePackages.kcoreaddons.dev}/include/KF6/KCoreAddons"
    ''-DCMAKE_CXX_FLAGS="-I${pkgs.kdePackages.kwin.dev}/include/kwin -I${pkgs.kdePackages.kcoreaddons.dev}/include/KF6/KCoreAddons -I${pkgs.kdePackages.libplasma.dev}/include/Plasma -I${pkgs.kdePackages.libplasma.dev}/include/PlasmaQuick"''
    "-DKWin_DIR=${pkgs.kdePackages.kwin.dev}/lib/cmake/KWin"
    "-DKDE_INSTALL_LOCALEDIR=share/locale/aerotheme" # Prevent translation file collisions
  ];

  customLibplasma = originalLibplasma.overrideAttrs (oldAttrs: {
    postUnpack =
      oldAttrs.postUnpack or ""
      + ''
        cp ${themeRepo}/misc/libplasma/src/declarativeimports/core/private/DefaultToolTip.qml $sourceRoot/src/declarativeimports/core/private/DefaultToolTip.qml
        cp ${themeRepo}/misc/libplasma/src/declarativeimports/core/tooltiparea.h $sourceRoot/src/declarativeimports/core/tooltiparea.h
        cp ${themeRepo}/misc/libplasma/src/declarativeimports/core/tooltiparea.cpp $sourceRoot/src/declarativeimports/core/tooltiparea.cpp
        cp ${themeRepo}/misc/libplasma/src/declarativeimports/core/tooltipdialog.cpp $sourceRoot/src/declarativeimports/core/tooltipdialog.cpp
        cp ${themeRepo}/misc/libplasma/src/plasmaquick/plasmawindow.cpp $sourceRoot/src/plasmaquick/plasmawindow.cpp
        cp ${themeRepo}/misc/libplasma/src/plasmaquick/popupplasmawindow.cpp $sourceRoot/src/plasmaquick/popupplasmawindow.cpp
      '';
  });

  # The SMOD window decoration. It still compiles from themeRepo 6.5.5, but it
  # must NOT come from there: smodglow connects to the decoration's
  # buttonHoverStatus signal, and the Plasma/6.6 smod repo widened that signal
  # from 3 arguments to 5 (adding isFlipped and textureType). Pairing 6.5.5's
  # decoration with Plasma/6.6's smodglow fails to compile in Qt's connect().
  # Decoration and smodglow are one unit — keep them on the same rev.
  decoration = stdenv.mkDerivation {
    name = "aerotheme-decoration";
    src = smodRepo;
    nativeBuildInputs = commonNativeBuildInputs ++ [pkgs.pkg-config];
    buildInputs = qt6Deps ++ kf6Deps ++ kf6DevDeps ++ plasmaDeps ++ waylandDeps ++ x11Deps;
    configurePhase = ''
      cmake -B build -G Ninja ${lib.concatStringsSep " " commonCmakeFlags}
    '';
    buildPhase = ''
      ninja -C build
    '';
    installPhase = ''
      ninja install -C build
    '';
  };

  # smodsnap, startupfeedback, aeroglassblur and aeroglide are ONE derivation now.
  #
  # In AeroThemePlasma each of those had a self-contained CMakeLists we could
  # point at directly. In aeroshell-kwin-components the subdirectories rely on
  # the parent project's find_package() calls — building one standalone dies with
  # `Unknown CMake command "kconfig_add_kcfg_files"` — so the parent is the unit
  # of build. KWIN_INSTALL_MISC=OFF restricts it to add_subdirectory(effects_cpp)
  # and skips the kwin scripts / rules / outline / smod assets, which we already
  # get from themeRepo and would otherwise collide.
  #
  # effects_cpp/CMakeLists.txt picks wayland/ vs x11/ off KWIN_BUILD_WAYLAND,
  # which commonCmakeFlags already sets, so there is no per-effect path here.
  kwinComponents = stdenv.mkDerivation {
    name = "aerotheme-kwin-components";
    src = kwinComponentsRepo;
    nativeBuildInputs = commonNativeBuildInputs ++ [pkgs.pkg-config];
    buildInputs = qt6Deps ++ kf6Deps ++ kf6DevDeps ++ plasmaDeps ++ waylandDeps ++ x11Deps ++ [decoration];
    configurePhase = ''
      cmake -B build -G Ninja ${lib.concatStringsSep " " commonCmakeFlags} \
        -DKWIN_INSTALL_MISC=OFF
    '';
    buildPhase = ''
      ninja -C build
    '';
    installPhase = ''
      ninja install -C build
    '';
  };

  # Kept as names so the overlay, the theme module and CI's target list keep
  # working; all four now resolve to the same combined derivation.
  smodsnap = kwinComponents;
  startupfeedback = kwinComponents;
  aeroglassblur = kwinComponents;
  aeroglide = kwinComponents;

  smodglow = stdenv.mkDerivation {
    name = "aerotheme-smodglow";
    src = "${smodRepo}/smodglow";
    nativeBuildInputs = commonNativeBuildInputs ++ [pkgs.pkg-config];
    buildInputs = qt6Deps ++ kf6Deps ++ kf6DevDeps ++ plasmaDeps ++ waylandDeps ++ x11Deps ++ [decoration];
    configurePhase = ''
      cmake -B build -G Ninja ${lib.concatStringsSep " " commonCmakeFlags}
    '';
    buildPhase = ''
      ninja -C build
    '';
    installPhase = ''
      ninja install -C build
    '';
  };


  seventasks = stdenv.mkDerivation {
    name = "aerotheme-seventasks";
    src = "${themeRepo}/plasma/plasmoids/src/seventasks_src";
    nativeBuildInputs = commonNativeBuildInputs ++ [pkgs.pkg-config];
    buildInputs = qt6Deps ++ kf6Deps ++ kf6DevDeps ++ plasmaDeps;
    configurePhase = ''
      cmake -B build -G Ninja ${lib.concatStringsSep " " commonCmakeFlags}
    '';
    buildPhase = ''
      ninja -C build
    '';
    installPhase = ''
      ninja install -C build
    '';
  };

  sevenstart = stdenv.mkDerivation {
    name = "aerotheme-sevenstart";
    src = "${themeRepo}/plasma/plasmoids/src/sevenstart_src";
    nativeBuildInputs = commonNativeBuildInputs ++ [pkgs.pkg-config];
    buildInputs = qt6Deps ++ kf6Deps ++ kf6DevDeps ++ plasmaDeps;
    
    # Fix hardcoded include paths and API issues
    postPatch = ''
      echo "Patching src/CMakeLists.txt to remove hardcoded include_directories()..."
      sed -i 's|include_directories(/usr/include/Plasma.*)|# &|' src/CMakeLists.txt
    '';
    
    # Add proper include paths.
    #
    # The KF6 entry is not optional padding: libplasma's own <Plasma/Theme>
    # header does `#include <Kirigami/Platform/PlatformTheme>`, so anything
    # pulling in Plasma/theme.h needs Kirigami's headers on the include path
    # too. kdePackages.kirigami is a *wrapper* derivation with no dev output of
    # its own — the headers only exist under .unwrapped.dev — which is why
    # having plain `kirigami` in plasmaDeps is not enough.
    NIX_CFLAGS_COMPILE = lib.concatStringsSep " " [
      "-I${pkgs.kdePackages.libplasma.dev}/include/Plasma"
      "-I${pkgs.kdePackages.libplasma.dev}/include/PlasmaQuick"
      # Two levels, both required: <Kirigami/Platform/PlatformTheme> resolves
      # against include/KF6, and that header's own kirigamiplatform_export.h
      # then pulls <kirigamiplatform_version.h> with angle brackets, which only
      # resolves with the component directory on the path as well.
      "-I${pkgs.kdePackages.kirigami.unwrapped.dev}/include/KF6"
      "-I${pkgs.kdePackages.kirigami.unwrapped.dev}/include/KF6/Kirigami/Platform"
    ];
    
    configurePhase = ''
      cmake -B build -G Ninja ${lib.concatStringsSep " " commonCmakeFlags} \
        -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
        -DBUILD_TESTING=OFF
    '';
    buildPhase = ''
      ninja -C build
    '';
    installPhase = ''
      ninja install -C build
      mkdir -p $out/share/plasma/plasmoids/io.gitgud.wackyideas.SevenStart
      # Create temp directory and copy QML files there first
      mkdir -p $TMPDIR/qml_tmp
      cp -r ${themeRepo}/plasma/plasmoids/io.gitgud.wackyideas.SevenStart/. $TMPDIR/qml_tmp/
      # Make files writable and fix incompatible API usage
      chmod -R u+w $TMPDIR/qml_tmp
      find $TMPDIR/qml_tmp -name "*.qml" -exec sed -i '/highlightNewlyInstalledApps/d' {} +
      # Now copy the fixed files to the output
      cp -r $TMPDIR/qml_tmp/. $out/share/plasma/plasmoids/io.gitgud.wackyideas.SevenStart/
    '';
  };

  desktopcontainment = stdenv.mkDerivation {
    name = "aerotheme-desktopcontainment";
    src = "${themeRepo}/plasma/plasmoids/src/desktopcontainment";
    nativeBuildInputs = commonNativeBuildInputs ++ [pkgs.pkg-config];
    buildInputs = qt6Deps ++ kf6Deps ++ kf6DevDeps ++ plasmaDeps ++ [pkgs.kdePackages.knotifyconfig pkgs.kdePackages.krunner];
    postPatch = ''
      sed -i 's/ecm_find_qmlmodule(org.kde.kirigami REQUIRED)/ecm_find_qmlmodule(org.kde.kirigami)/' CMakeLists.txt
    '';
    # TODO: find a better way to do this than faking a cmake module
    configurePhase = ''
      mkdir -p $TMPDIR/cmake-modules
      cat > $TMPDIR/cmake-modules/Findorg.kde.kirigami-QMLModule.cmake <<EOF
        set(org_kde_kirigami_QMLModule_FOUND TRUE)
        set(org_kde_kirigami_QMLModule_DIR "${pkgs.kdePackages.kirigami}/lib/qt-6/qml/org/kde/kirigami")
        message(STATUS "Found org.kde.kirigami-QMLModule")
      EOF
      export CMAKE_MODULE_PATH=$TMPDIR/cmake-modules:$CMAKE_MODULE_PATH
      cmake -B build -G Ninja ${lib.concatStringsSep " " commonCmakeFlags}
    '';
    buildPhase = ''
      ninja -C build
    '';
    installPhase = ''
      ninja install -C build
    '';
  };

  volume = stdenv.mkDerivation {
    name = "aerotheme-volume";
    src = "${themeRepo}/plasma/plasmoids/src/volume_src";
    nativeBuildInputs = commonNativeBuildInputs ++ [pkgs.pkg-config];
    buildInputs = qt6Deps ++ kf6Deps ++ kf6DevDeps ++ plasmaDeps ++ waylandDeps;
    configurePhase = ''
      cmake -B build -G Ninja ${lib.concatStringsSep " " commonCmakeFlags}
    '';
    buildPhase = ''
      ninja -C build
    '';
    installPhase = ''
      ninja install -C build
    '';
  };

  # Upstream rewrote this between 6.3.4 and 6.5.5: it used to be a pure-QML
  # drop-in at plasma/plasmoids/org.kde.plasma.notifications that we just copied,
  # and it is now a compiled C++ applet (io.gitgud.wackyideas.notifications) under
  # plasma/plasmoids/src/. So it builds like seventasks/sevenstart now rather than
  # being copied — the old path does not exist at this rev at all.
  #
  # The extra buildInputs are what the rewritten applet's find_package() calls
  # need and no other component here does: LibNotificationManager (whose cmake
  # config ships in plasma-workspace's dev output) and KF6NotifyConfig.
  notifications = stdenv.mkDerivation {
    name = "aerotheme-notifications";
    src = "${themeRepo}/plasma/plasmoids/src/notifications_src";
    nativeBuildInputs = commonNativeBuildInputs ++ [pkgs.pkg-config];
    buildInputs = qt6Deps ++ kf6Deps ++ kf6DevDeps ++ plasmaDeps ++ [
      pkgs.kdePackages.plasma-workspace
      pkgs.kdePackages.plasma-workspace.dev
      pkgs.kdePackages.knotifyconfig
      pkgs.kdePackages.knotifyconfig.dev
    ];
    configurePhase = ''
      cmake -B build -G Ninja ${lib.concatStringsSep " " commonCmakeFlags}
    '';
    buildPhase = ''
      ninja -C build
    '';
    installPhase = ''
      ninja install -C build
    '';
  };

  kcmloader = stdenv.mkDerivation {
    name = "aerotheme-kcmloader";
    src = "${themeRepo}/plasma/aerothemeplasma-kcmloader";
    nativeBuildInputs = commonNativeBuildInputs;
    buildInputs = qt6Deps ++ kf6Deps ++ kf6DevDeps ++ [ pkgs.kdePackages.kcmutils pkgs.kdePackages.qtbase pkgs.kdePackages.qttools ];
    configurePhase = ''
      cmake -B build -G Ninja ${lib.concatStringsSep " " commonCmakeFlags}
    '';
    buildPhase = ''
      ninja -C build
    '';
    installPhase = ''
      ninja install -C build
    '';
  };

  aerothemeplasma = stdenv.mkDerivation {
    name = "aerothemeplasma";
    src = themeRepo;
    nativeBuildInputs = [gnutar pkgs.gtk3]; # Add gtk3 for gtk-update-icon-cache
    installPhase = ''
      mkdir -p $out/share/plasma/desktoptheme \
        $out/share/plasma/look-and-feel \
        $out/share/plasma/plasmoids \
        $out/share/plasma/layout-templates \
        $out/share/plasma/shells \
        $out/share/kwin/effects \
        $out/share/kwin/tabbox \
        $out/share/kwin/outline \
        $out/share/kwin/scripts \
        $out/share/color-schemes \
        $out/share/Kvantum \
        $out/share/sddm/themes \
        $out/share/mime/packages \
        $out/share/icons/Windows\ 7\ Aero \
        $out/share/sounds/Windows\ 7 \
        $out/share/icons

      [ -d "$src/plasma/desktoptheme" ] && cp -r "$src/plasma/desktoptheme"/* $out/share/plasma/desktoptheme/
      [ -d "$src/plasma/look-and-feel" ] && cp -r "$src/plasma/look-and-feel"/* $out/share/plasma/look-and-feel/
      [ -d "$src/plasma/plasmoids" ] && cp -r "$src/plasma/plasmoids"/* $out/share/plasma/plasmoids/
      [ -d "$src/plasma/layout-templates" ] && cp -r "$src/plasma/layout-templates"/* $out/share/plasma/layout-templates/
      [ -d "$src/plasma/shells" ] && cp -r "$src/plasma/shells"/* $out/share/plasma/shells/
      [ -d "$src/kwin/effects" ] && cp -r "$src/kwin/effects"/* $out/share/kwin/effects/
      [ -d "$src/kwin/tabbox" ] && cp -r "$src/kwin/tabbox"/* $out/share/kwin/tabbox/
      [ -d "$src/kwin/outline" ] && cp -r "$src/kwin/outline"/* $out/share/kwin/outline/
      [ -d "$src/kwin/scripts" ] && cp -r "$src/kwin/scripts"/* $out/share/kwin/scripts/
      [ -d "$src/plasma/color_scheme" ] && cp "$src/plasma/color_scheme"/*.colors $out/share/color-schemes/
      [ -d "$src/misc/kvantum/Kvantum" ] && cp -r "$src/misc/kvantum/Kvantum"/* $out/share/Kvantum/
      [ -d "$src/plasma/smod" ] && cp -r "$src/plasma/smod" $out/share/smod
      [ -d "$src/plasma/sddm/sddm-theme-mod" ] && cp -r "$src/plasma/sddm/sddm-theme-mod" $out/share/sddm/themes/
      [ -d "$src/misc/mimetype" ] && cp -r "$src/misc/mimetype"/* $out/share/mime/packages/
      [ -f "$src/misc/cursors/aero-drop.tar.gz" ] && tar -xzf "$src/misc/cursors/aero-drop.tar.gz" -C $out/share/icons
      [ -f "$src/misc/icons/Windows 7 Aero.tar.gz" ] && tar -xzf "$src/misc/icons/Windows 7 Aero.tar.gz" -C $out/share/icons
      [ -f "$src/misc/sounds/sounds.tar.gz" ] && tar -xzf "$src/misc/sounds/sounds.tar.gz" -C $out/share/sounds

      # Validate and cache the icon theme (--ignore-theme-index: theme has no index.theme)
      gtk-update-icon-cache --ignore-theme-index $out/share/icons/Windows\ 7\ Aero
    '';
    meta = {
      description = "Windows 7 theme for KDE Plasma";
      license = lib.licenses.gpl3;
      platforms = lib.platforms.linux;
    };
  };
in {
  inherit decoration smodsnap smodglow startupfeedback aeroglassblur aeroglide aerothemeplasma aerothemeplasma-git seventasks sevenstart desktopcontainment volume notifications;
  # kcmloader temporarily disabled due to build issues
}
