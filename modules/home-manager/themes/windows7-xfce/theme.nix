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
    ./refresh.nix
    ./wallpaper.nix
    ./sounds.nix
    ./idle.nix
    ./screensaver.nix
    ./mimeapps.nix
    ./gaming-compositor.nix
  ];

  config = lib.mkIf win7XfceCondition {
    # Fully declarative theming: wipe the xfconf perchannel-xml + panel dirs before HM links
    # the new generation, so the seeded Win7 config is re-asserted on every rebuild. The
    # whole theme is Nix-declared (pins/tray/wallpaper/monitors/power via customConfig), so
    # runtime GUI tweaks are intentionally discarded each switch — this keeps the look and
    # layout reproducible and avoids .hm-backup litter from HM relinking over runtime files.
    home.activation.wipeXfconfForWin7 = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      run rm -rf "${config.xdg.configHome}/xfce4/xfconf/xfce-perchannel-xml" \
                 "${config.xdg.configHome}/xfce4/panel"
    '';
  };
}
