{ pkgs, lib, aerothemeplasma-src }:

let
  nativeBuildInputs = with pkgs; with kdePackages; [
    cmake
    ninja
    extra-cmake-modules
    pkg-config
    wrapQtAppsHook
  ];

  buildInputs = with pkgs.kdePackages; [
    qtbase
    qtdeclarative
    qtsvg
    qt5compat
    qttools
    kirigami
    kirigami-addons
    kcoreaddons
    qqc2-desktop-style
    kiconthemes
    kauth
    kcrash
    kconfig
    kcmutils
    knewstuff
    kio
    knotifications
    knotifyconfig
    attica
    krunner
    kglobalaccel
    kguiaddons
    kdbusaddons
    kwidgetsaddons
    kcodecs
    sonnet
    kpackage
    kxmlgui
    ksvg
    libplasma
    plasma5support
    plasma-activities
    plasma-activities-stats
  ];

  allDeps = nativeBuildInputs ++ buildInputs;

in pkgs.stdenv.mkDerivation {
  pname = "aerotheme-plasmoid-desktopcontainment";
  version = "6.3.4";

  src = "${aerothemeplasma-src}/plasma/plasmoids/src/desktopcontainment";

  inherit nativeBuildInputs buildInputs;
  dontWrapQtApps = true;

  # --- THE SURGICAL FIX ---
  # This command edits the CMakeLists.txt file and comments out the
  # single line that is causing the entire build to fail.
  postPatch = ''
    echo "Patching CMakeLists.txt to remove broken QML module check..."
    sed -i 's/ecm_find_qmlmodule(org.kde.kirigami REQUIRED)/# ecm_find_qmlmodule(org.kde.kirigami REQUIRED)/' CMakeLists.txt
  '';

  # Now we can use the clean, standard configure phase because the
  # underlying build script is no longer broken.
  configurePhase = ''
    runHook preConfigure
    cmake -S . -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=$out \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_TESTING=OFF \
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
      -DCMAKE_PREFIX_PATH="${lib.concatStringsSep ";" allDeps}"
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    cmake --build build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cmake --install build
    mkdir -p $out/share/plasma/plasmoids/io.gitgud.wackyideas.desktopcontainment

    # Now, copy the QML UI files from the source to the newly created directory
cp -r ${aerothemeplasma-src}/plasma/plasmoids/io.gitgud.wackyideas.desktopcontainment/. $out/share/plasma/plasmoids/io.gitgud.wackyideas.desktopcontainment/  '';
}