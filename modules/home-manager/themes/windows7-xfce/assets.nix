# ~/nixos-config/modules/home-manager/themes/windows7-xfce/assets.nix
{ config, pkgs, lib, customConfig, ... }:

# Make the Win7 theme + cursor discoverable BY NAME without claiming the global
# gtk.*/home.pointerCursor options — those are session-global and already owned by the
# Hyprland theme (century-series) on multi-DE hosts like vm-sandbox. Symlinking into
# ~/.local/share/{themes,icons} puts them on the xfwm4/xfsettingsd search path; xfconf.nix
# then selects them by name (authoritative inside XFCE via xfsettingsd). Mirrors the
# home.file symlink pattern in themes/aerothemeplasma/plasma-user.nix.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";
in {
  config = lib.mkIf win7XfceCondition {
    home.file = {
      ".local/share/themes/Windows-7".source =
        "${pkgs.windows7-xfce-gtk}/share/themes/Windows-7";
      ".local/share/icons/aero-drop".source =
        "${pkgs.windows7-xfce-assets}/share/icons/aero-drop";
    };
  };
}
