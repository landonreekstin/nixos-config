{ pkgs, lib, aerothemeplasma-src }:

pkgs.stdenv.mkDerivation {
  pname = "aerotheme-patched-polkit-agent";
  version = pkgs.kdePackages.polkit-kde-agent-1.version;

  src = pkgs.kdePackages.polkit-kde-agent-1.src;

  nativeBuildInputs = with pkgs; with kdePackages; [
    cmake
    ninja
    extra-cmake-modules
    pkg-config
    wrapQtAppsHook
  ];

  buildInputs = with pkgs; with kdePackages; [
    qtbase
    qtdeclarative
    qtsvg
    kcoreaddons
    ki18n
    kiconthemes
    kwidgetsaddons
    kdbusaddons
    kwindowsystem
    polkit-qt-1

    # --- THE FIX IS HERE ---
    # Adding the two missing dependencies reported by CMake.
    knotifications
    kcrash
  ];

  # This logic is correct.
  postUnpack = ''
    cp -r ${aerothemeplasma-src}/misc/uac-polkitagent/patches/* .
  '';

  # This logic is also correct.
  configurePhase = ''
    runHook preConfigure
    cmake -S . -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=$out \
      -DCMAKE_BUILD_TYPE=Release
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
    runHook postInstall
  '';
}