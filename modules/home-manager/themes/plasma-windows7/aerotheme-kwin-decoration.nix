{ pkgs, lib, aerothemeplasma-src }:

let
  kdeDeps = with pkgs.kdePackages; [
    extra-cmake-modules
    kcoreaddons
    kcolorscheme
    kconfig
    kguiaddons
    ki18n
    kiconthemes
    kwindowsystem
    kcmutils
    kdecoration
  ];
  
  allDeps = [ pkgs.kdePackages.qtbase ] ++ kdeDeps;

in
pkgs.stdenv.mkDerivation {
  pname = "aerotheme-kwin-decoration";
  version = "6.3.4";
  
  src = "${aerothemeplasma-src}/kwin/decoration";

  dontWrapQtApps = true;

  nativeBuildInputs = with pkgs; [ cmake ninja ];
  buildInputs = allDeps;

  configurePhase = ''
    runHook preConfigure

    cmake -S . -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=$out \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_QT5=OFF \
      -DBUILD_TESTING=OFF \
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
    runHook postInstall
  '';
}