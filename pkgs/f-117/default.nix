# ~/nixos-config/pkgs/f-117/default.nix
{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
}:

# F-117 (Briefing Room), insideabush's own news-briefing app, vibe-coded on blaney-pc.
#
# Its real home is the local-only repo ~/projects/breifing-room on blaney-pc, which has no
# remote. src/ is a snapshot of that repo (`git archive HEAD` at b5d7dc0) made into a blank
# slate for sharing: his local/personal feeds and dated reminders are taken out of
# sources.json, his dev notes (CLAUDE.md) and run.sh dropped, and briefing/ui.py reads a
# user's own ~/.local/share/briefing-room/sources.json first (see src/README.md). blaney-pc
# itself still launches his live project folder (hosts/blaney-pc/home.nix), not this.
#
# The AI briefings shell out to `claude` and the window placement to `hyprctl`; both are
# looked up on PATH at runtime and skipped when missing, so neither is a dependency here.
let
  python = python3.withPackages (ps: with ps; [ pyqt6 requests ]);
in
stdenvNoCC.mkDerivation {
  pname = "f-117";
  version = "0-unstable-2026-10-26";

  src = ./src;

  nativeBuildInputs = [ makeWrapper copyDesktopItems ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/f-117 $out/share/icons/hicolor/256x256/apps
    cp -r main.py briefing assets sources.json $out/share/f-117/
    cp assets/f-117.png $out/share/icons/hicolor/256x256/apps/f-117.png
    makeWrapper ${python}/bin/python $out/bin/f-117 \
      --add-flags $out/share/f-117/main.py
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "f-117";
      desktopName = "F-117";
      comment = "Daily news briefing";
      exec = "f-117";
      icon = "f-117";
      startupWMClass = "briefing-room";
      categories = [ "Network" "News" ];
    })
  ];

  meta = {
    description = "insideabush's news-briefing app (Briefing Room)";
    mainProgram = "f-117";
    platforms = lib.platforms.linux;
  };
}
