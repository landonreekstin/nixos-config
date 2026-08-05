# ~/nixos-config/modules/home-manager/themes/windows7-xfce/refresh.nix
{ config, pkgs, lib, customConfig, ... }:

# `win7-xfce-refresh` — apply the latest windows7-xfce config to the RUNNING XFCE session
# without a logout or reboot. Run it right after `rebuild`.
#
# Why it's needed: the XFCE settings stack caches aggressively. xfconfd reads the
# per-channel XML only once at startup and never re-reads it, and the consumer daemons apply
# their settings once and hold them in memory — xfsettingsd (GTK theme / Segoe UI / Aero
# icons / cursor / sounds), xfwm4 (window decorations + keyboard shortcuts) and xfce4-panel
# (layout + launcher icons). So a `rebuild` reseeds the XML on disk, but the live session
# keeps the old look/binds until those daemons are reloaded — which a plain logout often
# fails to force (xfconfd lingers on the user D-Bus bus), historically needing a full reboot.
#
# This reloads each piece in order: drop xfconfd's stale cache, then reload every consumer so
# it re-reads the freshly-seeded xfconf. Assumes the seed on disk is current, i.e. run it
# after a `rebuild` (whose wipeXfconfForWin7 activation re-asserts the perchannel XML). MUST be run
# from a terminal *inside* the XFCE session — it needs the full session env (XAUTHORITY /
# XDG_*); launching the panel from an external shell leaves it unmapped/invisible.
#
# STATUS: NOT yet runtime-verified. The xfconfd-drop + xfsettingsd --replace + xfwm4 SIGHUP
# pieces are proven (keybinds/icons/xsettings reload), but the panel kill+relaunch (step 4) is
# unproven in a real in-session run — if it leaves the taskbar invisible, fall back to
# `xfce4-panel -r` or drop the panel restart. See TASKS.md "Verify + finalize win7-xfce-refresh".
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  refresh = pkgs.writeShellApplication {
    name = "win7-xfce-refresh";
    runtimeInputs = [ pkgs.procps pkgs.util-linux ];
    text = ''
      if [ -z "''${DISPLAY:-}" ]; then
        echo "win7-xfce-refresh: no DISPLAY — run this inside your XFCE session." >&2
        exit 1
      fi

      echo "Refreshing Windows 7 XFCE session…"

      # 1) Drop xfconfd's stale in-memory cache. It reads the per-channel XML only at startup
      #    and never re-reads it, so a rebuild's new seed stays invisible until it respawns.
      #    D-Bus re-activates it (reading the fresh XML) on the next query below.
      pkill -f xfconfd 2>/dev/null || true
      sleep 0.5

      # 2) Re-apply xsettings (Windows-7 GTK theme, Segoe UI, Aero icons, cursor, sounds).
      #    --replace hands the XSETTINGS manager selection to a fresh instance — no kill needed.
      setsid ${pkgs.xfce.xfce4-settings}/bin/xfsettingsd --replace >/dev/null 2>&1 &

      # 3) Reload the window manager: Win7 xfwm4 decorations + keyboard shortcuts (Alt+F4 …).
      pkill -HUP -f xfwm4 2>/dev/null || true
      sleep 1

      # 4) Restart the panel for THIS display. A plain `xfce4-panel -r` can bring the panel
      #    back without re-reserving its screen strut (an invisible taskbar), so kill this
      #    session's panel and relaunch it fresh — its plugins exit with it, and the new
      #    instance reads the freshly-seeded layout via the respawned xfconfd.
      pgrep -u "$UID" -f xfce4-panel 2>/dev/null | while read -r pid; do
        [ -r "/proc/$pid/environ" ] || continue
        if tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -qx "DISPLAY=''${DISPLAY}"; then
          kill "$pid" 2>/dev/null || true
        fi
      done
      sleep 1
      setsid ${pkgs.xfce.xfce4-panel}/bin/xfce4-panel >/dev/null 2>&1 &

      # 5) Reload the desktop (wallpaper + desktop icons).
      ${pkgs.xfce.xfdesktop}/bin/xfdesktop --reload 2>/dev/null || true

      echo "Done. Windows 7 XFCE session reloaded."
    '';
  };
in {
  config = lib.mkIf win7XfceCondition {
    home.packages = [ refresh ];
  };
}
