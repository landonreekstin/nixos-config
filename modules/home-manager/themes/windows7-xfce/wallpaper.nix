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

  # Landscape wallpaper: the shared themed wallpaper (falls back to the bundled Win7 image).
  wp = if customConfig.homeManager.themes.wallpaper != null
       then customConfig.homeManager.themes.wallpaper
       else ../../../../assets/wallpapers/windows7-wallpaper.jpg;

  # Portrait wallpaper: the Win7 image is 16:9 and looks stretched on a vertical panel, so
  # portrait monitors get the same portrait-friendly image Hyprland's century-series uses for
  # its vertical displays (assets/wallpapers/carrier-top.jpg).
  verticalWp = ../../../../assets/wallpapers/carrier-top.jpg;

  xfconf = "${pkgs.xfce.xfconf}/bin/xfconf-query";

  setWallpaper = pkgs.writeShellScript "win7-set-wallpaper" ''
    hwp='${wp}'
    vwp='${verticalWp}'
    # One wallpaper across all workspaces.
    ${xfconf} -c xfce4-desktop -p /backdrop/single-workspace-mode --create -t bool -s true 2>/dev/null || true
    ${xfconf} -c xfce4-desktop -p /backdrop/single-workspace-number --create -t int -s 0 2>/dev/null || true
    # Per output: portrait (height > width) gets the vertical image, else the landscape one.
    # image-style 5 = zoomed (fill, preserve aspect) — Windows 7's "Fill".
    ${pkgs.xorg.xrandr}/bin/xrandr -q | ${pkgs.gawk}/bin/awk '
      / connected/ {
        name=$1; geo="";
        for (i = 2; i <= NF; i++) if ($i ~ /^[0-9]+x[0-9]+\+/) { geo = $i; break }
        if (geo == "") next;
        split(geo, a, "x"); w = a[1] + 0; rest = a[2]; sub(/\+.*/, "", rest); h = rest + 0;
        print name, (h > w ? "V" : "H");
      }' | while read -r mon orient; do
      base="/backdrop/screen0/monitor$mon/workspace0"
      if [ "$orient" = "V" ]; then img="$vwp"; else img="$hwp"; fi
      ${xfconf} -c xfce4-desktop -p "$base/last-image" --create -t string -s "$img"
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
