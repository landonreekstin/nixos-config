# ~/nixos-config/pkgs/librepods.nix
{ lib, stdenv, fetchFromGitHub, cmake, pkg-config,
  qt6, openssl, libpulseaudio }:

stdenv.mkDerivation rec {
  pname = "librepods";
  version = "unstable-2025-12-15";

  src = fetchFromGitHub {
    owner = "kavishdevar";
    repo = "librepods";
    rev = "fd33528218b7e1378429c4d773d757e4be36416f";
    hash = "sha256-NhoWMx9M9X2pHMYZCre6We80jl8XV6843J5y37v9Hyg=";
  };

  sourceRoot = "source/linux";

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
    qt6.qttools   # lupdate/lrelease for Qt6::LinguistTools
  ];

  buildInputs = [
    qt6.qtbase          # Qt6::Core, Qt6::Gui, Qt6::Widgets, Qt6::DBus
    qt6.qtdeclarative   # Qt6::Quick
    qt6.qtconnectivity  # Qt6::Bluetooth
    openssl
    libpulseaudio
  ];

  meta = with lib; {
    description = "AirPods features (ANC, ear detection, battery) on Linux";
    homepage = "https://github.com/kavishdevar/librepods";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "librepods";
  };
}
