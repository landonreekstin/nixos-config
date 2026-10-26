# ~/nixos-config/pkgs/glade/default.nix
#
# The Glade: insideabush's living pixel-art desktop (a Rain World-style forest clearing
# you move around by clicking paths, whose objects open his apps). Under Hyprland it runs
# as a layer-shell surface on the "bottom" layer of every monitor; under X11 as a
# borderless window kept behind the others. See modules/home-manager/hyprland/desktops/glade/desktop.nix.
# It is always night there; its name banners use Departure Mono, the same pixel font as
# the bar (hyprland/desktops/glade), passed in as GLADE_FONT.
#
# The source is his own vibe project, ~/projects/hud on blaney-pc, published as
# github:cblaney00/glade; the program is its glade/ folder. To update: push the project's
# main, then bump `rev`, `hash` and `version` (the commit date) — see
# docs/companion-repos.md#glade.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  python3,
  gtk3,
  gtk-layer-shell,
  gobject-introspection,
  wrapGAppsHook3,
  makeWrapper,
  wmctrl,
  xrandr,
  departure-mono,
}:

let
  python = python3.withPackages (ps: [ ps.pygame ps.pygobject3 ps.pycairo ]);
in
stdenvNoCC.mkDerivation {
  pname = "glade";
  version = "0-unstable-2026-10-26";

  src = fetchFromGitHub {
    owner = "cblaney00";
    repo = "glade";
    rev = "0549bd54be3f0dcc24c8341802901a193493fb75";
    hash = "sha256-3KIpM1keg5XLqrcm8Ny9zE85S8F1zPpuQHpFcAA4tBU=";
  };
  sourceRoot = "source/glade";

  nativeBuildInputs = [ wrapGAppsHook3 gobject-introspection makeWrapper ];
  # gtk-layer-shell's typelib is what lets the GTK side make a desktop-layer surface.
  buildInputs = [ gtk3 gtk-layer-shell ];

  # Wrap the python entry point by hand, so the GI typelib paths wrapGAppsHook3
  # collects end up on it.
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 -t $out/share/glade *.py
    runHook postInstall
  '';

  postFixup = ''
    makeWrapper ${python}/bin/python $out/bin/glade \
      "''${gappsWrapperArgs[@]}" \
      --add-flags $out/share/glade/main.py \
      --set PYTHONDONTWRITEBYTECODE 1 \
      --set PYGAME_HIDE_SUPPORT_PROMPT 1 \
      --set GLADE_FONT ${departure-mono}/share/fonts/otf/DepartureMono-Regular.otf \
      --prefix PATH : ${lib.makeBinPath [ wmctrl xrandr ]}
  '';

  meta = {
    description = "A living pixel-art forest desktop you click around to open apps";
    platforms = [ "x86_64-linux" ];
    mainProgram = "glade";
  };
}
