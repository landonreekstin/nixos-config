{ pkgs, lib, aerothemeplasma-src, buildWithWayland ? false }:

let
  kwinDevPkg = pkgs.kdePackages.kwin.dev;

  buildAndNativeInputs = with pkgs; [
    cmake ninja pkg-config wayland wayland-protocols
    kdePackages.extra-cmake-modules kdePackages.kconfig kdePackages.kconfigwidgets
    kdePackages.kcoreaddons kdePackages.kcrash kdePackages.ki18n kdePackages.kio
    kdePackages.kservice kdePackages.knotifications kdePackages.kwidgetsaddons
    kdePackages.kwindowsystem kdePackages.kguiaddons kdePackages.kcmutils
    kdePackages.ksvg kdePackages.kdecoration
    kdePackages.qtbase kdePackages.qttools
    libepoxy xorg.libX11 xorg.libxcb
  ] ++ [ kwinDevPkg ];

in pkgs.stdenv.mkDerivation {
  pname = "aerotheme-kwin-effect-startupfeedback";
  version = "6.3.4";

  src = "${aerothemeplasma-src}/kwin/effects_cpp/startupfeedback";

  dontWrapQtApps = true;
  
  NIX_CFLAGS_COMPILE = "-I${kwinDevPkg}/include/kwin";

  # --- CORRECTED SECTION ---
  # This postPatch hook correctly removes the hardcoded set commands AND
  # the multi-line include_directories command that uses them.
  postPatch = ''
    echo "Patching CMakeLists.txt to remove all hardcoded /usr/include logic..."
    # Remove the variable definitions
    sed -i '/^set(KPLUGINFACTORY_INCLUDE/d' ./CMakeLists.txt
    sed -i '/^set(KCONFIGCORE_INCLUDE/d' ./CMakeLists.txt
    
    # Find the line starting with 'include_directories(',
    # append the Next line to the buffer, and then delete both.
    sed -i '/^include_directories(/{N;d;}' ./CMakeLists.txt
  '';

  nativeBuildInputs = with pkgs; [ cmake ninja pkg-config wayland wayland-protocols kdePackages.extra-cmake-modules ];
  buildInputs = buildAndNativeInputs;

  configurePhase = ''
    runHook preConfigure
    cmake -S . -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=$out \
      -DCMAKE_BUILD_TYPE=Release \
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