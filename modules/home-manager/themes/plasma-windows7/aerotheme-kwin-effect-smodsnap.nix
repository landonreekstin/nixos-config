{ pkgs, lib, aerothemeplasma-src, smoddecoration, buildWithWayland ? false }:

let
  kwinDevPkg = pkgs.kdePackages.kwin.dev;

  # This list contains all dependencies from CMakeLists.txt and our previous lessons.
  buildAndNativeInputs = with pkgs; [
    cmake ninja pkg-config
    kdePackages.extra-cmake-modules 
    kdePackages.kconfigwidgets
    kdePackages.kdecoration
    kdePackages.qtbase
  ] ++ [ kwinDevPkg smoddecoration ]; # Add the two special dependencies

in pkgs.stdenv.mkDerivation {
  pname = "aerotheme-kwin-effect-smodsnap";
  version = "6.3.4";

  src = "${aerothemeplasma-src}/kwin/effects_cpp/kwin-effect-smodsnap-v2";

  dontWrapQtApps = true;
  
  # This remains essential for finding KWin's private headers like "core/output.h"
  NIX_CFLAGS_COMPILE = "-I${kwinDevPkg}/include/kwin";

  nativeBuildInputs = with pkgs; [ cmake ninja pkg-config kdePackages.extra-cmake-modules ];
  buildInputs = buildAndNativeInputs;

  # This configuration is our proven standard now.
  configurePhase = ''
    runHook preConfigure
    cmake -S . -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=$out \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_KF6=ON \
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
      -DKWIN_BUILD_WAYLAND=${if buildWithWayland then "ON" else "OFF"} \
      -DCMAKE_PREFIX_PATH="${lib.concatStringsSep ";" buildAndNativeInputs}"
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