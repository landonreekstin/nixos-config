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
    qtbase qtdeclarative qtsvg qtmultimedia ki18n kwindowsystem
    kconfig ksvg kcoreaddons qt5compat qttools kirigami
    kiconthemes kauth kcrash kcmutils knewstuff kio knotifications
    knotifyconfig attica krunner kglobalaccel kguiaddons kdbusaddons
    kwidgetsaddons kcodecs sonnet kpackage kxmlgui libplasma
    plasma5support plasma-activities plasma-activities-stats
  ];

  allDeps = nativeBuildInputs ++ buildInputs;

in pkgs.stdenv.mkDerivation {
  pname = "aerotheme-plasmoid-sevenstart";
  version = "6.3.4";

  src = "${aerothemeplasma-src}/plasma/plasmoids/src/sevenstart_src";

  inherit nativeBuildInputs buildInputs;
  dontWrapQtApps = true;

  # This patch is still necessary to remove the broken hardcoded /usr/include line.
  postPatch = ''
    echo "Patching src/CMakeLists.txt to remove hardcoded include_directories()..."
    sed -i 's|include_directories(/usr/include/Plasma.*)|# &|' src/CMakeLists.txt
  '';

  # --- THE FINAL FIX ---
  # We provide both required include paths directly to the compiler.
  # This solves both the "Plasma/Applet" and "plasmaquick/dialog.h" errors.
  NIX_CFLAGS_COMPILE = "-I${pkgs.kdePackages.libplasma.dev}/include/Plasma -I${pkgs.kdePackages.libplasma.dev}/include/PlasmaQuick";

  # Standard configure/build/install phases that are proven to work.
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
    mkdir -p $out/share/plasma/plasmoids/io.gitgud.wackyideas.SevenStart

    # Now, copy the QML UI files from the source to the newly created directory
cp -r ${aerothemeplasma-src}/plasma/plasmoids/io.gitgud.wackyideas.SevenStart/. $out/share/plasma/plasmoids/io.gitgud.wackyideas.SevenStart/
  runHook postInstall  '';
}