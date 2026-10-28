# ~/nixos-config/pkgs/r62d/default.nix
#
# R62D: insideabush's top-down tactical 5v5 for friends, played in the browser. Plain
# JavaScript with no npm packages: a Node server (game + web pages) and the browser client.
# Source: github.com/cblaney00/r62d (his vibe project ~/projects/r62d). This is just the
# source plus a `r62d-server` command; the `r62d` launcher and menu entry are in
# modules/nixos/programs/r62d.nix. Bumping the pin: docs/companion-repos.md.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  nodejs_22,
  procps,
}:

stdenvNoCC.mkDerivation {
  pname = "r62d";
  version = "0-unstable-2026-10-28";

  src = fetchFromGitHub {
    owner = "cblaney00";
    repo = "r62d";
    rev = "068186d4d4a6f2f4e2b0b2686926d786100b7053";
    hash = "sha256-o/E1a9TuqqDk95G3NKmID7K5XUUmNoBa5fmi8MoxChg=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/r62d $out/share/icons/hicolor/scalable/apps
    cp -r server shared public package.json $out/share/r62d/
    cp public/icon.svg $out/share/icons/hicolor/scalable/apps/r62d.svg
    # profiles and match history live in the player's home, not the read-only store
    # (pkill: "Quit to desktop" closes the game window)
    makeWrapper ${nodejs_22}/bin/node $out/bin/r62d-server \
      --add-flags $out/share/r62d/server/server.js \
      --prefix PATH : ${lib.makeBinPath [ procps ]} \
      --run 'export R62D_DATA="''${R62D_DATA:-''${XDG_DATA_HOME:-$HOME/.local/share}/r62d/data}"; mkdir -p "$R62D_DATA"'
    runHook postInstall
  '';

  meta = {
    description = "Top-down tactical 5v5 for friends, in the browser";
    homepage = "https://github.com/cblaney00/r62d";
    mainProgram = "r62d-server";
    platforms = lib.platforms.linux;
  };
}
