# ~/nixos-config/pkgs/glade/default.nix
#
# The Glade: insideabush's living pixel-art desktop (a Rain World-style forest clearing
# you move around by clicking paths, whose objects open his apps). Under Hyprland it runs
# as a layer-shell surface on the "bottom" layer of every monitor; under X11 as a
# borderless window kept behind the others. See modules/home-manager/hyprland/desktops/glade/desktop.nix.
# It is always night there; its name banners use Departure Mono, the same pixel font as
# the bar (hyprland/desktops/glade), passed in as GLADE_FONT.
#
# The source is his own vibe project, ~/projects/glade on blaney-pc, published as
# github:cblaney00/glade; the program is its glade/ folder. blaney-pc builds it from that
# folder (localSrc); the pin below is the release other machines get, bumped only in a
# release PR of its own — see docs/companion-repos.md.
#
# It also carries the Claude panel's plumbing (claude_state.py in the source): `glade-status`,
# which the panel's Claude Code hooks and Claude itself run, and share/glade/claude-hooks.json,
# the hooks, passed with `--settings` by the blaney-pc launchers (ccn, vibe, blaney-todo).
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  localSrc ? null,
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
  # The pin is his latest *release*. A host in vibeProjects.localApps passes his project
  # folder as localSrc instead (pkgs/vibe-local-src.nix), so it runs his newest work.
  version = if localSrc != null then "0-local" else "0-unstable-2026-10-28";

  src = if localSrc != null then localSrc else fetchFromGitHub {
    owner = "cblaney00";
    repo = "glade";
    rev = "ad00c3f9acc7b40774aa05e9f07fb9c045c42ac7";
    hash = "sha256-eb4UWhwKLG5oPPKwo+W6j1omFNj+ciyXwrrsiKKvQEE=";
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
    makeWrapper ${python}/bin/python $out/bin/glade-status \
      --add-flags $out/share/glade/claude_state.py \
      --set PYTHONDONTWRITEBYTECODE 1
    hook='[{"hooks": [{"type": "command", "command": "'$out'/bin/glade-status hook", "timeout": 5}]}]'
    ask='[{"matcher": "AskUserQuestion|ExitPlanMode", "hooks": [{"type": "command", "command": "'$out'/bin/glade-status hook", "timeout": 5}]}]'
    every='[{"matcher": "*", "hooks": [{"type": "command", "command": "'$out'/bin/glade-status hook", "timeout": 5}]}]'
    cat > $out/share/glade/claude-hooks.json <<EOF
    {"hooks": {"SessionStart": $hook, "UserPromptSubmit": $hook, "PreToolUse": $ask, "PostToolUse": $every,
               "Notification": $hook, "Stop": $hook, "SessionEnd": $hook}}
    EOF
  '';

  meta = {
    description = "A living pixel-art forest desktop you click around to open apps";
    platforms = [ "x86_64-linux" ];
    mainProgram = "glade";
  };
}
