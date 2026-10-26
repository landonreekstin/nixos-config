# ~/nixos-config/pkgs/f-117/default.nix
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  python3,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
}:

# F-117 (Briefing Room), insideabush's own news-briefing app, vibe-coded on blaney-pc.
#
# The source is github:cblaney00/f-117, a blank-slate copy of his local project
# ~/projects/breifing-room, which stays private: its history, dev notes and his own feeds
# never go there. The project's ./publish.sh pushes that clean copy. A user's own pages and
# feeds go in ~/.local/share/briefing-room/sources.json, which replaces the shipped one
# (see the repo's README). blaney-pc itself still launches his live project folder
# (hosts/blaney-pc/home.nix), not this. To update: run ./publish.sh in the project, then
# bump `rev`, `hash` and `version` — see docs/companion-repos.md#f-117.
#
# The AI briefings shell out to `claude` and the window placement to `hyprctl`; both are
# looked up on PATH at runtime and skipped when missing, so neither is a dependency here.
let
  python = python3.withPackages (ps: with ps; [ pyqt6 requests ]);
in
stdenvNoCC.mkDerivation {
  pname = "f-117";
  version = "0-unstable-2026-10-26";

  src = fetchFromGitHub {
    owner = "cblaney00";
    repo = "f-117";
    rev = "0c6b70df0481794b51b211dbb4aec72bc3985f47";
    hash = "sha256-fWo31P4UhPY1vTIjpkyb2wV2Y+UkDrRUgWH0IBzgR44=";
  };

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
