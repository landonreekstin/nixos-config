# aerotheme-cursors.nix
{ pkgs, aerothemeplasma-src }:

pkgs.stdenv.mkDerivation {
  pname = "aerotheme-cursors-aero-drop";
  version = "6.3.4";

  src = aerothemeplasma-src;
  nativeBuildInputs = [ pkgs.gnutar ];

  installPhase = ''
    mkdir -p $out/share/icons
    tar -xf $src/misc/cursors/aero-drop.tar.gz -C $out/share/icons
  '';
}