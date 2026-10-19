# ~/nixos-config/pkgs/quiver-launcher/default.nix
{
  lib,
  appimageTools,
  fetchurl,
  makeDesktopItem,
}:

# Quiver Launcher, a catalog front-end for PC ports and recomps (Zelda64Recomp,
# 2 Ship 2 Harkinian, ...) that downloads them from GitHub/GitLab releases and runs them.
#
# The games are what needs care, not Quiver: each is a generic-Linux binary or AppImage
# that expects an FHS system. wrapType2 runs Quiver inside a bwrap FHS root, and every
# game it launches inherits that root, so gameLibs below are what the games see.
# (Upstream's .flatpak doesn't help: it launches games on the host via flatpak-spawn.)
#
# AppImage games can't FUSE-mount inside bwrap, and APPIMAGE_EXTRACT_AND_RUN can't be set
# for them: Quiver strips every APPIMAGE_* variable from the processes it starts
# (HostProcessEnvironment.Sanitize upstream). The module registers AppImages with
# binfmt_misc instead, so they run through appimage-run.
let
  pname = "quiver-launcher";
  version = "3.5.1";

  src = fetchurl {
    url = "https://github.com/tgeorgiadis/quiver-launcher/releases/download/v${version}/QuiverLauncher-linux-x64.AppImage";
    hash = "sha256-qM1TmLba6SS87Ans4XgcA8v9cymGdUdvJvwcBy08Yps=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "Quiver Launcher";
    comment = "Download and play PC ports and recompiled games";
    exec = pname;
    icon = "QuiverLauncher";
    startupWMClass = "QuiverLauncher";
    categories = [ "Game" ];
    keywords = [ "recomp" "port" "n64" "games" ];
  };

  # What the games link against beyond appimageTools' default set. Also given to
  # appimage-run by modules/nixos/programs/quiver.nix, which runs the AppImage games.
  gameLibs =
    pkgs: with pkgs; [
      SDL2
      sdl3
      vulkan-loader
      libdecor
      gamemode
      libpulseaudio
      alsa-lib
      # native file pickers (the recomps' ROM-select dialog)
      gtk3
      zenity
    ];
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs =
    pkgs:
    with pkgs;
    [
      # .NET itself: globalization and TLS for the catalog and GitHub API
      icu
      openssl
    ]
    ++ gameLibs pkgs;

  # The store copy can't replace itself; version bumps go through the pin above (the same
  # switch upstream's flatpak wrapper sets).
  profile = ''
    export QuiverLauncher_SKIP_UPDATES=1
  '';

  passthru = { inherit gameLibs; };

  # The store dir isn't writable, so the library (apps.json, Apps/, Cache/) falls back to
  # ~/.local/share/QuiverLauncher, per user.
  extraInstallCommands = ''
    install -Dm644 ${desktopItem}/share/applications/${pname}.desktop \
      $out/share/applications/${pname}.desktop
    install -Dm644 ${appimageContents}/QuiverLauncher.png \
      $out/share/icons/hicolor/256x256/apps/QuiverLauncher.png
  '';

  meta = {
    description = "Launcher for PC ports and recompiled games from GitHub/GitLab releases";
    homepage = "https://github.com/tgeorgiadis/quiver-launcher";
    license = lib.licenses.mit;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
