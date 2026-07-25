# ~/nixos-config/modules/nixos/themes/windows7-xfce/windows7-xfce-gtk.nix
{ stdenv, lib, fetchFromGitHub }:

# B00merang's "Windows-7" theme: GTK 2/3/4 widget styling plus an xfwm4 window-
# decoration subtree (title/caption-button pixmaps + themerc). This is the source of the
# Win7 window chrome for the XFCE windows7 theme. GPL-3.0+.
stdenv.mkDerivation {
  pname = "windows7-xfce-gtk";
  version = "0-unstable-2024-943b530";

  src = fetchFromGitHub {
    owner = "B00merang-Project";
    repo = "Windows-7";
    rev = "943b5307b349d3526068be0fa32f7549ee37ab45";
    hash = "sha256-itEHU/9LeraH0n3a2F/r8FWF8Vj7BoF1FFUW2bLNJH4=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/themes/Windows-7"
    cp -r index.theme gtk-2.0 gtk-3.0 gtk-4.0 xfwm4 metacity-1 "$out/share/themes/Windows-7/"
    runHook postInstall
  '';

  meta = {
    description = "Windows 7 GTK + xfwm4 theme (B00merang)";
    homepage = "https://github.com/B00merang-Project/Windows-7";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
