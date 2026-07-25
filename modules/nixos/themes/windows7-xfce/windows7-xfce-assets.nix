# ~/nixos-config/modules/nixos/themes/windows7-xfce/windows7-xfce-assets.nix
{ stdenv, lib, fetchgit, gnutar }:

# Light extraction of the reusable Win7 asset from the AeroThemePlasma repo — the
# `aero-drop` cursor theme — WITHOUT the heavy Qt/KDE build the aerothemeplasma package
# does. Independently pinned (same rev as the KDE side) so this is fully decoupled from
# the plasma overlay.
#
# NOTE: at rev 6.3.4 the repo ships only misc/cursors/ (no sound theme, no icon theme —
# the KDE module's sounds/icons paths are stale no-ops). Win7 icons are deferred to the
# M5 polish pass; the Win7 sound scheme is handled (or descoped) separately in M4.
stdenv.mkDerivation {
  pname = "windows7-xfce-assets";
  version = "6.3.4";

  src = fetchgit {
    url = "https://gitgud.io/wackyideas/AeroThemePlasma.git";
    rev = "6.3.4";
    sha256 = "sha256-OPzL/Fc/irNYlSzYBkl/AIvJBydcpD8LCka+FTpV4FQ=";
  };

  nativeBuildInputs = [ gnutar ];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/icons"
    tar -xzf "$src/misc/cursors/aero-drop.tar.gz" -C "$out/share/icons"
    runHook postInstall
  '';

  meta = {
    description = "Windows 7 aero-drop cursor theme (extracted from AeroThemePlasma)";
    homepage = "https://gitgud.io/wackyideas/AeroThemePlasma";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.linux;
  };
}
