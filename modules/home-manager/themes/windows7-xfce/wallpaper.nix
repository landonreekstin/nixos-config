# ~/nixos-config/modules/home-manager/themes/windows7-xfce/wallpaper.nix
{ config, pkgs, lib, customConfig, ... }:

# Desktop wallpaper. xfdesktop stores the backdrop per-monitor under hardware-specific
# property names (e.g. /backdrop/screen0/monitorDP-1/workspace0/last-image), which it only
# creates lazily, so a static xfce4-desktop.xml seed can't know the monitor names ahead of
# time. A login script resolves each output and sets its image via xfconf-query, then reloads
# xfdesktop.
#
# Orientation comes from the DECLARED config (transform 1/3 = vertical), NOT from live geometry:
# this autostart may run before the monitor-layout resolver has rotated the panels, so reading
# live rotation would mis-assign (a portrait monitor still in its native landscape mode would
# wrongly get the landscape wallpaper — then get cropped once rotated). We map each declared
# monitor to its current connector by EDID (same approach as xfce/monitors.nix), which is
# available regardless of rotation state. Portrait → carrier-top.jpg (the Win7 16:9 image looks
# stretched on a vertical panel); landscape → the shared/Win7 wallpaper.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  # Landscape wallpaper: the XFCE-specific override if set (lets a host give XFCE a different
  # wallpaper than its KDE without touching the shared one), else the shared themed wallpaper,
  # else the bundled Win7 image.
  wp = if customConfig.homeManager.themes.xfceWallpaper != null
       then customConfig.homeManager.themes.xfceWallpaper
       else if customConfig.homeManager.themes.wallpaper != null
       then customConfig.homeManager.themes.wallpaper
       else ../../../../assets/wallpapers/windows7-wallpaper.jpg;

  # Portrait wallpaper: the same portrait-friendly image Hyprland's century-series uses.
  verticalWp = ../../../../assets/wallpapers/carrier-top.jpg;

  isDesc = id: lib.hasPrefix "desc:" id || lib.hasInfix " " id;
  useEdid = m: m.edid != null && m.edid != "";
  monSelector = m:
    if useEdid m then m.edid
    else if isDesc m.identifier then lib.removePrefix "desc:" m.identifier
    else m.identifier;

  # [{selector, isDesc, vertical, wallpaper}] for each enabled monitor. `wallpaper` is the
  # per-monitor override store path (or null → use the orientation default).
  monitorsJson = pkgs.writeText "xfce-wallpaper-monitors.json" (builtins.toJSON
    (map (m: {
      selector = monSelector m;
      isDesc = useEdid m || isDesc m.identifier;
      vertical = m.transform == "1" || m.transform == "3";
      wallpaper = if m.wallpaper != null then "${m.wallpaper}" else null;
    }) (lib.filter (m: m.enabled) customConfig.desktop.monitors)));

  setWallpaperPy = pkgs.writeText "win7-set-wallpaper.py" ''
    import json, re, subprocess, sys

    XRANDR = "${pkgs.xorg.xrandr}/bin/xrandr"
    XQ = "${pkgs.xfce.xfconf}/bin/xfconf-query"
    XFDESKTOP = "${pkgs.xfce.xfdesktop}/bin/xfdesktop"
    HWP = "${wp}"
    VWP = "${verticalWp}"

    def parse_edid(hexstr):
        try:
            b = bytes.fromhex(hexstr)
        except ValueError:
            return ""
        if len(b) < 128:
            return ""
        mfg = (b[8] << 8) | b[9]
        letters = "".join(chr(((mfg >> s) & 0x1f) + 64) for s in (10, 5, 0))
        parts = [letters]
        for off in (54, 72, 90, 108):
            d = b[off:off + 18]
            if len(d) == 18 and d[0] == 0 and d[1] == 0 and d[2] == 0 and d[3] in (0xFC, 0xFF, 0xFE):
                txt = d[5:18].split(b"\n")[0].decode("ascii", "ignore").strip()
                if txt:
                    parts.append(txt)
        parts.append(str(int.from_bytes(b[12:16], "little")))
        return " ".join(parts)

    def get_outputs():
        try:
            out = subprocess.run([XRANDR, "--verbose"], capture_output=True, text=True).stdout
        except Exception:
            return {}
        outputs, cur, edid_mode, edid_hex = {}, None, False, []
        def flush():
            if cur is not None:
                outputs[cur]["edid"] = parse_edid("".join(edid_hex))
        for line in out.splitlines():
            m = re.match(r"^(\S+) (connected|disconnected)", line)
            if m:
                flush()
                edid_hex[:] = []
                edid_mode = False
                cur = m.group(1)
                outputs[cur] = {"connected": m.group(2) == "connected", "edid": ""}
                continue
            if cur is None:
                continue
            if re.match(r"^\s+EDID:", line):
                edid_mode = True
                continue
            if edid_mode:
                h = line.strip()
                if re.fullmatch(r"[0-9a-fA-F]+", h):
                    edid_hex.append(h)
                else:
                    edid_mode = False
        flush()
        return outputs

    def resolve(sel, is_desc, outputs, used):
        if not sel:
            return None
        if not is_desc:
            o = outputs.get(sel)
            return sel if (o and o["connected"] and sel not in used) else None
        seln = sel.lower()
        for name, info in outputs.items():
            if info["connected"] and name not in used and seln in info["edid"].lower():
                return name
        return None

    def set_wp(conn, img):
        base = "/backdrop/screen0/monitor%s/workspace0" % conn
        subprocess.run([XQ, "-c", "xfce4-desktop", "-p", base + "/last-image",
                        "--create", "-t", "string", "-s", img])
        # image-style 5 = zoomed (fill, preserve aspect) — Windows 7's "Fill".
        subprocess.run([XQ, "-c", "xfce4-desktop", "-p", base + "/image-style",
                        "--create", "-t", "int", "-s", "5"])

    def main():
        mons = json.load(open(sys.argv[1]))
        outputs = get_outputs()
        # One wallpaper across all workspaces.
        subprocess.run([XQ, "-c", "xfce4-desktop", "-p", "/backdrop/single-workspace-mode",
                        "--create", "-t", "bool", "-s", "true"])
        subprocess.run([XQ, "-c", "xfce4-desktop", "-p", "/backdrop/single-workspace-number",
                        "--create", "-t", "int", "-s", "0"])
        used = set()
        for mon in mons:
            conn = resolve(mon["selector"], mon["isDesc"], outputs, used)
            if conn:
                used.add(conn)
                # Per-monitor override, else the orientation default.
                img = mon.get("wallpaper") or (VWP if mon["vertical"] else HWP)
                set_wp(conn, img)
        # Any connected output not covered by the config → landscape default.
        for name, info in outputs.items():
            if info["connected"] and name not in used:
                set_wp(name, HWP)
        subprocess.run([XFDESKTOP, "--reload"])

    main()
  '';

  setWallpaper = pkgs.writeShellScript "win7-set-wallpaper" ''
    exec ${pkgs.python3}/bin/python3 ${setWallpaperPy} ${monitorsJson}
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
