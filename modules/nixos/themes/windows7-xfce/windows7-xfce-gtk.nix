# ~/nixos-config/modules/nixos/themes/windows7-xfce/windows7-xfce-gtk.nix
{ stdenv, lib, fetchFromGitHub, gnutar, gtk3 }:

# User738git's "GTKAero": a Windows 7 GTK 2/3/4 theme (with xfwm4 window decorations)
# built to match AeroThemePlasma — i.e. the same Win7 look this repo runs on KDE. Unlike
# the older B00merang theme, its GTK3 CSS targets modern GTK (3.20+/3.24), so widgets
# actually render as Win7. It also bundles a full "Windows 7 Aero" icon theme, which we
# extract here. The GTK theme name is "Windows-7"; the icon theme is "Windows 7 Aero".
# GPL-3.0.
stdenv.mkDerivation {
  pname = "windows7-xfce-gtk";
  version = "0-unstable-2024-9ab9903";

  src = fetchFromGitHub {
    owner = "User738git";
    repo = "GTKAero";
    rev = "9ab9903c498f30638fde80904dfee5bdae6456f6";
    hash = "sha256-++KANqKuPXCibr+51MisETrecoAhhGJNZfFRughkQMc=";
  };

  nativeBuildInputs = [ gnutar gtk3 ];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # GTK 2/3/4 widget theme + xfwm4 decorations → share/themes/Windows-7
    mkdir -p "$out/share/themes/Windows-7" "$out/share/icons"
    cp -r index.theme gtk-2.0 gtk-3.0 gtk-4.0 xfwm4 "$out/share/themes/Windows-7/"

    # Fix Thunar toolbar overlap: the theme's bundled thunar.css is tuned for the pre-4.20
    # Thunar toolbar (hardcoded `entry { height:16px !important }`, negative toolbar margins,
    # magic-number offsets). Thunar 4.20 redesigned the toolbar, so those offsets make the
    # location/search bar overlap the command buttons. Drop the `@import "thunar.css"` so
    # Thunar uses the normal Win7-themed widgets (still fully themed by the base gtk.css)
    # without the broken pre-4.20 geometry. Also append a small sane entry sizing for
    # entries inside toolbars, in case a toolbar entry inherits the global 16px height.
    for css in gtk-3.0/gtk.css gtk-3.0/gtk-dark.css; do
      f="$out/share/themes/Windows-7/$css"
      [ -f "$f" ] || continue
      sed -i '/@import url("thunar.css")/d' "$f"
      cat >> "$f" <<'EOF'

/* nixos-config: sane entry height inside toolbars (Thunar 4.20 location/search bar) */
toolbar entry, .primary-toolbar entry, headerbar entry {
  min-height: 24px;
  height: auto;
  max-height: none;
  padding-top: 2px;
  padding-bottom: 2px;
}
EOF
    done

    # Bundled "Windows 7 Aero" icon theme → share/icons
    tar -xzf AeroIcons.tar.gz -C "$out/share/icons"
    gtk-update-icon-cache "$out/share/icons/Windows 7 Aero" || true

    runHook postInstall
  '';

  meta = {
    description = "Windows 7 GTK + xfwm4 theme with Aero icons (GTKAero, aerothemeplasma-aligned)";
    homepage = "https://github.com/User738git/GTKAero";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
