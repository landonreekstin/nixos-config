# ~/nixos-config/modules/home-manager/themes/windows7-xfce/keybindings.nix
{ config, pkgs, lib, customConfig, ... }:

# Windows 7 / Hyprland-parity keyboard shortcuts for the XFCE session. Two pieces:
#
#  1. A full xfce4-keyboard-shortcuts.xml, seeded as the xfconf per-channel XML XFCE reads
#     (same pattern as xfconf.nix's xfwm4/xsettings channels). We OWN the whole channel, so
#     the window-manager binds live under xfwm4/custom and the app-launch binds under
#     commands/custom, each with override=true (which tells XFCE to use the custom set and
#     ignore its built-in defaults). Because override drops the defaults, this file also
#     re-declares the Windows-standard binds worth keeping (Alt+F4, Alt+Tab, Ctrl+Alt+arrows).
#     The theme's wipeXfconfForWin7 activation re-asserts this XML on every rebuild.
#  2. xcape, launched from an XDG autostart entry, maps a Super_L *tap* (press+release with no
#     other key) to Ctrl+Esc — which the XML binds to the Whisker (Start) menu, i.e. Windows'
#     Start-key behavior. Super still works as a modifier for every real combo below.
#
# The keymap mirrors the user's Hyprland binds where they translate to a stacking WM, and
# falls back to Windows 11 conventions where they don't: Super+Arrows = Aero snap, Super+L =
# lock, Ctrl+Shift+Esc = Task Manager, Super+D = show desktop. App-launch commands come from
# customConfig.apps.programs (the same registry Hyprland reads) so the two
# desktops stay in lockstep — except Files (Super+F → thunar, theme-native), editor (Super+T →
# mousepad, XFCE's native editor rather than the Hyprland kate), and music (plain spotify; the
# Hyprland value's --ozone-platform=wayland flags are wrong under X11).
#
# The `binds` data below is the SINGLE SOURCE OF TRUTH: it generates both the xfconf XML and
# the Super+/ cheatsheet (a themed read-only yad popup, mirroring Hyprland's Super+/), so
# the reference can never drift from the live binds. Each entry is
# { key; value; wm ? false; desc ? null; cheat ? true }:
#   - wm=true  → value is an xfwm4 action name (goes in xfwm4/custom)
#   - wm=false → value is a shell command (goes in commands/custom)
#   - desc     → cheatsheet label; cheat=false keeps a bind active but hides it from the sheet.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  # App-launch commands come from the customConfig.apps.programs registry — the same
  # source Hyprland reads — so the two desktops stay in lockstep. A role with
  # package = null has an empty command (it is unset); those binds are filtered out
  # below rather than emitted as an empty xfconf value.
  apps = lib.mapAttrs (_: role: role.command) customConfig.apps.programs;
  xfconfDir = "xfce4/xfconf/xfce-perchannel-xml";

  # Per-monitor display toggles, Hyprland parity (Ctrl+Super+1..4 → xfce-toggle-monitor <name>).
  # One bind per configured monitor, indexed like Hyprland's imap1 in hyprland/functional.nix.
  # xfce-toggle-monitor comes from the DE-gated xfce/monitors.nix on PATH (command bind, wm=false).
  monitors = customConfig.desktop.monitors;
  displayBinds = lib.imap1 (i: mon: {
    key = "<Primary><Super>${toString i}";
    value = "xfce-toggle-monitor ${mon.name}";
    desc = "Toggle ${mon.name} display";
  }) monitors;

  groupsRaw = [
    { title = "Windows & snapping"; binds = [
        { key = "<Super>Left";         value = "tile_left_key";                 wm = true; desc = "Snap window left"; }
        { key = "<Super>Right";        value = "tile_right_key";                wm = true; desc = "Snap window right"; }
        # Quadrant tiling on the numpad diagonals (7/9/1/3 sit in the numpad's corners,
        # matching the screen corners). NumLock is forced on below so these emit KP_7/9/1/3
        # (not KP_Home/Prior/End/Next) — xfwm4's one-key-per-action rule means we can only
        # bind one NumLock state per action. Drag-to-corner does the same via tile_on_move.
        { key = "<Super>KP_7";         value = "tile_up_left_key";              wm = true; desc = "Snap top-left quarter"; }
        { key = "<Super>KP_9";         value = "tile_up_right_key";             wm = true; desc = "Snap top-right quarter"; }
        { key = "<Super>KP_1";         value = "tile_down_left_key";            wm = true; desc = "Snap bottom-left quarter"; }
        { key = "<Super>KP_3";         value = "tile_down_right_key";           wm = true; desc = "Snap bottom-right quarter"; }
        { key = "<Super>Up";           value = "maximize_window_key";           wm = true; desc = "Maximize"; }
        { key = "<Super>Down";         value = "hide_window_key";               wm = true; desc = "Minimize"; }
        { key = "<Super><Shift>Left";  value = "move_window_to_monitor_left_key";  wm = true; desc = "Move window to monitor left"; }
        { key = "<Super><Shift>Right"; value = "move_window_to_monitor_right_key"; wm = true; desc = "Move window to monitor right"; }
        # Prev/next workspace via Super+Ctrl (uses prev_/next_workspace_key so it doesn't
        # collide with the left_/right_workspace_key actions on the Ctrl+Alt defaults below).
        { key = "<Super><Primary>Left";  value = "prev_workspace_key"; wm = true; desc = "Previous workspace"; }
        { key = "<Super><Primary>Right"; value = "next_workspace_key"; wm = true; desc = "Next workspace"; }
        # Alt+F4 owns the native close_window_key action; Super+Q closes via a command
        # (wmctrl) because xfwm4 allows only ONE shortcut per window action — mapping both
        # to close_window_key drops one. Same reason Alt+F10/Alt+F9 are omitted: Super+Up/Down
        # already own maximize/minimize, and a second key on the same action is ignored.
        { key = "<Alt>F4";             value = "close_window_key";              wm = true; desc = "Close window"; }
        { key = "<Super>q";            value = "wmctrl -c :ACTIVE:";            desc = "Close window"; }
        # Bare F11 (not Super+F11) for Windows-familiar fullscreen. xfwm4 grabs it globally,
        # so in-app F11 (browser/video) toggles WM fullscreen instead — intentional trade-off.
        { key = "F11";                 value = "fullscreen_key";                wm = true; desc = "Toggle fullscreen"; }
        { key = "<Super>d";            value = "show_desktop_key";              wm = true; desc = "Show desktop"; }
        { key = "<Alt>Tab";            value = "cycle_windows_key";             wm = true; desc = "Switch window"; }
        { key = "<Alt><Shift>Tab";     value = "cycle_reverse_windows_key";     wm = true; desc = "Switch window (reverse)"; }
        # Kept xfwm4 defaults — hidden from cheatsheet. The Ctrl+Alt+Left/Right workspace
        # defaults use the left_/right_workspace_key actions, so they don't collide with the
        # Super+Ctrl prev_/next_workspace_key binds above (different actions).
        { key = "<Alt>F7";             value = "move_window_key";               wm = true; cheat = false; }
        { key = "<Alt>F8";             value = "resize_window_key";             wm = true; cheat = false; }
        { key = "<Alt>space";          value = "popup_menu_key";                wm = true; cheat = false; }
        { key = "<Primary><Alt>Left";  value = "left_workspace_key";            wm = true; cheat = false; }
        { key = "<Primary><Alt>Right"; value = "right_workspace_key";           wm = true; cheat = false; }
      ]; }
    { title = "Applications"; binds = [
        { key = "<Super>Return"; value = apps.terminal; desc = "Terminal (kitty)"; }
        { key = "<Super>f";      value = "thunar";      desc = "Files"; }
        { key = "<Super>b";      value = apps.browser;  desc = "Web browser"; }
        { key = "<Super>i";      value = apps.ide;      desc = "Code editor (VS Code)"; }
        { key = "<Super>t";      value = "mousepad";    desc = "Text editor (Mousepad)"; }
        { key = "<Super>m";      value = "spotify";     desc = "Music (Spotify)"; }
        { key = "<Super>c";      value = apps.chat;     desc = "Chat (Discord)"; }
        { key = "<Super>g";      value = apps.gaming;   desc = "Games (Steam)"; }
        { key = "<Super>p";      value = "bitwarden";   desc = "Password manager"; }
      ]; }
    { title = "System"; binds = [
        { key = "<Super>space";           value = "xfce4-popup-whiskermenu"; cheat = false; } # shown in Start
        { key = "<Primary>Escape";        value = "xfce4-popup-whiskermenu"; cheat = false; } # paired w/ Super-tap
        { key = "<Super>l";               value = "xflock4";                 desc = "Lock screen"; }
        { key = "<Super>BackSpace";       value = "xfce4-session-logout";    desc = "Log out"; }
        { key = "<Super>v";               value = "xfce4-popup-clipman";     desc = "Clipboard history"; }
        { key = "<Super><Shift>s";        value = "xfce4-screenshooter -r";  desc = "Screenshot (region)"; }
        { key = "Print";                  value = "xfce4-screenshooter -f";  desc = "Screenshot (whole screen)"; }
        { key = "<Primary><Shift>Escape"; value = "xfce4-taskmanager";       desc = "Task Manager"; }
      ]; }
  ] ++ lib.optional (monitors != []) { title = "Displays"; binds = displayBinds; };

  # Drop command binds whose app role is unset (command = "", i.e. package = null on this
  # host) so neither the xfconf XML nor the cheatsheet advertises a shortcut that does
  # nothing. WM action binds always have a literal value and are never filtered.
  groups = map (g: g // {
    binds = lib.filter (b: (b.wm or false) || b.value != "") g.binds;
  }) groupsRaw;

  allBinds = lib.concatMap (g: g.binds) groups;
  esc = lib.replaceStrings [ "<" ">" ] [ "&lt;" "&gt;" ];
  xmlLine = b: ''          <property name="${esc b.key}" type="string" value="${b.value}"/>'';

  # Super+1..9,0 → switch to workspace N; Super+Shift+1..9,0 → move active window there
  # (Super+0 = workspace 10). XML-only; the cheatsheet shows a two-line summary. Note the
  # theme's xfwm4.xml sets workspace_count=4, so 5..0 are declared but inert until it's raised.
  wsXmlLines = lib.concatMap (n:
    let s = if n == 10 then "0" else toString n; in [
      ''          <property name="&lt;Super&gt;${s}" type="string" value="workspace_${toString n}_key"/>''
      ''          <property name="&lt;Super&gt;&lt;Shift&gt;${s}" type="string" value="move_window_workspace_${toString n}_key"/>''
    ]) (lib.range 1 10);

  wmXml  = lib.concatStringsSep "\n" (map xmlLine (lib.filter (b: b.wm or false) allBinds) ++ wsXmlLines);
  cmdXml = lib.concatStringsSep "\n"
    (map xmlLine (lib.filter (b: !(b.wm or false)) allBinds)
     ++ [ ''          <property name="&lt;Super&gt;slash" type="string" value="${cheatScript}"/>'' ]);

  keyboardShortcutsXml = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfce4-keyboard-shortcuts" version="1.0">
      <property name="xfwm4" type="empty">
        <property name="custom" type="empty">
    ${wmXml}
          <property name="override" type="bool" value="true"/>
        </property>
      </property>
      <property name="commands" type="empty">
        <property name="custom" type="empty">
    ${cmdXml}
          <property name="override" type="bool" value="true"/>
        </property>
      </property>
    </channel>
  '';

  # ---- Cheatsheet (Super+/) ---------------------------------------------------------------
  # Human-readable key label, e.g. "<Super><Shift>s" → "Super + Shift + s". Proportional font
  # (zenity), so entries use " — " separators rather than space-padded columns.
  keyLabel = key: lib.foldl' (s: r: lib.replaceStrings [ (builtins.elemAt r 0) ] [ (builtins.elemAt r 1) ] s) key [
    [ "<Super>" "Super + " ] [ "<Primary>" "Ctrl + " ] [ "<Alt>" "Alt + " ] [ "<Shift>" "Shift + " ]
    [ "Return" "Enter" ] [ "BackSpace" "Backspace" ] [ "Escape" "Esc" ]
    [ "KP_7" "Num 7" ] [ "KP_9" "Num 9" ] [ "KP_1" "Num 1" ] [ "KP_3" "Num 3" ]
  ];
  cheatLine = b: "  ${keyLabel b.key} — ${b.desc}";
  cheatGroup = g:
    let shown = lib.filter (b: (b.cheat or true) && (b ? desc)) g.binds;
    in "${g.title}\n" + lib.concatMapStringsSep "\n" cheatLine shown;

  cheatText = ''
    Windows 7 — Keyboard Shortcuts
    (Super = the Windows key)

    Start
      Super (tap) — Start menu
      Super + Space — Start menu
      Super + / — Show this cheatsheet

  '' + lib.concatMapStringsSep "\n\n" cheatGroup groups + ''


    Workspaces
      Super + 1…0 — Switch to workspace 1–10
      Super + Shift + 1…0 — Move active window to workspace
  '';

  cheatFile = pkgs.writeText "win7-xfce-keybinds.txt" cheatText;
  # yad (GTK3) — NOT zenity: zenity 4.x is libadwaita/GTK4, which hardcodes Adwaita and ignores
  # the Windows-7 GTK theme + xfwm4 decorations (see xfce.nix's libadwaita note). yad is GTK3,
  # so it renders in the Win7 theme with a real xfwm4 Win7 titlebar.
  cheatScript = pkgs.writeShellScript "win7-xfce-cheatsheet" ''
    exec ${pkgs.yad}/bin/yad --text-info \
      --title="Keyboard Shortcuts" \
      --width=520 --height=720 --center --wrap \
      --filename=${cheatFile} \
      --button="Close":0
  '';

  # Super-tap → Ctrl+Esc (bound to the Whisker menu in the XML above). Super still modifies
  # normal combos. The whisker bind itself now lives in the seeded XML, so this only runs xcape.
  startKeyScript = pkgs.writeShellScript "win7-start-key" ''
    exec ${pkgs.xcape}/bin/xcape -e 'Super_L=Control_L|Escape'
  '';

  # Force NumLock on so the numpad emits KP_7/9/1/3 (the quadrant-tile binds above) rather
  # than KP_Home/Prior/End/Next. xfwm4 binds one accelerator per action, so we can't cover
  # both NumLock states — pinning it on makes the numpad diagonals deterministic.
  numlockScript = pkgs.writeShellScript "win7-numlock" ''
    exec ${pkgs.numlockx}/bin/numlockx on
  '';
in {
  config = lib.mkIf win7XfceCondition {
    # xcape for the Super-tap; clipman provides xfce4-popup-clipman (Super+V) and taskmanager
    # backs Ctrl+Shift+Esc (both also in the default XFCE suite — harmless store-path dedup).
    # yad (the cheatsheet popup) is pulled in via the script's store-path reference.
    home.packages = [
      pkgs.xcape
      pkgs.xfce.xfce4-clipman-plugin
      pkgs.xfce.xfce4-taskmanager
      pkgs.wmctrl                       # Super+Q close (xfwm4 allows one key per action)
      pkgs.numlockx                     # NumLock-on autostart (numpad quadrant binds)
    ];

    xdg.configFile = {
      "${xfconfDir}/xfce4-keyboard-shortcuts.xml".text = keyboardShortcutsXml;

      "autostart/win7-start-key.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Windows 7 Start key
        Exec=${startKeyScript}
        OnlyShowIn=XFCE;
        X-XFCE-Autostart-enabled=true
      '';

      "autostart/win7-numlock.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Windows 7 NumLock on
        Exec=${numlockScript}
        OnlyShowIn=XFCE;
        X-XFCE-Autostart-enabled=true
      '';
    };
  };
}
