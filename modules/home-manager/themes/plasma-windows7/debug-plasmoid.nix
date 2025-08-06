# File: debug-plasmoid.nix
{ pkgs, aerothemeplasma-src }:

pkgs.stdenv.mkDerivation {
  pname = "debug-plasmoid";
  version = "1.0";

  # The source code we want to debug
  src = aerothemeplasma-src;

  # All the tools and libraries needed for the build environment
  nativeBuildInputs = with pkgs; with kdePackages; [
    cmake
    ninja
    extra-cmake-modules
    pkg-config
    wrapQtAppsHook
  ];
  buildInputs = with pkgs.kdePackages; [
    qtbase qtdeclarative qtsvg qt5compat qttools
    kirigami kirigami-addons kcoreaddons qqc2-desktop-style
    kiconthemes kauth kcrash kconfig kcmutils knewstuff kio
    knotifications knotifyconfig attica krunner kglobalaccel
    kguiaddons kdbusaddons kwidgetsaddons kcodecs sonnet
    kpackage kxmlgui ksvg libplasma plasma5support
    plasma-activities plasma-activities-stats
  ];
}