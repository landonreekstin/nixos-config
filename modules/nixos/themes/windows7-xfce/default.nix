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

    # Install the Segoe UI font stack (from vista-fonts) so XFCE's xsettings Gtk/FontName
    # = "Segoe UI 9" resolves. Deliberately does NOT set fonts.defaultFonts — that would
    # change the system-wide default sans for ALL desktops (KDE/Hyprland) whenever this
    # theme is enabled. The font is selected per-session via xsettings instead, keeping
    # XFCE enablement non-disruptive on multi-DE hosts.
    fonts.packages = with pkgs; [ corefonts vista-fonts ];
  };
}
