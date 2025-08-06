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
    # Start with our successful template's dependencies
    qtbase qtdeclarative qtsvg qtmultimedia ki18n kwindowsystem
    kconfig ksvg kcoreaddons qt5compat qttools kirigami
    kiconthemes kauth kcrash kcmutils knewstuff kio knotifications
    knotifyconfig attica krunner kglobalaccel kguiaddons kdbusaddons
    kwidgetsaddons kcodecs sonnet kpackage kxmlgui libplasma
    plasma5support plasma-activities plasma-activities-stats

    # --- ADD NEW DEPENDENCIES for volume_src ---
    qtwayland
    plasma-wayland-protocols
    pkgs.wayland # This one is not in kdePackages
  ];

  allDeps = nativeBuildInputs ++ buildInputs;

in pkgs.stdenv.mkDerivation {
  pname = "aerotheme-plasmoid-volume";
  version = "6.3.4";

  # Use the direct pathing pattern that works.
  src = "${aerothemeplasma-src}/plasma/plasmoids/src/volume_src";

  inherit nativeBuildInputs buildInputs;
  dontWrapQtApps = true;

  # Patch out the broken hardcoded /usr/include line.
  postPatch = ''
    echo "Patching src/CMakeLists.txt to remove hardcoded include_directories()..."
    sed -i 's|include_directories(/usr/include/Plasma.*)|# &|' src/CMakeLists.txt
  '';

  # Proactively provide the correct include paths to prevent "No such file or directory".
  NIX_CFLAGS_COMPILE = "-I${pkgs.kdePackages.libplasma.dev}/include/Plasma -I${pkgs.kdePackages.libplasma.dev}/include/PlasmaQuick";

  # Use the standard, proven configure/build/install phases.
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
    mkdir -p $out/share/plasma/plasmoids/io.gitgud.wackyideas.volume
  
    # Now, copy the QML UI files from the source to the newly created directory
    cp -r ${aerothemeplasma-src}/plasma/plasmoids/io.gitgud.wackyideas.volume/. $out/share/plasma/plasmoids/io.gitgud.wackyideas.volume/
    runHook postInstall
  '';
}