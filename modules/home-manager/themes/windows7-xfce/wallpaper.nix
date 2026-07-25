# ~/nixos-config/modules/home-manager/themes/windows7-xfce/wallpaper.nix
{ config, pkgs, lib, customConfig, ... }:

# Desktop wallpaper. xfdesktop stores the backdrop per-monitor under hardware-specific
# property names (e.g. /backdrop/screen0/monitorDP-1/workspace0/last-image), which it
# only creates lazily — so a static xfce4-desktop.xml seed can't know the monitor names
# ahead of time. Instead a login script enumerates the connected outputs (xrandr) and sets
# the image for each via xfconf-query, then reloads xfdesktop. Uses the shared
# customConfig.homeManager.themes.wallpaper (falling back to the bundled Win7 wallpaper).
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  wp = if customConfig.homeManager.themes.wallpaper != null
       then customConfig.homeManager.themes.wallpaper
       else ../../../../assets/wallpapers/windows7-wallpaper.jpg;

  xfconf = "${pkgs.xfce.xfconf}/bin/xfconf-query";

  setWallpaper = pkgs.writeShellScript "win7-set-wallpaper" ''
    wp='${wp}'
    # One wallpaper across all workspaces.
    ${xfconf} -c xfce4-desktop -p /backdrop/single-workspace-mode --create -t bool -s true 2>/dev/null || true
    ${xfconf} -c xfce4-desktop -p /backdrop/single-workspace-number --create -t int -s 0 2>/dev/null || true
    # image-style 5 = zoomed (fill, preserve aspect) — Windows 7's "Fill".
    for mon in $(${pkgs.xorg.xrandr}/bin/xrandr --listmonitors | ${pkgs.gawk}/bin/awk 'NR>1{print $NF}'); do
      base="/backdrop/screen0/monitor$mon/workspace0"
      ${xfconf} -c xfce4-desktop -p "$base/last-image" --create -t string -s "$wp"
      ${xfconf} -c xfce4-desktop -p "$base/image-style" --create -t int -s 5
    done
    ${pkgs.xfce.xfdesktop}/bin/xfdesktop --reload 2>/dev/null || true
  '';
in {
  config = lib.mkIf win7XfceCondition {
    xdg.configFile."autostart/win7-wallpaper.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Windows 7 wallpaper
      Exec=${setWallpaper}
      OnlyShowIn=XFCE;
      X-XFCE-Autostart-enabled=true
    '';
  };
}
