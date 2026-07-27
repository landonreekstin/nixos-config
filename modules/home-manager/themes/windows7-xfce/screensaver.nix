# ~/nixos-config/modules/home-manager/themes/windows7-xfce/screensaver.nix
{ config, pkgs, lib, customConfig, ... }:

# XFCE screensaver for the windows7 theme: replay the *exact* ASCII aviation animation this
# host's Ly login screen shows, instead of blanking. The animation is the same Ly `.dur`
# file selected by customConfig.desktop.displayManager.ly.animationFile — resolved here with
# the identical fallback logic as modules/nixos/desktop/ly-century-series-theme.nix (null →
# the century-series default f18-animation.dur). Byte-identical to the login animation, per
# host, with no per-host code.
#
# Engine choice: xscreensaver, NOT xfce4-screensaver. xfce4-screensaver's saver/theme engine
# is non-functional on NixOS — its garcon-menu theme discovery resolves *every* theme (its own
# built-ins included) to a NULL command, so it can only ever blank. xscreensaver is the
# purpose-built X11 tool for custom animated savers: it runs a "program" with $XSCREENSAVER_WINDOW
# set to a plain fullscreen X window, into which we embed an xterm running the .dur player. We
# disable xfce4-screensaver (autostart override) so the two idle daemons don't fight, and keep
# xfce4-power-manager for DPMS (idle.nix); xscreensaver owns the saver + lock only.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  # Same source resolution as the Ly century-series theme (null → default 320x90 file).
  lyCfg = customConfig.desktop.displayManager.ly;
  durSrc = if lyCfg.animationFile != null
           then lyCfg.animationFile
           else ../../../../assets/ly/f18-animation.dur;

  # --- idle timing (shared desktop.idle, same as idle.nix) --------------------------------
  idle = customConfig.desktop.idle;
  pad = n: if n < 10 then "0${toString n}" else toString n;
  toHMS = s: let h = s / 3600; m = (s - h * 3600) / 60; sec = s - h * 3600 - m * 60;
             in "${toString h}:${pad m}:${pad sec}";

  # Saver activates at screensaverTimeout (fallback lockTimeout, else 15 min).
  saverSecs = if idle.screensaverTimeout != null then idle.screensaverTimeout
              else if idle.lockTimeout != null then idle.lockTimeout else 900;
  lockEnabled = idle.lockTimeout != null;
  # xscreensaver lockTimeout is the delay AFTER the saver activates before locking.
  lockDelaySecs = if lockEnabled then lib.max 0 (idle.lockTimeout - saverSecs) else 0;

  # xscreensaver owns DPMS too (xfce4-power-manager's DPMS is disabled in idle.nix to avoid a
  # fight — xscreensaver clobbers xset DPMS on activate regardless). Screen powers off at
  # idle.sleepTimeout.
  dpmsEnabled = idle.sleepTimeout != null;
  dpmsTime = if dpmsEnabled then toHMS idle.sleepTimeout else "4:00:00";

  # --- .dur player (stdlib Python; gzip(JSON) frames with 256-color colorMap + delays) -----
  durPlayer = pkgs.writeText "win7-dur-player.py" ''
    import gzip, json, sys, time, shutil, signal

    def main():
        with gzip.open(sys.argv[1], "rt", encoding="utf-8") as fh:
            mov = json.load(fh)["DurMovie"]
        cols, lines = mov["columns"], mov["lines"]
        frames = mov["frames"]

        rendered = []
        for fr in frames:
            contents = fr["contents"]
            cmap = fr["colorMap"]
            rows = []
            for y in range(lines):
                row = contents[y] if y < len(contents) else ""
                parts = []
                pfg = pbg = None
                for x in range(cols):
                    ch = row[x] if x < len(row) else " "
                    if x < len(cmap) and y < len(cmap[x]):
                        fg, bg = cmap[x][y]
                    else:
                        fg, bg = 7, 0
                    if fg != pfg or bg != pbg:
                        parts.append("\x1b[38;5;%d;48;5;%dm" % (fg, bg))
                        pfg, pbg = fg, bg
                    parts.append(ch)
                parts.append("\x1b[0m")
                rows.append("".join(parts))
            rendered.append((rows, float(fr.get("delay", 0.1))))

        ts = shutil.get_terminal_size((cols, lines))
        top = max(0, (ts.lines - lines) // 2)
        left = max(0, (ts.columns - cols) // 2)

        w = sys.stdout.write
        # Hide cursor, disable auto-wrap (so writing the bottom-right cell can't scroll the
        # frame), clear once; then draw each row with ABSOLUTE cursor positioning (never a
        # trailing newline) so the terminal never scrolls — a trailing '\n' on the last row
        # would roll the frame up by one line each tick and look fragmented.
        w("\x1b[?25l\x1b[?7l\x1b[2J")
        try:
            while True:
                for rows, delay in rendered:
                    buf = []
                    for i, line in enumerate(rows):
                        buf.append("\x1b[%d;%dH%s" % (top + i + 1, left + 1, line))
                    w("".join(buf))
                    sys.stdout.flush()
                    time.sleep(delay)
        except (KeyboardInterrupt, BrokenPipeError):
            pass
        finally:
            w("\x1b[?7h\x1b[?25h\x1b[0m")
            sys.stdout.flush()

    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    main()
  '';

  # --- saver entry point: embed a full-window xterm running the player --------------------
  # xscreensaver sets $XSCREENSAVER_WINDOW to a plain fullscreen X window; xterm -into
  # reparents into it and fills it. We pick the font's PIXEL size (via fontconfig
  # "pixelsize=", NOT -fs which is points) so the animation's fixed cols×lines grid is as
  # large as possible while still fitting: a Monospace cell is ~0.6 wide and ~1.2 tall per
  # pixelsize, so pixelsize ≤ min(cellW/0.6, cellH/1.2) where cellW=winW/cols, cellH=winH/lines.
  # -geometry cols×lines sizes xterm to exactly the animation grid (xterm -into does NOT
  # auto-fill the parent — without it xterm defaults to 80×24 and only a small top-left corner
  # draws, the rest black). At the fitted pixelsize the grid is ≲ the window (thin bottom/right
  # margin).
  saverScript = pkgs.writeShellScript "win7-ascii-saver" ''
    set -eu
    dur="${durSrc}"
    [ -n "''${XSCREENSAVER_WINDOW:-}" ] || exit 1

    read cols lines < <(${pkgs.python3}/bin/python3 -c \
      'import gzip,json,sys; d=json.load(gzip.open(sys.argv[1],"rt"))["DurMovie"]; print(d["columns"], d["lines"])' \
      "$dur")

    W=""; H=""
    eval "$(${pkgs.xorg.xwininfo}/bin/xwininfo -id "$XSCREENSAVER_WINDOW" 2>/dev/null \
      | ${pkgs.gawk}/bin/awk '/Width:/{print "W="$2} /Height:/{print "H="$2}')"

    px=12
    if [ -n "$W" ] && [ -n "$H" ]; then
      px=$(${pkgs.gawk}/bin/awk -v H="$H" -v W="$W" -v c="$cols" -v l="$lines" \
        'BEGIN{cw=W/c; ch=H/l; a=cw/0.6; b=ch/1.2; m=(a<b?a:b); if(m<4)m=4; printf "%d", m}')
    fi

    exec ${pkgs.xterm}/bin/xterm -into "$XSCREENSAVER_WINDOW" \
      -geometry "''${cols}x''${lines}" \
      -fa "Monospace:pixelsize=$px" \
      -b 0 -bw 0 +sb -bg black -fg white \
      -e ${pkgs.python3}/bin/python3 ${durPlayer} "$dur"
  '';

  # --- ~/.xscreensaver: one-saver mode running our program, dark aviation lock palette -----
  xscreensaverConf = ''
    timeout:	${toHMS saverSecs}
    cycle:	${toHMS saverSecs}
    lock:	${if lockEnabled then "True" else "False"}
    lockTimeout:	${toHMS lockDelaySecs}
    passwdTimeout:	0:00:30
    dpmsEnabled:	${if dpmsEnabled then "True" else "False"}
    dpmsQuickOff:	False
    dpmsStandby:	${dpmsTime}
    dpmsSuspend:	${dpmsTime}
    dpmsOff:	${dpmsTime}
    grabDesktopImages:	False
    grabVideoFrames:	False
    chooseRandomImages:	False
    mode:	one
    selected:	0
    programs:							      \
      "Windows 7 Aviation" ${saverScript} \n\
    fade:	False
    unfade:	False
    fadeSeconds:	0:00:00
    fadeTicks:	0
    splash:	False
    foreground:	#8fd6ff
    background:	#0a0e14
    textForeground:	#8fd6ff
    textBackground:	#0a0e14
    borderColor:	#1f6feb
  '';

  # xscreensaver launcher (the daemon). xfce4-power-manager keeps DPMS, so xscreensaver owns
  # only the saver + lock.
  xscreensaverAutostart = ''
    [Desktop Entry]
    Type=Application
    Name=Windows 7 screensaver (xscreensaver)
    Exec=${pkgs.xscreensaver}/bin/xscreensaver --no-splash
    OnlyShowIn=XFCE;
    X-XFCE-Autostart-enabled=true
  '';

  # Shadow the profile's xfce4-screensaver autostart so its (blank-only, conflicting) daemon
  # does not start alongside xscreensaver.
  disableXfceScreensaver = ''
    [Desktop Entry]
    Type=Application
    Name=Screensaver (disabled by windows7 theme — xscreensaver is used instead)
    Exec=true
    Hidden=true
    X-XFCE-Autostart-enabled=false
  '';
in {
  config = lib.mkIf win7XfceCondition {
    home.packages = [ pkgs.xscreensaver ];
    home.file.".xscreensaver".text = xscreensaverConf;
    xdg.configFile = {
      "autostart/win7-xscreensaver.desktop".text = xscreensaverAutostart;
      "autostart/xfce4-screensaver.desktop".text = disableXfceScreensaver;
    };
  };
}
