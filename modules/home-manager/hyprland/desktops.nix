# ~/nixos-config/modules/home-manager/hyprland/desktops.nix
# Hyprland desktops (customConfig.homeManager.hyprland.desktops): imports every
# desktops/<name>/, declares its hyprDesktops.<name> options (desktops/lib.nix), and
# turns each enabled one into a Hyprland config:
#
# - the default desktop's settings go into wayland.windowManager.hyprland, so
#   home-manager writes them into ~/.config/hypr/hyprland.conf as before;
# - every other enabled desktop is rendered to ~/.config/hypr/desktops/<name>.conf,
#   which that desktop's display-manager entry starts Hyprland with
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
    + mergeOnto hyprOpts.extraConfig (rawDefs name "extraConfig");

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

  hyprDesktop = pkgs.writeShellScriptBin "hypr-desktop" ''
    set -u
    current() {
      ${systemctl} --user list-units --type=target --state=active --plain --no-legend \
          'hypr-desktop-*.target' 2>/dev/null \
        | ${pkgs.gawk}/bin/awk 'NR == 1 { n = $1; sub(/^hypr-desktop-/, "", n); sub(/\.target$/, "", n); print n }'
    }
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
        [ -n "''${2:-}" ] || { echo "usage: hypr-desktop session-start <desktop>" >&2; exit 2; }
        ${systemctl} --user stop hypr-desktop-session.service
        ${systemctl} --user import-environment HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY
        exec ${systemctl} --user start "hypr-desktop-$2.target" ;;
      *)
        echo "usage: hypr-desktop current|list" >&2
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
          (rawDefs dcfg.default o)));
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
