# ~/nixos-config/pkgs/vibenote/default.nix
#
# VibeNote: insideabush's idea pad for his other vibe projects, a small Tk window.
# Plain Python, standard library only (tkinter). Source: github.com/cblaney00/vibenote
# (his vibe project ~/projects/vibenote). This is the source plus a `vibenote` command;
# the menu entry is in modules/nixos/programs/vibenote.nix. Bumping the pin:
# docs/companion-repos.md.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  localSrc ? null,
  makeWrapper,
  python3,
  git,
}:

let
  python = python3.withPackages (ps: [ ps.tkinter ]);
in
stdenvNoCC.mkDerivation {
  pname = "vibenote";
  # The pin is his latest *release*. A host in vibeProjects.localApps passes his project
  # folder as localSrc instead (pkgs/vibe-local-src.nix), so it runs his newest work.
  version = if localSrc != null then "0-local" else "0-unstable-2026-10-30";

  src = if localSrc != null then localSrc else fetchFromGitHub {
    owner = "cblaney00";
    repo = "vibenote";
    rev = "02ba13dc6782a6287a91cccd6d59b68b6e16df0a";
    hash = "sha256-D5zTrt3Bh5BzwQLSbvMQBL3Mocp6CIVOhfDsjq1w45s=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # notes live in ~/.local/share/vibenote, so the program itself can stay read-only
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/vibenote
    cp main.py projects.py sender.py store.py open_chat.sh $out/share/vibenote/
    # its own icon (his pick: a glowing green notepad); a release from before it had none
    if [ -f assets/icon.svg ]; then
      install -Dm644 assets/icon.svg $out/share/icons/hicolor/scalable/apps/vibenote.svg
    fi
    makeWrapper ${python}/bin/python $out/bin/vibenote \
      --add-flags $out/share/vibenote/main.py \
      --prefix PATH : ${lib.makeBinPath [ git ]}
    runHook postInstall
  '';

  meta = {
    description = "Notes for each of your projects, sent to Claude in batches";
    homepage = "https://github.com/cblaney00/vibenote";
    mainProgram = "vibenote";
    platforms = lib.platforms.linux;
  };
}
