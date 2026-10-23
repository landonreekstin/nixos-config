# scripts/nested-hyprland/vpointer.nix — nix-build scripts/nested-hyprland/vpointer.nix
{ pkgs ? import <nixpkgs> { } }:
pkgs.stdenv.mkDerivation {
  name = "vpointer";
  src = ./vpointer.c;
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.wayland-scanner pkgs.pkg-config ];
  buildInputs = [ pkgs.wayland ];
  buildPhase = ''
    X=${pkgs.wlr-protocols}/share/wlr-protocols/unstable/wlr-virtual-pointer-unstable-v1.xml
    wayland-scanner client-header $X wlr-virtual-pointer-unstable-v1-client-protocol.h
    wayland-scanner private-code $X proto.c
    $CC -O2 -I. -o vpointer $src proto.c $(pkg-config --cflags --libs wayland-client)
  '';
  installPhase = "install -Dm755 vpointer $out/bin/vpointer";
}
