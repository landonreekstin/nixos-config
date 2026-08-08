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
# Runtime-verified live over RDP on gaming-pc (2026-08-06). Step 4 reuses the login panel bind
# (win7-bind-panels from panel.nix) rather than a bespoke kill+relaunch, so the seed→`xfce4-panel -r`
# sequence runs and the Win7 power flyout's command-logout stays live across a refresh — a naive
# relaunch would skip the seed and regress the Start power button to the two-click dialog.
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

      # 4) Re-run the exact login panel bind (win7-bind-panels from panel.nix): re-resolve
      #    monitors → panel outputs, re-seed each whiskermenu rc, then a single `xfce4-panel -r`.
      #    Reusing the login path (not a bespoke kill+relaunch) is what keeps the Win7 power
      #    flyout live — the flyout needs the running whiskermenu plugin to hold command-logout
      #    in memory, which it only acquires by reading the freshly-seeded rc on panel restart.
      #    A naive relaunch skips the seed → the pruned on-disk rc has no command-logout → the
      #    Start power button regresses to the stock two-click dialog.
      win7-bind-panels

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
