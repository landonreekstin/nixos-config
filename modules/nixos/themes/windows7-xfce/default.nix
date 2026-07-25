# ~/nixos-config/modules/nixos/themes/windows7-xfce/default.nix
{ config, pkgs, lib, ... }:

# System-side wiring for the XFCE windows7 theme: exposes the vendored theme/asset
# derivations on pkgs (via a gated overlay) and installs the Segoe UI font stack.
# Mirrors themes/aerothemeplasma/plasma-system.nix but carries NO Plasma/Qt/xserver
# config, so it can't drag KDE onto an XFCE-only host.
let
  win7XfceCondition = lib.elem "xfce" config.customConfig.desktop.environments
    && config.customConfig.homeManager.themes.xfce == "windows7";
in {
  config = lib.mkIf win7XfceCondition {
    nixpkgs.overlays = [
      (final: prev: {
        windows7-xfce-gtk = prev.callPackage ./windows7-xfce-gtk.nix { };
        windows7-xfce-assets = prev.callPackage ./windows7-xfce-assets.nix { };
      })
    ];

    # Segoe UI (from vista-fonts). Harmlessly duplicates the aerotheme font block when
    # both KDE-aero and XFCE-win7 are active on one host (e.g. vm-sandbox) — list values
    # merge and fontconfig uses the first match.
    fonts = {
      packages = with pkgs; [ corefonts vista-fonts ];
      fontconfig = {
        enable = true;
        defaultFonts = {
          sansSerif = [ "Segoe UI" ];
          serif = [ "Segoe UI" ];
          monospace = [ "Hack" ];
        };
      };
    };
  };
}
