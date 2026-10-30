# ~/nixos-config/modules/nixos/programs/vibenote.nix
{ config, pkgs, lib, ... }:

# VibeNote (pkgs/vibenote): insideabush's notes for each of his vibe projects, as an app.
# `vibenote` opens the window; notes are kept in ~/.local/share/vibenote/notes.json.
let
  cfg = config.customConfig.programs.vibenote;
  vibenote = pkgs.callPackage ../../../pkgs/vibenote (import ../../../pkgs/vibe-local-src.nix config.customConfig "vibenote");

  desktop = pkgs.makeDesktopItem {
    name = "vibenote";
    desktopName = "VibeNote";
    comment = "Notes for each of your projects, sent to Claude in batches";
    exec = "vibenote";
    icon = "vibenote"; # pkgs/vibenote installs it from assets/icon.svg
    categories = [ "Utility" ];
    # its Tk window's class (main.py), so the Glade's dock can tell the window is VibeNote's
    startupWMClass = "vibenote";
  };
in
{
  options.customConfig.programs.vibenote.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "VibeNote, insideabush's per-project notes app (vibenote command + menu entry).";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ vibenote desktop ];
  };
}
