# ~/nixos-config/modules/home-manager/themes/windows7-xfce/gaming-compositor.nix
{ pkgs, lib, customConfig, ... }:

# Auto-toggle xfwm4 compositing for gaming. On gaming-pc's mixed-refresh multi-monitor X
# screen (e.g. 180Hz LG + 60Hz portrait) the xfwm4 compositor paces composited
# (non-unredirected) games to a vblank — often the 60Hz one — so a high-fps game presents on
# an uneven cadence: the fps counter reads high but motion is choppy. Confirmed live: disabling
# compositing makes it smooth, and the stutter is absent in Hyprland.
#
# This watcher runs inside the XFCE session and disables /general/use_compositing while a
# FULLSCREEN window (a game) is the active window, restoring it (Aero glass) otherwise. It is
# launcher-agnostic — works for Steam, Lutris, Heroic and native games with zero per-game
# setup. It replaces an earlier gamemode start/end hook that couldn't be triggered reliably
# from inside Steam's pressure-vessel sandbox (`gamemoderun %command%` broke War Thunder's
# anti-cheat launch). Purely reactive to _NET_ACTIVE_WINDOW / _NET_CLIENT_LIST_STACKING via
# `xprop -spy`, so it costs nothing at rest.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  watcher = pkgs.writeShellScript "win7-xfce-gaming-compositor" ''
    XPROP=${pkgs.xorg.xprop}/bin/xprop
    XQ=${pkgs.xfce.xfconf}/bin/xfconf-query
    GREP=${pkgs.gnugrep}/bin/grep

    # True (rc 0) when the currently-active window has _NET_WM_STATE_FULLSCREEN.
    active_fullscreen() {
      win=$("$XPROP" -root _NET_ACTIVE_WINDOW 2>/dev/null | "$GREP" -m1 -o '0x[0-9a-fA-F]\+')
      if [ -z "$win" ] || [ "$win" = "0x0" ]; then
        return 1
      fi
      "$XPROP" -id "$win" _NET_WM_STATE 2>/dev/null | "$GREP" -q _NET_WM_STATE_FULLSCREEN
    }

    # Set compositing to the desired state, but only write on an actual change (xfconf writes
    # are session-wide; avoid needless churn / glass flicker).
    apply() {
      if active_fullscreen; then target=false; else target=true; fi
      cur=$("$XQ" -c xfwm4 -p /general/use_compositing 2>/dev/null)
      if [ "$cur" != "$target" ]; then
        "$XQ" -c xfwm4 -p /general/use_compositing -n -t bool -s "$target" 2>/dev/null || true
      fi
    }

    apply
    # React to focus changes (game launch/exit/alt-tab) and map/unmap/restack.
    "$XPROP" -root -spy _NET_ACTIVE_WINDOW _NET_CLIENT_LIST_STACKING 2>/dev/null |
      while read -r _; do
        apply
      done
  '';
in {
  config = lib.mkIf win7XfceCondition {
    xdg.configFile."autostart/win7-xfce-gaming-compositor.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Windows 7 XFCE: gaming compositor auto-toggle
      Exec=${watcher}
      OnlyShowIn=XFCE;
      X-XFCE-Autostart-enabled=true
    '';
  };
}
