# ~/nixos-config/modules/home-manager/themes/windows7-xfce/keybindings.nix
{ config, pkgs, lib, customConfig, ... }:

# Windows-style Start-menu key: tapping the Super key opens the Whisker (Start) menu.
# Super is a modifier, so X can't bind it directly; xcape maps a Super *tap* (press+release
# with no other key) to Ctrl+Esc while leaving Super working as a modifier for combos.
# Ctrl+Esc is bound to the whiskermenu popup (also Windows 7's real Start shortcut).
#
# The binding is added at login via xfconf-query (--create is idempotent and doesn't
# clobber the rest of xfce4-keyboard-shortcuts, unlike seeding the whole file). Restricted
# to the XFCE session via OnlyShowIn.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  startKeyScript = pkgs.writeShellScript "win7-start-key" ''
    ${pkgs.xfce.xfconf}/bin/xfconf-query -c xfce4-keyboard-shortcuts \
      -p '/commands/custom/<Primary>Escape' --create -t string \
      -s 'xfce4-popup-whiskermenu' 2>/dev/null || true
    exec ${pkgs.xcape}/bin/xcape -e 'Super_L=Control_L|Escape'
  '';
in {
  config = lib.mkIf win7XfceCondition {
    home.packages = [ pkgs.xcape pkgs.xfce.xfconf ];

    xdg.configFile."autostart/win7-start-key.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Windows 7 Start key
      Exec=${startKeyScript}
      OnlyShowIn=XFCE;
      X-XFCE-Autostart-enabled=true
    '';
  };
}
