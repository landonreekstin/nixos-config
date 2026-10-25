# ~/nixos-config/modules/home-manager/hyprland/desktops.nix
# Hyprland desktops (customConfig.homeManager.hyprland.desktops): imports every
# desktops/<name>/, declares its hyprDesktops.<name> options (desktops/lib.nix), and
# turns each enabled one into a Hyprland config:
#
# - the default desktop's settings go into wayland.windowManager.hyprland, and the
#   file home-manager renders from them becomes ~/.config/hypr/desktops/<default>.conf;
# - every other enabled desktop is rendered to ~/.config/hypr/desktops/<name>.conf;
# - ~/.config/hypr/hyprland.conf, which every session starts with, only picks one
#   of those by the environment: none of these variables set, the default;
#   HYPR_DESKTOP_AWAY and HYPR_DESKTOP_IS_<name> (desktops/lib.nix envVar) set,
#   desktop <name>. That desktop's display-manager entry sets them
#   (modules/nixos/desktop/hyprland.nix).
#
# How a non-default desktop's config is built: home-manager merges every module's
# wayland.windowManager.hyprland.* into the ONE hyprland.conf, and once merged
# nothing can be taken back out. So instead of reading the merged value, each
# desktop's file re-merges the option's individual definitions — the functional
# layer's (functional.nix, swayidle.nix, ...), i.e. all of them except the default
# desktop's, which this file forwards — with the desktop's own, keeping priorities.
# The functional layer therefore reaches every desktop from a single source.
#
# The rule that makes this work: a desktop module never writes
# wayland.windowManager.hyprland.{settings,extraConfig,plugins} itself, only
# hyprDesktops.<name>.*. The assertion below enforces it.
#
# Which desktop is live: every desktop's config starts with
# `hypr-desktop session-start <name>`, which starts the systemd user target
# hypr-desktop-<name>.target. That target is bound to hypr-desktop-session.service,
# which lives exactly as long as the compositor, so the target (and every unit
# bound to it with desktops/lib.nix `bindTo`) stops when the session ends.
# Scripts ask `hypr-desktop current`.
#
# A desktop's own startup lines (exec-once in hyprDesktops.<name>.extraConfig) run
# through `hypr-desktop run <name>`, in a systemd scope that is PartOf its target,
# so what they start stops with the desktop too.
#
# Switching live (`hypr-desktop switch <name>`) sets those variables in the
# compositor (`hyprctl keyword env`) and reloads: hyprlang re-reads the
# environment on every parse, so hyprland.conf then picks the other desktop. Not
# `hyprctl reload full-reset` with a new HYPRLAND_CONFIG, the only way Hyprland
# changes its config path: in 0.55 that crashes in flushCaches, at once if a
# plugin was ever loaded and sooner or later otherwise. A reload runs no exec-once
# line, so the switch does the rest of what login would have: it loads and
# unloads plugins, sets the new desktop's session environment, starts its target
# (which stops the old one), runs the startup lines the old config lacked, stops
# the daemons the new one lacks, and restarts waybar.
{ config, options, pkgs, lib, customConfig, ... }:

let
  dcfg = customConfig.homeManager.hyprland.desktops;
  on = lib.elem "hyprland" customConfig.desktop.environments;
  desktopLib = import ./desktops/lib.nix { inherit lib; };

  # Every subdirectory of desktops/ is a desktop.
  desktopNames = lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir ./desktops));

  hyprOpts = options.wayland.windowManager.hyprland;
  declared = options.hyprDesktops;
  forwarded = [ "settings" "extraConfig" "plugins" ];

  fromHere = def: lib.hasSuffix "/modules/home-manager/hyprland/desktops.nix" (toString def.file);
  fromADesktop = def: lib.hasInfix "/modules/home-manager/hyprland/desktops/" (toString def.file);

  # Re-merge one Hyprland option from the functional layer's definitions plus
  # `desktopDefs`.
  mergeOnto = opt: desktopDefs:
    (lib.modules.mergeDefinitions opt.loc opt.type
      (lib.filter (d: !fromHere d) opt.definitionsWithLocations ++ desktopDefs)).mergedValue;

  # A desktop's raw definitions of one of its options, priorities intact.
  rawDefs = name: o: declared.${name}.${o}.definitionsWithLocations;

  pluginPath = entry:
    if lib.types.package.check entry then "${entry}/lib/lib${entry.pname}.so" else entry;

  # A desktop's extraConfig, with each exec-once line run in the desktop's scope.
  ownStartup = name: text: lib.concatMapStringsSep "\n" (line:
    let m = builtins.match "([[:space:]]*)exec-once[[:space:]]*=[[:space:]]*(.*)" line; in
    if m == null then line
    else "${lib.elemAt m 0}exec-once = ${hyprDesktop}/bin/hypr-desktop run ${name} ${lib.escapeShellArg (lib.elemAt m 1)}")
    (lib.splitString "\n" text);
  # Into mkOrder/mkIf/mkMerge to the strings inside.
  mapContent = f: v:
    if v ? _type && v ? content then v // { content = mapContent f v.content; }
    else if v ? _type && v ? contents then v // { contents = map (mapContent f) v.contents; }
    else f v;
  extraConfigDefs = name:
    map (d: d // { value = mapContent (ownStartup name) d.value; }) (rawDefs name "extraConfig");

  confPath = name: "${config.xdg.configHome}/hypr/desktops/${name}.conf";

  # hyprland.conf. One level of `# hyprlang if` only: hyprlang does not nest them.
  selector = ''
    # Written by hyprland/desktops.nix: sources the desktop the environment names.
    # hyprlang if !HYPR_DESKTOP_AWAY
    source = ${confPath dcfg.default}
    # hyprlang endif
  '' + lib.concatMapStrings (n: ''
    # hyprlang if ${desktopLib.envVar n}
    source = ${confPath n}
    # hyprlang endif
  '') sessionDesktops;

  render = name:
    let
      importantPrefixes = config.wayland.windowManager.hyprland.importantPrefixes;
      settings = config.hyprDesktops.${name}.transformSettings
        ((if config.hyprDesktops.${name}.waybar then lib.id else dropWaybar)
          (mergeOnto hyprOpts.settings (rawDefs name "settings")));
      plugins = mergeOnto hyprOpts.plugins (rawDefs name "plugins");
    in
    # The same order home-manager writes hyprland.conf in: plugins, settings,
    # extraConfig. The session's start comes before all of it.
    sessionStart name
    + lib.optionalString (plugins != [ ]) (lib.hm.generators.toHyprconf {
      attrs."exec-once" = map (p: "hyprctl plugin load ${pluginPath p}") plugins;
      inherit importantPrefixes;
    })
    + lib.hm.generators.toHyprconf { attrs = settings; inherit importantPrefixes; }
    + mergeOnto hyprOpts.extraConfig (extraConfigDefs name);

  sessionDesktops = lib.filter (n: n != dcfg.default) dcfg.enabled;

  dropWaybar = s: s // {
    "exec-once" = lib.filter (l: !lib.hasInfix "waybar-start" l) (s."exec-once" or [ ]);
  };

  systemctl = "${pkgs.systemd}/bin/systemctl";

  # Lives exactly as long as the compositor whose session started it: the
  # desktop targets bind to it, so they stop when Hyprland exits.
  # The pid comes from the instance's lock file. Not `hyprctl instances`: at login
  # it can catch an instance half-written and print invalid JSON.
  sessionWatch = pkgs.writeShellScript "hypr-desktop-session" ''
    lock="$XDG_RUNTIME_DIR/hypr/''${HYPRLAND_INSTANCE_SIGNATURE:-}/hyprland.lock"
    for _ in $(${pkgs.coreutils}/bin/seq 1 50); do
      pid=$(${pkgs.coreutils}/bin/head -n1 "$lock" 2>/dev/null)
      case "$pid" in ""|*[!0-9]*) ;; *) kill -0 "$pid" 2>/dev/null && break ;; esac
      pid=
      ${pkgs.coreutils}/bin/sleep 0.1
    done
    [ -n "$pid" ] || { echo "no live Hyprland behind $lock" >&2; exit 1; }
    exec ${pkgs.coreutils}/bin/tail --pid="$pid" -f /dev/null
  '';

  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  pkill = "${pkgs.procps}/bin/pkill";

  # What `switch` needs to know about each desktop, as shell variables.
  desktopVars = name:
    let
      d = config.hyprDesktops.${name};
      env = d.sessionEnv;
      exports = n: v: "${n}=${lib.escapeShellArg v}";
    in ''
      ${name})
        ${exports "conf" (confPath name)}
        ${exports "plugins" (lib.concatMapStringsSep " " pluginPath (mergeOnto hyprOpts.plugins (rawDefs name "plugins")))}
        ${exports "leave" (pkgs.writeText "hypr-desktop-${name}-leave" d.leaveExtraConfig)}
        ${exports "bar" (if name == dcfg.default || d.waybar then "1" else "")}
        ${exports "apps" (env.HYPR_DESKTOP_APPS or "")}
        ${exports "kitty" (env.KITTY_CONFIG_DIRECTORY or "${config.xdg.configHome}/kitty")}
        ${exports "gtk" (env.GTK_THEME or "")} ;;
    '';

  hyprDesktop = pkgs.writeShellScriptBin "hypr-desktop" ''
    set -u
    current() {
      ${systemctl} --user list-units --type=target --state=active --plain --no-legend \
          'hypr-desktop-*.target' 2>/dev/null \
        | ${pkgs.gawk}/bin/awk 'NR == 1 { n = $1; sub(/^hypr-desktop-/, "", n); sub(/\.target$/, "", n); print n }'
    }
    desktop() {
      case "$1" in
        ${lib.concatMapStrings desktopVars dcfg.enabled}
        *) return 1 ;;
      esac
    }
    # Also as a notification: from the keybind there is no terminal to read.
    die() {
      echo "hypr-desktop: $*" >&2
      ${pkgs.libnotify}/bin/notify-send -a hypr-desktop "Can't switch desktop" "$*" 2>/dev/null
      exit 1
    }
    # The exec-once commands of a config file.
    startup() { ${pkgs.gnused}/bin/sed -n 's/^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*//p' "$1" 2>/dev/null | ${pkgs.coreutils}/bin/sort -u; }

    case "''${1:-}" in
      current)
        current ;;
      list)
        cur=$(current)
        for n in ${lib.concatStringsSep " " dcfg.enabled}; do
          if [ "$n" = "$cur" ]; then echo "* $n"; else echo "  $n"; fi
        done ;;
      session-start)
        # Run from the desktop's own config at login (exec-once). The compositor's
        # instance goes into the user manager first: the session watcher needs it to
        # find the compositor, and so do units that talk to it (hyprctl, the pad).
        # A watcher still running from an older session is stopped first, but only
        # then: stopping it stops every desktop scope, including ones this
        # session's own startup lines may already have created.
        [ -n "''${2:-}" ] || { echo "usage: hypr-desktop session-start <desktop>" >&2; exit 2; }
        if ${systemctl} --user -q is-active hypr-desktop-session.service; then
          ${systemctl} --user stop hypr-desktop-session.service
        fi
        ${systemctl} --user import-environment HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY
        exec ${systemctl} --user start "hypr-desktop-$2.target" ;;
      run)
        # A desktop's startup line, in a scope that stops with its target.
        [ $# -eq 3 ] || { echo "usage: hypr-desktop run <desktop> <command>" >&2; exit 2; }
        if [ -S "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus" ]; then
          exec ${pkgs.systemd}/bin/systemd-run --user --scope --quiet --collect \
            --slice=app.slice -p "PartOf=hypr-desktop-$2.target" -- /bin/sh -c "$3"
        fi
        exec /bin/sh -c "$3" ;;
      switch)
        new=''${2:-}
        [ -n "$new" ] || { echo "usage: hypr-desktop switch <desktop>" >&2; exit 2; }
        [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || die "not inside a Hyprland session"
        cur=$(current)
        [ -n "$cur" ] || die "no desktop is live"
        [ "$cur" = "$new" ] && exit 0
        desktop "$cur" || die "the live desktop $cur is not enabled any more; log out instead"
        o_conf=$conf o_plugins=$plugins o_leave=$leave
        desktop "$new" || die "no desktop $new (hypr-desktop list)"

        # The new desktop's plugins, before the config that sets their options.
        for p in $plugins; do
          case " $o_plugins " in *" $p "*) ;; *) ${hyprctl} plugin load "$p" >/dev/null ;; esac
        done

        # Which desktop hyprland.conf sources, and the session environment the new desktop's entry would have started with.
        # PATH is ours (inherited from the compositor) without any desktop's app
        # wrappers (desktop-apps.nix). Not the compositor's own: it runs with
        # capabilities, so /proc/<pid>/environ is unreadable.
        path=$(printf '%s' "$PATH" | ${pkgs.coreutils}/bin/tr ':' '\n' \
          | ${pkgs.gnugrep}/bin/grep -v '/hypr/desktops/[^/]*/bin$' | ${pkgs.coreutils}/bin/paste -sd:)
        [ -n "$path" ] || die "empty PATH"
        [ -n "$apps" ] && path="$apps/bin:$path"
        away=1
        [ "$new" = ${lib.escapeShellArg dcfg.default} ] && away=
        cmds="keyword env HYPR_DESKTOP_AWAY,$away"
        for pair in ${lib.concatMapStringsSep " " (n: "${n}=${desktopLib.envVar n}") sessionDesktops}; do
          v=
          [ "''${pair%%=*}" = "$new" ] && v=1
          cmds="$cmds; keyword env ''${pair#*=},$v"
        done
        ${hyprctl} --batch "$cmds; keyword env PATH,$path; keyword env HYPR_DESKTOP_APPS,$apps; keyword env KITTY_CONFIG_DIRECTORY,$kitty" >/dev/null
        [ -n "$gtk" ] && ${hyprctl} keyword env "GTK_THEME,$gtk" >/dev/null

        # Then the old desktop's plugins can go, and the new target start: it
        # conflicts with the old one, which stops, and with it the old desktop's
        # units and scopes.
        ${hyprctl} reload >/dev/null
        for p in $o_plugins; do
          case " $plugins " in *" $p "*) ;; *) ${hyprctl} plugin unload "$p" >/dev/null ;; esac
        done
        ${systemctl} --user start "hypr-desktop-$new.target"

        # Daemons the old config backgrounded and the new one does not start
        # (the wallpaper daemon, leaving for xbox360): stopped by their binary.
        old=$(startup "$o_conf") new_lines=$(startup "$conf")
        ${pkgs.coreutils}/bin/comm -23 <(echo "$old") <(echo "$new_lines") \
          | ${pkgs.gnugrep}/bin/grep -E '^/nix/store/[^ ]+( .*)? &$' | while IFS= read -r l; do
            bin=''${l%% *}
            ${pkill} -f "^$(printf '%s' "$bin" | ${pkgs.gnused}/bin/sed 's/[.+]/\\&/g')( |$)" || true
          done

        # The startup lines login would have run that the old config did not
        # (plus the old desktop's way out), except the target (done) and waybar
        # (below).
        { ${pkgs.coreutils}/bin/comm -13 <(echo "$old") <(echo "$new_lines"); startup "$o_leave"; } \
          | ${pkgs.gnugrep}/bin/grep -v -e 'hypr-desktop session-start' -e 'hyprctl plugin load' -e 'waybar-start' \
          | ${pkgs.gawk}/bin/awk 'NF && !seen[$0]++' | while IFS= read -r l; do
            ${hyprctl} dispatch exec "$l" >/dev/null
          done

        # Through the compositor, so the bars get the new environment.
        if [ -n "$bar" ]; then
          ${hyprctl} dispatch exec "$HOME/.local/bin/waybar-restart" >/dev/null
        else
          ${pkill} -f 'bin/waybar-start' || true
          ${pkill} -f 'bin/waybar( |$)' || true
        fi ;;
      pick)
        # A menu of the desktops (Super+Shift+D).
        cur=$(current)
        new=$(for n in ${lib.concatStringsSep " " dcfg.enabled}; do [ "$n" = "$cur" ] || echo "$n"; done \
          | rofi -dmenu -i -p DESKTOP) || exit 0
        [ -n "$new" ] && exec "$0" switch "$new" ;;
      *)
        echo "usage: hypr-desktop current|list|switch <desktop>|pick" >&2
        exit 2 ;;
    esac
  '';

  sessionStart = name: "exec-once = ${hyprDesktop}/bin/hypr-desktop session-start ${name}\n";

  # The same reload home-manager does for hyprland.conf: `hyprctl reload` re-reads
  # whichever file each running instance was started with.
  reload = ''
    (
      XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
      if [[ -d "$XDG_RUNTIME_DIR/hypr" ]]; then
        for i in $(${pkgs.hyprland}/bin/hyprctl instances -j | ${pkgs.jq}/bin/jq -r ".[].instance"); do
          ${pkgs.hyprland}/bin/hyprctl -i "$i" reload config-only
        done
      fi
    )
  '';
in
{
  imports = map (n: ./desktops + "/${n}") desktopNames;

  options.hyprDesktops = lib.genAttrs desktopNames (_: desktopLib.desktopOptions);

  config = lib.mkIf on (lib.mkMerge [
    {
      assertions = [
        {
          assertion = dcfg.default == null || lib.elem dcfg.default dcfg.enabled;
          message = ''
            customConfig.homeManager.hyprland.desktops.default is "${toString dcfg.default}",
            which is not in desktops.enabled.
          '';
        }
      ] ++ map (o:
        let bad = lib.filter fromADesktop hyprOpts.${o}.definitionsWithLocations; in {
          assertion = bad == [ ];
          message = ''
            wayland.windowManager.hyprland.${o} is set from a desktop module:
              ${lib.concatMapStringsSep "\n  " (d: toString d.file) bad}
            A desktop sets hyprDesktops.<name>.${o} instead
            (see modules/home-manager/hyprland/desktops.nix).
          '';
        }) forwarded;

      home.packages = [ hyprDesktop ];

      # A rebuild must never restart these: that would stop the live desktop's
      # target and every unit bound to it (keep-old: the new version applies from
      # the next login).
      systemd.user.services.hypr-desktop-session = {
        Unit = {
          Description = "The running Hyprland session (stops with the compositor)";
          X-SwitchMethod = "keep-old";
        };
        Service = {
          ExecStart = "${sessionWatch}";
          # The instance is dead; nothing should keep talking to it.
          ExecStopPost = "${systemctl} --user unset-environment HYPRLAND_INSTANCE_SIGNATURE";
        };
      };
      systemd.user.targets = lib.listToAttrs (map (name:
        lib.nameValuePair "hypr-desktop-${name}" {
          Unit = {
            Description = "Hyprland desktop ${name}";
            BindsTo = [ "hypr-desktop-session.service" ];
            After = [ "hypr-desktop-session.service" ];
            # One desktop at a time.
            Conflicts = map desktopLib.target (lib.remove name dcfg.enabled);
            X-SwitchMethod = "keep-old";
          };
        }) dcfg.enabled);

      xdg.configFile = lib.listToAttrs (map (name:
        lib.nameValuePair "hypr/desktops/${name}.conf" {
          text = render name;
          onChange = reload;
        }) sessionDesktops);
    }

    # The default desktop goes to home-manager as-is, so hyprland.conf is built
    # exactly as if its modules had written there themselves. Its extraConfig
    # leads the file's (mkOrder 500), as it did when themes wrote it directly.
    (lib.mkIf (dcfg.default != null) {
      wayland.windowManager.hyprland = lib.genAttrs forwarded (o:
        lib.mkMerge (map (d: if o == "extraConfig" then lib.mkOrder 500 d.value else d.value)
          (if o == "extraConfig" then extraConfigDefs dcfg.default else rawDefs dcfg.default o)));

      # The file home-manager renders from that moves next to the other desktops'
      # (only enabled files count as targets, so the selector can take its place).
      xdg.configFile."hypr/hyprland.conf".enable = lib.mkForce false;
      xdg.configFile."hypr/desktops/${dcfg.default}.conf" = {
        inherit (config.xdg.configFile."hypr/hyprland.conf") text;
        onChange = reload;
      };
      xdg.configFile.hypr-desktop-selector = {
        target = "hypr/hyprland.conf";
        text = selector;
        onChange = reload;
      };
    })

    # The default session starts its target first, and undoes whatever the other
    # desktops leave set. extraConfig, not exec-once: functional.nix's exec-once
    # list is mkDefault.
    (lib.mkIf (dcfg.default != null) {
      wayland.windowManager.hyprland.extraConfig = lib.mkOrder 400 (sessionStart dcfg.default
        + lib.concatMapStrings (n: config.hyprDesktops.${n}.leaveExtraConfig) sessionDesktops);
    })
  ]);
}
