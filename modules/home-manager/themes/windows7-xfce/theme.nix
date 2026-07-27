# ~/nixos-config/modules/home-manager/themes/windows7-xfce/theme.nix
{ config, pkgs, lib, customConfig, ... }:

# Hub for the XFCE "windows7" theme. Layers visual identity over the always-on XFCE
# functional base (modules/home-manager/xfce/functional.nix). Self-gates like every
# theme module: active only when the XFCE DE is present AND this theme is selected.
#
# Concern split:
#   assets.nix — make the Win7 GTK/xfwm4 theme + aero-drop cursor discoverable by name
#                (symlinks into ~/.local/share; does NOT claim the global gtk.*/cursor
#                options, which the Hyprland theme owns on multi-DE hosts)
#   xfconf.nix — the XFCE-authoritative xfconf XML (xsettings + xfwm4) selecting them by
#                name, which xfsettingsd reads inside an XFCE session
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";
in {
  imports = [
    ./assets.nix
    ./xfconf.nix
    ./panel.nix
    ./keybindings.nix
    ./wallpaper.nix
    ./sounds.nix
    ./idle.nix
    ./screensaver.nix
  ];

  config = lib.mkIf win7XfceCondition {
    # Rebuild-enforced theming (analog of plasmaOverride). When xfceOverride is on, wipe
    # the xfconf perchannel-xml dir before HM links the new generation so the seeded Win7
    # XML is re-asserted every switch. When off (default), the theme is seeded once and
    # runtime XFCE tweaks persist.
    home.activation = lib.mkIf customConfig.homeManager.themes.xfceOverride {
      wipeXfconfForWin7 = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
        run rm -rf "${config.xdg.configHome}/xfce4/xfconf/xfce-perchannel-xml" \
                   "${config.xdg.configHome}/xfce4/panel"
      '';
    };
  };
}
