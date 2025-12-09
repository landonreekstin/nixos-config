{ pkgs, lib, aerothemeplasma-src, buildWithWayland ? false }:

let
  # Use the unified KWin .dev package (KDE 6 doesn't have separate X11/Wayland builds)
  kwinDevPkg = pkgs.kdePackages.kwin.dev;

  # Define the full list of all dependencies.
  buildAndNativeInputs = with pkgs; [
    cmake ninja pkg-config wayland wayland-protocols
    kdePackages.extra-cmake-modules kdePackages.kconfig kdePackages.kconfigwidgets
    kdePackages.kcoreaddons kdePackages.kcrash kdePackages.ki18n kdePackages.kio
    kdePackages.kservice kdePackages.knotifications kdePackages.kwidgetsaddons
    kdePackages.kwindowsystem kdePackages.kguiaddons kdePackages.kcmutils
    kdePackages.ksvg kdePackages.kdecoration
    kdePackages.qtbase kdePackages.qttools
    libepoxy xorg.libX11 xorg.libxcb
  ] ++ [ kwinDevPkg ]; # Add the correct kwin dev package to the list

in pkgs.stdenv.mkDerivation {
  pname = "aerotheme-kwin-effect-aeroglide";
  version = "6.3.4";

  src = "${aerothemeplasma-src}/kwin/effects_cpp/aeroglide";

  dontWrapQtApps = true;

  # --- THIS IS THE CRUCIAL NEW FIX ---
  # This manually adds the required private include path to the C++ compiler flags.
  # This will force the compiler to find "core/output.h".
  NIX_CFLAGS_COMPILE = "-I${kwinDevPkg}/include/kwin";

  # We still need to patch out the hardcoded /usr/include paths to prevent them from interfering.
  postPatch = ''
    echo "Patching CMakeLists.txt to remove hardcoded /usr/include paths..."
    sed -i '/KPLUGINFACTORY_INCLUDE/d' ./CMakeLists.txt
    sed -i '/KWIN_INCLUDE/d' ./CMakeLists.txt
  '';

  # Assign the pre-defined lists to the correct stdenv attributes.
  nativeBuildInputs = with pkgs; [ cmake ninja pkg-config wayland wayland-protocols kdePackages.extra-cmake-modules ];
  buildInputs = buildAndNativeInputs;

  # The explicit configure/build/install phases remain necessary.
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