# ~/nixos-config/modules/home-manager/themes/windows7-xfce/panel.nix
{ config, pkgs, lib, customConfig, ... }:

# The Windows 7 taskbar, generated from customConfig.homeManager.themes.xfcePanel so the
# pinned apps / tray applets / icon size are declarative per host (the Win7 analog of the
# KDE pinnedApps + systemTray config).
#
# Multi-monitor: XFCE can't span one panel across outputs, so we generate ONE panel per
# enabled monitor (customConfig.desktop.monitors). Every panel is a full clone — Start orb ·
# pinned launchers · window list · clock · show-desktop — but the system tray + volume live
# only on the PRIMARY panel (status-notifier icons can register to just one host). Panels are
# bound to their monitor by EDID at login (bind-outputs script) so they follow the right
# physical screen even when connector names reorder across reboots — mirroring the layout
# resolver in modules/home-manager/xfce/monitors.nix. Hosts with no desktop.monitors get a
# single full panel (previous behaviour).
#
# Layout (left→right): Start orb (whiskermenu) · pinned icon-only launchers · window list
# (open apps, with labels) · expanding spacer · [volume · systray — primary only] · clock ·
# show-desktop.
#
# Per-panel plugin ids are namespaced by panel index p as base = p*100 (panel 0 keeps the
# familiar 1/8/10../2-7 ids): 1 whiskermenu · 8 separator · 10.. launchers · 2 tasklist ·
# 3 spacer · 4 pulseaudio · 5 systray · 6 clock · 7 showdesktop.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  panelCfg = customConfig.homeManager.themes.xfcePanel;
  pins = panelCfg.pinnedApps;
  trays = panelCfg.trayApplets;

  orb = "${config.home.homeDirectory}/.local/share/windows7-xfce/orb.png";

  # Stable per-launcher desktop-file id.
  deskId = app: lib.toLower (lib.replaceStrings [ " " "/" ] [ "-" "-" ] app.name);

  isDesc = id: lib.hasPrefix "desc:" id || lib.hasInfix " " id;

  # One panel per enabled monitor; fall back to a single (primary) panel when none configured.
  enabledMons = lib.filter (m: m.enabled) customConfig.desktop.monitors;
  panelMons = if enabledMons != [] then enabledMons else [ null ];
  indexedMons = lib.imap0 (i: m: { inherit i m; }) panelMons;
  primaryIndex =
    let mains = lib.filter (e: e.m != null && e.m.name == "main") indexedMons;
    in if mains != [] then (lib.head mains).i else 0;

  # ---- Per-panel fragment builders -------------------------------------------------------
  panelBase = i: i * 100;

  panelPluginIds = { i, m }:
    let
      base = panelBase i;
      isPrim = i == primaryIndex;
      launcherIds = lib.imap0 (j: _: base + 10 + j) pins;
    in
    [ (base + 1) (base + 8) ] ++ launcherIds ++ [ (base + 2) (base + 3) ]
    ++ lib.optionals isPrim [ (base + 4) (base + 5) ]
    ++ [ (base + 6) (base + 7) ];

  # <panel-N> property block (geometry + plugin-id list). output-name is seeded by the
  # bind-outputs login script, not here.
  mkPanelBlock = { i, m }:
    let
      num = toString (i + 1);
      idsXml = lib.concatMapStrings
        (id: "            <value type=\"int\" value=\"${toString id}\"/>\n")
        (panelPluginIds { inherit i m; });
    in ''
        <property name="panel-${num}" type="empty">
          <property name="position" type="string" value="p=8;x=0;y=0"/>
          <property name="length" type="uint" value="100"/>
          <property name="position-locked" type="bool" value="true"/>
          <property name="icon-size" type="uint" value="${toString panelCfg.iconSize}"/>
          <property name="size" type="uint" value="40"/>
          <property name="plugin-ids" type="array">
    ${idsXml}      </property>
        </property>
    '';

  # Plugin definitions for one panel.
  mkPanelPlugins = { i, m }:
    let
      base = panelBase i;
      isPrim = i == primaryIndex;
      launcherPluginsXml = lib.concatStrings (lib.imap0 (j: app: ''
            <property name="plugin-${toString (base + 10 + j)}" type="string" value="launcher">
              <property name="items" type="array">
                <value type="string" value="${deskId app}.desktop"/>
              </property>
              <property name="disable-tooltips" type="bool" value="false"/>
              <property name="show-label" type="bool" value="false"/>
            </property>
      '') pins);
      trayPluginsXml = lib.optionalString isPrim ''
        <property name="plugin-${toString (base + 4)}" type="string" value="pulseaudio">
          <property name="enable-keyboard-shortcuts" type="bool" value="true"/>
          <property name="show-notifications" type="bool" value="true"/>
        </property>
        <property name="plugin-${toString (base + 5)}" type="string" value="systray">
          <property name="square-icons" type="bool" value="true"/>
          <property name="icon-size" type="int" value="${toString panelCfg.iconSize}"/>
        </property>
      '';
    in ''
        <property name="plugin-${toString (base + 1)}" type="string" value="whiskermenu"/>
        <property name="plugin-${toString (base + 8)}" type="string" value="separator">
          <property name="expand" type="bool" value="false"/>
          <property name="style" type="uint" value="0"/>
        </property>
    ${launcherPluginsXml}    <property name="plugin-${toString (base + 2)}" type="string" value="tasklist">
          <property name="grouping" type="uint" value="1"/>
          <property name="show-labels" type="bool" value="true"/>
          <property name="flat-buttons" type="bool" value="false"/>
          <property name="show-handle" type="bool" value="false"/>
        </property>
        <property name="plugin-${toString (base + 3)}" type="string" value="separator">
          <property name="expand" type="bool" value="true"/>
          <property name="style" type="uint" value="0"/>
        </property>
    ${trayPluginsXml}    <property name="plugin-${toString (base + 6)}" type="string" value="clock">
          <property name="mode" type="uint" value="2"/>
          <property name="digital-layout" type="uint" value="3"/>
          <property name="digital-time-format" type="string" value="%-I:%M %p"/>
          <property name="digital-date-format" type="string" value="%-m/%-d/%Y"/>
        </property>
        <property name="plugin-${toString (base + 7)}" type="string" value="showdesktop"/>
    '';

  panelsListXml = lib.concatMapStrings
    (e: "        <value type=\"int\" value=\"${toString (e.i + 1)}\"/>\n") indexedMons;

  panelXml = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfce4-panel" version="1.0">
      <property name="configver" type="int" value="2"/>
      <property name="panels" type="array">
    ${panelsListXml}    <property name="dark-mode" type="bool" value="true"/>
    ${lib.concatMapStrings mkPanelBlock indexedMons}  </property>
      <property name="plugins" type="empty">
    ${lib.concatMapStrings mkPanelPlugins indexedMons}  </property>
    </channel>
  '';

  # The Start-menu power flyout, shared with keybindings.nix (<Super>BackSpace and the
  # physical power key bind the same window). Invoked here with the panel's whiskermenu
  # instance id so the Start menu stays open underneath it.
  powerMenu = import ./power-menu.nix { inherit pkgs; };

  # Whiskermenu (Start menu) rc — one instance per panel (plugin id base+1). Win7 orb button.
  # Parameterised by the panel's whiskermenu instance id so command-logout can hand it to the
  # power flyout, which uses it to keep this same Start menu open underneath (see power-menu.nix).
  whiskerRcFor = id: ''
    button-title=Start
    button-icon=${orb}
    button-single-row=false
    show-button-title=false
    show-button-icon=true
    launcher-show-name=true
    launcher-show-description=true
    launcher-show-tooltip=true
    category-show-name=true
    item-icon-size=2
    category-icon-size=1
    load-hierarchy=false
    view-as-icons=false
    default-category=0
    recent-items-count=10
    favorites-in-recent=true
    position-search-alternate=true
    position-commands-alternate=false
    position-categories-alternate=true
    stay-focused=false
    confirm-session-command=false
    menu-width=450
    menu-height=550
    menu-opacity=100
    command-settings=xfce4-settings-manager
    show-command-settings=true
    command-lockscreen=xflock4
    show-command-lockscreen=true
    command-logout=${powerMenu}/bin/win7-power-menu ${toString id}
    show-command-logout=true
    search-actions=5
  '';
  # whiskermenu (Start menu) rc — seeded per panel as a WRITABLE copy via home.activation
  # (below), NOT a read-only xdg.configFile symlink. whiskermenu rewrites its own rc at runtime
  # (favorites / recently-used), and writing through a store symlink clobbers it — which is why
  # the *active* panels' whiskermenu-N.rc used to vanish after login, leaving the Start menu
  # with no command-logout so it fell back to the stock xfce4-session-logout two-click dialog.
  whiskerRcStoreFor = id: pkgs.writeText "win7-whiskermenu-${toString id}.rc" (whiskerRcFor id);

  # Each pinned app becomes a .desktop file in its launcher-<id> directory, per panel.
  launcherFiles = lib.listToAttrs (lib.concatMap
    (e: lib.imap0 (j: app: {
      name = "xfce4/panel/launcher-${toString (panelBase e.i + 10 + j)}/${deskId app}.desktop";
      value.text = ''
        [Desktop Entry]
        Version=1.0
        Type=Application
        Name=${app.name}
        Exec=${app.exec}
        Icon=${app.icon}
        Terminal=false
        StartupNotify=true
      '';
    }) pins)
    indexedMons);

  # ---- Bind each panel to its monitor by EDID, at login ----------------------------------
  # JSON: [{panel, primary, selector, isDesc}] — selector is the EDID substring or connector.
  # Same edid-aware selector as the layout resolver: prefer `edid` (EDID match), else the
  # `identifier` (desc: → EDID match, or a plain connector name → literal).
  useEdid = m: m.edid != null && m.edid != "";
  monSelector = m:
    if useEdid m then m.edid
    else if isDesc m.identifier then lib.removePrefix "desc:" m.identifier
    else m.identifier;
  panelBindJson = pkgs.writeText "xfce-panel-bind.json" (builtins.toJSON (map (e: {
    panel = e.i + 1;
    primary = e.i == primaryIndex;
    selector = if e.m == null then "" else monSelector e.m;
    isDesc = e.m != null && (useEdid e.m || isDesc e.m.identifier);
    # whiskermenu (Start menu) plugin id for this panel + the canonical rc the bind script
    # seeds before its single panel restart, so the running plugin picks up command-logout and
    # the Win7 power flyout stays live every login (see seed_whisker_rcs).
    whiskerId = panelBase e.i + 1;
    whiskerRc = toString (whiskerRcStoreFor (panelBase e.i + 1));
  }) indexedMons));

  bindPy = pkgs.writeText "xfce-bind-panels.py" ''
    import json, os, re, shutil, subprocess, sys

    XRANDR = "${pkgs.xorg.xrandr}/bin/xrandr"
    XQ = "${pkgs.xfce.xfconf}/bin/xfconf-query"
    PANEL = "${pkgs.xfce.xfce4-panel}/bin/xfce4-panel"

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

    def set_output(panel, value):
        subprocess.run([XQ, "-c", "xfce4-panel",
                        "-p", "/panels/panel-%d/output-name" % panel,
                        "--create", "-t", "string", "-s", value])

    def seed_whisker_rcs(panels):
        # Write each panel's canonical whiskermenu-<id>.rc (carrying the command-logout line that
        # drives the Win7 power flyout) from the /nix/store copy, immediately BEFORE the single
        # panel restart below. What the flyout actually needs is the *running* whiskermenu plugin
        # to hold command-logout in memory; the plugin gets that by READING this rc when the panel
        # (re)starts. So seeding here, then restarting once, loads command-logout into the plugin
        # every login. xfce4-panel prunes the on-disk ~/.config copy again a few seconds later
        # (its session-lifecycle behavior) — that's harmless: the source of truth is the store rc,
        # re-applied on the next login. Unconditional copy (no detect): the theme is fully
        # declarative, so favorites/recent aren't preserved across sessions anyway.
        home = os.path.expanduser("~")
        for p in panels:
            wid, src = p.get("whiskerId"), p.get("whiskerRc")
            if not wid or not src:
                continue
            dst = os.path.join(home, ".config/xfce4/panel/whiskermenu-%d.rc" % wid)
            try:
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copyfile(src, dst)
                os.chmod(dst, 0o644)
            except OSError:
                pass

    def main():
        panels = json.load(open(sys.argv[1]))
        outputs = get_outputs()
        used = set()
        for p in panels:
            conn = resolve(p["selector"], p["isDesc"], outputs, used) if p["selector"] else None
            if p["primary"]:
                # Full taskbar → the primary monitor's connector (resolved by EDID, so it
                # doesn't depend on --primary having been set yet); fall back to "Primary".
                if conn:
                    used.add(conn)
                set_output(p["panel"], conn or "Primary")
            elif conn:
                used.add(conn)
                set_output(p["panel"], conn)
            else:
                # Monitor absent → bind to a name that can't match so the panel stays hidden
                # (rather than piling a duplicate onto the primary).
                set_output(p["panel"], "__absent-panel-%d__" % p["panel"])
        # Seed the canonical whiskermenu rc's, then restart the panel ONCE. The restart reads the
        # freshly-seeded rc into each whiskermenu plugin, so the Win7 power flyout's command-logout
        # is live for this session (see seed_whisker_rcs). No post-restart repair / second -r is
        # needed — the panel pruning the on-disk copy afterward doesn't affect the running plugin.
        seed_whisker_rcs(panels)
        subprocess.run([PANEL, "-r"])

    main()
  '';

  # Login autostart runs this to resolve monitors → panel outputs, seed the whiskermenu rc's
  # (so the Win7 power flyout's command-logout is live) and restart the panel once. Exposed as
  # a named `win7-bind-panels` binary (writeShellScriptBin) so it's a stable PATH command that
  # win7-xfce-refresh can reuse for its panel-reload step instead of a bespoke kill+relaunch —
  # a naive relaunch skips the seed and drops command-logout, breaking the flyout.
  bindScript = pkgs.writeShellScriptBin "win7-bind-panels" ''
    exec ${pkgs.python3}/bin/python3 ${bindPy} ${panelBindJson}
  '';

  # ---- Tray applets (primary panel systray) ----------------------------------------------
  trayCmd = {
    network = "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator";
    bluetooth = "${pkgs.blueman}/bin/blueman-applet";
    power = "${pkgs.xfce.xfce4-power-manager}/bin/xfce4-power-manager --no-daemon";
    clipboard = "${pkgs.xfce.xfce4-clipman-plugin}/bin/xfce4-clipman";
    nightlight = "${pkgs.redshift}/bin/redshift-gtk";
  };

  # redshift needs a location; seed a manual one so redshift-gtk works without geoclue.
  # Temperatures + location come from the declarative xfcePanel.nightlight options.
  nl = panelCfg.nightlight;
  redshiftConf = lib.optionalAttrs (lib.elem "nightlight" trays) {
    "redshift/redshift.conf".text = ''
      [redshift]
      temp-day=${toString nl.tempDay}
      temp-night=${toString nl.tempNight}
      transition=1
      location-provider=manual
      adjustment-method=randr

      [manual]
      lat=${toString nl.latitude}
      lon=${toString nl.longitude}
    '';
  };
  # Clipman self-registers an autostart entry named xfce4-clipman-plugin-autostart.desktop
  # (Hidden=false) the first time it runs. If we launch it under a *different* filename, that
  # self-written entry becomes a SECOND launcher → clipman's "already running" popup on every
  # login. So emit the clipboard tray under clipman's own canonical filename: there is then
  # only ever one entry (our read-only HM symlink), and any runtime self-write lands on the
  # same path instead of creating a competing one. dropStaleClipmanAutostart (below) clears a
  # pre-existing real file so HM can own the path.
  trayFileName = t:
    if t == "clipboard"
    then "autostart/xfce4-clipman-plugin-autostart.desktop"
    else "autostart/win7-tray-${t}.desktop";
  trayFiles = lib.listToAttrs (map (t: {
    name = trayFileName t;
    value.text = ''
      [Desktop Entry]
      Type=Application
      Name=Windows 7 tray: ${t}
      Exec=${trayCmd.${t}}
      OnlyShowIn=XFCE;
      Hidden=false
      X-XFCE-Autostart-enabled=true
    '';
  }) trays);
in {
  config = lib.mkIf win7XfceCondition {
    xdg.configFile = lib.mkMerge [
      launcherFiles
      trayFiles
      redshiftConf
      {
        "xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml".text = panelXml;
        # Bind panels to their monitors by EDID after the session (and monitor layout) come up.
        "autostart/win7-bind-panels.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Windows 7 panel monitor binding
          Exec=${bindScript}/bin/win7-bind-panels
          OnlyShowIn=XFCE;
          X-XFCE-Autostart-enabled=true
        '';
      }
    ];

    # Expose the panel monitor-bind/whiskermenu-seed script as a stable PATH command so
    # win7-xfce-refresh (and manual use) can re-run the exact login panel bind — seed the
    # whiskermenu rc's then a single `xfce4-panel -r` — keeping the Win7 power flyout live.
    home.packages = [ bindScript ];

    # Seed each panel's whiskermenu rc as a WRITABLE copy after HM links the generation, rather
    # than as a read-only xdg.configFile symlink that whiskermenu clobbers when it rewrites its
    # own state (see whiskerRcStoreFor above). The theme's wipeXfconfForWin7 activation removes
    # ~/.config/xfce4/panel before linkGeneration, so the file is absent here and gets seeded
    # fresh with the current declared theme content on every rebuild (fully declarative). The
    # "if absent" guard keeps this idempotent within a generation.
    # Clipman writes ~/.config/autostart/xfce4-clipman-plugin-autostart.desktop (Hidden=false)
    # as a real file, which HM won't clobber when it links our canonical clipboard autostart
    # (trayFileName "clipboard"). Remove that real file before linkGeneration — but only when
    # it's a non-symlink, so we never delete HM's own link. Idempotent across rebuilds.
    home.activation.dropStaleClipmanAutostart =
      lib.mkIf (lib.elem "clipboard" trays)
        (lib.hm.dag.entryBefore [ "linkGeneration" ] ''
          _clipman_autostart="${config.xdg.configHome}/autostart/xfce4-clipman-plugin-autostart.desktop"
          if [ -e "$_clipman_autostart" ] && [ ! -L "$_clipman_autostart" ]; then
            run rm -f "$_clipman_autostart"
          fi
        '');

    home.activation.seedWin7WhiskerRc = lib.hm.dag.entryAfter [ "linkGeneration" ] (
      lib.concatMapStringsSep "\n" (e:
        let
          id = panelBase e.i + 1;
          target = "${config.xdg.configHome}/xfce4/panel/whiskermenu-${toString id}.rc";
        in ''
          if [ ! -e "${target}" ]; then
            run ${pkgs.coreutils}/bin/install -Dm644 ${whiskerRcStoreFor id} "${target}"
          fi
        ''
      ) indexedMons
    );
  };
}
