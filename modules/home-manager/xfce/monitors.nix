# ~/nixos-config/modules/home-manager/xfce/monitors.nix
{ config, pkgs, lib, customConfig, ... }:

# Declarative XFCE monitor layout. XFCE (X11) does nothing with monitor position/orientation
# on its own, so a multi-monitor session comes up mis-arranged. This makes the XFCE session a
# second, read-only consumer of customConfig.desktop.monitors (the same list Hyprland reads —
# see modules/home-manager/hyprland/functional.nix), applying position/orientation via an
# XFCE-scoped autostart entry (OnlyShowIn=XFCE). KDE/Hyprland are untouched: the list is only
# *read*, and the autostart only fires in XFCE.
#
# Stable identity, not connector names: X11 connector names (DP-1, HDMI-A-1, …) reorder
# between reboots/drivers (observed here: KDE saved the main panel as DP-0, the live session
# calls it DP-1). So — like Hyprland's `desc:` selector — a monitor whose identifier is a
# description (`desc:…`, or any identifier containing a space) is matched to whatever connector
# currently carries that EDID, at login. A plain connector-name identifier (DP-1) is used
# literally (still works, just not reorder-proof). EDID is read from `xrandr --verbose` inside
# the X session (NVIDIA leaves /sys/class/drm/*/edid empty, so sysfs can't be used).
#
# This is a functional/hardware concern (not visual), so it lives in the XFCE base module and
# is DE-gated, not theme-gated — any XFCE host benefits, themed or not. Hosts with no
# desktop.monitors emit nothing and fall through to plain X defaults.
#
# Deliberately NOT translated: scale. X11 per-output `xrandr --scale` is blurry and shifts
# neighbour coordinates; XFCE does HiDPI globally via DPI, not per output. We reproduce
# mode + position + rotation ("position + orientation"), which is what's wanted.
let
  isXfceDesktop = customConfig.desktop.enable
    && lib.elem "xfce" customConfig.desktop.environments;

  monitors = customConfig.desktop.monitors;
  enabledMonitors = lib.filter (m: m.enabled) monitors;

  # Primary output: the one named "main", else the first enabled monitor.
  mainMon = lib.findFirst (m: m.name == "main") null enabledMonitors;
  primaryMon =
    if mainMon != null then mainMon
    else if enabledMonitors != [] then lib.head enabledMonitors
    else null;
  primaryId = if primaryMon != null then primaryMon.identifier else null;

  # wl_output transform (Hyprland) → xrandr --rotate. Direction of 90°/270° should be
  # confirmed visually; flip left<->right here if a portrait monitor is rotated the wrong way.
  rotateOf = t:
    if t == null || t == "0" then "normal"
    else if t == "1" then "left"
    else if t == "2" then "inverted"
    else "right"; # "3"

  # An identifier is a hardware description (match by EDID) if it has the desc: prefix or
  # contains a space — the same heuristic Hyprland uses (hyprland/functional.nix).
  isDesc = id: lib.hasPrefix "desc:" id || lib.hasInfix " " id;

  # Physical-vs-logical position correction. desktop.monitors positions are Hyprland LOGICAL
  # (post-scale) coordinates. XFCE renders at native resolution (scale dropped), so a monitor
  # placed at the scaled primary's logical edge overlaps the primary's larger physical extent
  # (e.g. LG scale 1.0667 → logical width 2400 but 2560 physical; a neighbour at logical x=2400
  # overlaps by 160px). Shift monitors sitting to the right of / below the primary by the
  # primary's (physical − logical) size difference so they tile flush. No-op when the primary
  # isn't scaled (diff = 0), and left/above monitors already touch the primary's origin edges.
  fj = builtins.fromJSON;
  round = q: builtins.floor (q + 0.5);
  parsePair = s: let p = lib.splitString "x" s; in { x = fj (lib.elemAt p 0); y = fj (lib.elemAt p 1); };

  primaryScaleInfo =
    if primaryMon == null then null
    else
      let
        whStr = lib.head (lib.splitString "@" primaryMon.resolution);
        parts = lib.splitString "x" whStr;
        okWH = (lib.length parts == 2)
          && builtins.match "[0-9]+" (lib.elemAt parts 0) != null
          && builtins.match "[0-9]+" (lib.elemAt parts 1) != null;
        scale = fj primaryMon.scale;
        pos = parsePair primaryMon.position;
      in
        if !okWH || scale == 1 then null
        else
          let
            physW = fj (lib.elemAt parts 0);
            physH = fj (lib.elemAt parts 1);
            logW = round (physW / scale);
            logH = round (physH / scale);
          in {
            diffX = physW - logW;
            diffY = physH - logH;
            rightEdge = pos.x + logW;
            bottomEdge = pos.y + logH;
          };

  adjustPosition = posStr:
    if primaryScaleInfo == null then posStr
    else
      let
        p = parsePair posStr;
        si = primaryScaleInfo;
        x = p.x + (if p.x >= si.rightEdge then si.diffX else 0);
        y = p.y + (if p.y >= si.bottomEdge then si.diffY else 0);
      in "${toString x}x${toString y}";

  # XFCE identifies a monitor by its `edid` substring when set (matched against the EDID from
  # xrandr --verbose); otherwise it falls back to `identifier` (a desc: string → EDID match, or
  # a plain connector name → literal match). `edid` exists because X11 connector names differ
  # from Hyprland's — see the option docs in common-options.nix.
  useEdid = m: m.edid != null && m.edid != "";
  toEntry = m: {
    name = m.name; # stable identity for the runtime on/off state file (below)
    selector =
      if useEdid m then m.edid
      else if isDesc m.identifier then lib.removePrefix "desc:" m.identifier
      else m.identifier;
    isDesc = useEdid m || isDesc m.identifier; # true → match by EDID substring
    enabled = m.enabled;
    primary = m.identifier == primaryId;
    mode = m.resolution; # "preferred" | "WxH" | "WxH@R" — parsed in the resolver
    position = adjustPosition m.position;
    rotate = rotateOf m.transform;
  };

  monitorsJson = pkgs.writeText "xfce-monitors.json"
    (builtins.toJSON (map toEntry monitors));

  # Login-time resolver: reads xrandr --verbose, maps each configured monitor to the connector
  # that currently carries its EDID (or its literal connector name), builds one atomic xrandr
  # command, and applies it. Skips monitors not currently connected. Python stdlib only.
  resolverPy = pkgs.writeText "xfce-apply-monitors.py" ''
    import json, re, subprocess, sys

    XRANDR = "${pkgs.xorg.xrandr}/bin/xrandr"

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

    def find_output(sel, is_desc, outputs, used):
        if not is_desc:
            o = outputs.get(sel)
            return sel if (o and o["connected"] and sel not in used) else None
        seln = sel.lower()
        for name, info in outputs.items():
            if info["connected"] and name not in used and seln in info["edid"].lower():
                return name
        return None

    def mode_args(res):
        if res in ("preferred", "", None):
            return ["--auto"]
        if "@" in res:
            mm, rr = res.split("@", 1)
            return ["--mode", mm, "--rate", rr]
        return ["--mode", res]

    def read_disabled(path):
        # Runtime on/off state (xfce-toggle-monitor): one monitor NAME per line = forced off.
        # Absent/empty file → no overrides, pure declarative defaults (backward-compatible).
        try:
            with open(path) as f:
                return set(l.strip() for l in f if l.strip())
        except OSError:
            return set()

    def main():
        monitors = json.load(open(sys.argv[1]))
        disabled = read_disabled(sys.argv[2]) if len(sys.argv) > 2 else set()
        outputs = get_outputs()
        args, used, applied = [XRANDR], set(), 0
        for m in monitors:
            if m["name"] in disabled:
                m["enabled"] = False  # remembered toggle-off wins over declarative enabled
            out = find_output(m["selector"], m["isDesc"], outputs, used)
            if not out:
                sys.stderr.write("xfce-monitors: no connected output for %r\n" % m["selector"])
                continue
            used.add(out)
            args += ["--output", out]
            if not m["enabled"]:
                args += ["--off"]
                applied += 1
                continue
            if m["primary"]:
                args += ["--primary"]
            args += mode_args(m["mode"])
            args += ["--pos", m["position"], "--rotate", m["rotate"]]
            applied += 1
        if applied:
            subprocess.run(args)

    main()
  '';

  # Runtime on/off state lives outside the Nix store so a toggle survives logout. Shared by the
  # login resolver (reads it) and xfce-toggle-monitor (writes it).
  stateExpr = "\${XDG_STATE_HOME:-$HOME/.local/state}/xfce-monitors/disabled";

  applyScript = pkgs.writeShellScript "xfce-apply-monitors" ''
    # xfsettingsd's display helper otherwise reacts to the RandR event our `xrandr --off`
    # produces and, a few seconds later, re-enables the still-connected output at 0x0
    # (overlapping the primary). Disable its auto-management so our declarative xrandr layout is
    # the sole authority. Idempotent; re-asserted on every apply (login autostart + each toggle).
    xq=${pkgs.xfce.xfconf}/bin/xfconf-query
    "$xq" -c displays -p /Notify             -n -t int -s 0 2>/dev/null || true
    "$xq" -c displays -p /AutoEnableProfiles  -n -t int -s 0 2>/dev/null || true
    exec ${pkgs.python3}/bin/python3 ${resolverPy} ${monitorsJson} "${stateExpr}"
  '';

  # Hyprland-parity runtime toggle (mirrors modules/home-manager/scripts/toggle-monitor.nix):
  # flip a monitor's remembered on/off state, then re-run the full resolver so every OTHER
  # monitor is re-applied at its exact declared position (this is what the XFCE Displays GUI
  # fails to do). Bound to Ctrl+Super+1..4 in the windows7-xfce keybindings.
  validNames = lib.concatMapStringsSep " " (m: m.name) monitors;
  nameAlt = lib.concatMapStringsSep "|" (m: m.name) monitors; # case-pattern alternation
  toggleBin = pkgs.writeShellApplication {
    name = "xfce-toggle-monitor";
    runtimeInputs = [ pkgs.coreutils pkgs.gnugrep ];
    text = ''
      name="''${1:-}"
      if [ -z "$name" ]; then
        echo "usage: xfce-toggle-monitor <monitor-name>" >&2
        exit 2
      fi
      case "$name" in
        ${nameAlt}) ;;
        *) echo "xfce-toggle-monitor: unknown monitor '$name' (configured: ${validNames})" >&2
           exit 1 ;;
      esac

      state_file="${stateExpr}"
      mkdir -p "$(dirname "$state_file")"
      touch "$state_file"
      if grep -qxF "$name" "$state_file"; then
        # currently forced off → turn it back on
        tmp="$(mktemp)"
        grep -vxF "$name" "$state_file" > "$tmp" || true
        mv "$tmp" "$state_file"
      else
        # currently on → force it off
        echo "$name" >> "$state_file"
      fi

      exec ${applyScript}
    '';
  };
in
{
  # Only emit the autostart entry when a layout is actually declared; otherwise leave the
  # XFCE session on plain X defaults.
  config = lib.mkIf (isXfceDesktop && monitors != []) {
    # xfce-toggle-monitor on PATH — referenced by name from the windows7-xfce keybindings.
    home.packages = [ toggleBin ];

    xdg.configFile."autostart/xfce-monitors.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=XFCE monitor layout
      Comment=Apply declarative monitor position/orientation (customConfig.desktop.monitors)
      Exec=${applyScript}
      OnlyShowIn=XFCE;
      X-XFCE-Autostart-enabled=true
    '';
  };
}
