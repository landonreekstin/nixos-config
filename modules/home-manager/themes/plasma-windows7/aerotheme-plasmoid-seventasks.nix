{ pkgs, lib, aerothemeplasma-src }:

let
  nativeBuildInputs = with pkgs; with kdePackages; [
    cmake
    ninja
    extra-cmake-modules
    pkg-config
    wrapQtAppsHook
    
    # This hook automatically finds and patches the RPATH of compiled binaries.
    # It's essential for making sure our plasmoid can find its libraries.
    autoPatchelfHook 
  ];

  buildInputs = with pkgs.kdePackages; [
    qtbase qtdeclarative qtsvg qtmultimedia ki18n kwindowsystem
    kconfig ksvg kcoreaddons qt5compat qttools kirigami
    kiconthemes kauth kcrash kcmutils knewstuff kio knotifications
    knotifyconfig attica krunner kglobalaccel kguiaddons kdbusaddons
    kwidgetsaddons kcodecs sonnet kpackage kxmlgui libplasma
    plasma5support plasma-activities plasma-activities-stats

    # --- THE CORRECT, BUILD-TIME FIX ---
    # By including plasma-workspace here, the build process will link against it
    # and autoPatchelfHook will write the correct library paths into the
    # compiled plasmoid files themselves. This removes the need for any
    # runtime environment variable hacks.
    plasma-workspace 
  ];

  allDeps = nativeBuildInputs ++ buildInputs;

in pkgs.stdenv.mkDerivation {
  pname = "aerotheme-plasmoid-seventasks";
  version = "6.3.4";

  src = "${aerothemeplasma-src}/plasma/plasmoids/src/seventasks_src";

  inherit nativeBuildInputs buildInputs;
  dontWrapQtApps = true;

  postPatch = ''
    echo "Patching src/CMakeLists.txt to remove hardcoded include_directories()..."
    sed -i 's|include_directories(/usr/include/Plasma.*)|# &|' src/CMakeLists.txt
  '';

  # Standard phases are fine now that the dependencies are correct.
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
    mkdir -p $out/share/plasma/plasmoids/io.gitgud.wackyideas.seventasks
    cp -r ${aerothemeplasma-src}/plasma/plasmoids/io.gitgud.wackyideas.seventasks/. $out/share/plasma/plasmoids/io.gitgud.wackyideas.seventasks/
    runHook postInstall
  '';
}