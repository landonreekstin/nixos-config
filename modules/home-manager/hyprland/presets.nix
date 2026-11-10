# ~/nixos-config/modules/home-manager/hyprland/presets.nix
# App presets (customConfig.homeManager.hyprland.presets): `hypr-preset <name>` lays
# out a set of apps across monitors and workspaces, bound to Super+<key> and offered
# as launcher-bar buttons (de-wm-components/waybar/functional.nix).
#
# Workspaces are relative to each monitor, not fixed IDs: slot 1 is whatever the
# monitor shows when the preset runs, slot 2+ a new empty workspace created on it.
# Hyprland's numbered workspaces belong to no monitor, so every move is followed by
# a check that the workspace really is on the target monitor (a new one is created
# on whichever monitor has focus, often the TV).
#
# Apps already open are moved rather than started again. An app with a window
# already on its target monitor is left alone, which makes re-running a preset a
# no-op instead of a workspace factory. Windows on special or named workspaces
# (negative IDs: the ckb utility drawer, the stream walls' PiP tiles) are never
# taken.
#
# Freshly started apps are placed by a background watcher, not just by the exec
# rule: `[workspace N silent]` only matches windows from the PID it started, which
# misses Flatpak Discord, Steam handing over to an already-running instance, and
# Steam's updater window giving way to the main one.
{ config, pkgs, lib, customConfig, ... }:

let
  presets = customConfig.homeManager.hyprland.presets;
  on = lib.elem "hyprland" customConfig.desktop.environments && presets != { };

  monitorNamed = n: lib.findFirst (m: m.name == n) null customConfig.desktop.monitors;
  # Same identifier rule as generateMonitorConfig in functional.nix.
  hyprId = m:
    if lib.hasPrefix "desc:" m.identifier then m.identifier
    else if lib.hasInfix " " m.identifier || lib.hasInfix "." m.identifier then "desc:${m.identifier}"
    else m.identifier;

  unknownMonitors = lib.unique (lib.concatMap (p: lib.filter (n: monitorNamed n == null)
    (map (a: a.monitor) p.apps)) (lib.attrValues presets));

  spec = pkgs.writeText "hypr-presets.json" (builtins.toJSON (lib.mapAttrs (_: p: {
    inherit (p) label key;
    apps = map (a: {
      inherit (a) command class slot;
      monitor = let m = monitorNamed a.monitor; in if m == null then a.monitor else hyprId m;
    }) p.apps;
  }) presets));

  hyprPreset = pkgs.writeShellApplication {
    name = "hypr-preset";
    runtimeInputs = [ pkgs.hyprland pkgs.jq pkgs.coreutils pkgs.libnotify ];
    text = ''
      spec=${spec}

      if [ $# -eq 0 ] || [ "$1" = list ]; then
        jq -r 'to_entries[] | "\(.key)\t\(.value.label)\tSuper+\(.value.key // "-")\t\(.value.apps | map(.class) | join(", "))"' "$spec"
        exit 0
      fi

      name=$1
      preset=$(jq -c --arg n "$name" '.[$n] // empty' "$spec")
      if [ -z "$preset" ]; then
        echo "hypr-preset: no preset '$name' (try: hypr-preset list)" >&2
        exit 1
      fi

      monitors=$(hyprctl -j monitors)

      # A configured identifier (connector or desc:...) -> live monitor name.
      monitor_name() {
        jq -r --arg id "$1" '
          map(select(.name == $id or (("desc:" + .description) | startswith($id))))[0].name // empty
        ' <<<"$monitors"
      }

      # Windows of class regex $1 on real (numbered) workspaces, as "address workspace monitor".
      windows_of() {
        hyprctl -j clients | jq -r --arg c "$1" '
          .[] | select(.workspace.id > 0) | select(.class | test("^(?:" + $c + ")$"; "i"))
          | "\(.address) \(.workspace.id) \(.monitor)"'
      }

      monitor_id() { jq -r --arg n "$1" 'map(select(.name == $n))[0].id' <<<"$monitors"; }

      # "monitor:slot" -> workspace ID, fixed for the whole run. Sets $ws rather than
      # printing it: called in a $(...) subshell, the reservations below would be
      # lost and two new slots would get the same ID.
      declare -A taken=() slots=()
      while read -r id; do taken[$id]=1; done < <(hyprctl -j workspaces | jq -r '.[].id')
      workspace_for() {
        local mon=$1 slot=$2 key="$1:$2" id=1
        if [ -z "''${slots[$key]:-}" ]; then
          if [ "$slot" -eq 1 ]; then
            slots[$key]=$(jq -r --arg n "$mon" 'map(select(.name == $n))[0].activeWorkspace.id' <<<"$monitors")
          else
            # Lowest workspace ID nobody uses, reserved for this run.
            while [ -n "''${taken[$id]:-}" ]; do id=$((id + 1)); done
            taken[$id]=1
            slots[$key]=$id
          fi
        fi
        ws=''${slots[$key]}
      }

      # Move one window to workspace $2 and make sure that workspace sits on monitor $3.
      place() {
        local addr=$1 ws=$2 mon=$3 on
        hyprctl dispatch movetoworkspacesilent "$ws,address:$addr" >/dev/null
        on=$(hyprctl -j workspaces | jq -r --argjson w "$ws" 'map(select(.id == $w))[0].monitor // empty')
        if [ -n "$on" ] && [ "$on" != "$mon" ]; then
          hyprctl dispatch moveworkspacetomonitor "$ws" "$mon" >/dev/null
        fi
      }

      # After a launch: place every window of the class that turns up, for up to 45 s
      # (Steam is slow), stopping 3 s after the first one lands.
      watch_launch() {
        local class=$1 ws=$2 mon=$3 deadline=$((SECONDS + 45)) landed=0 addr w _m
        while [ "$SECONDS" -lt "$deadline" ]; do
          while read -r addr w _m; do
            [ -n "$addr" ] || continue
            if [ "$w" != "$ws" ]; then place "$addr" "$ws" "$mon"; fi
            if [ "$landed" -eq 0 ]; then
              landed=1
              deadline=$((SECONDS + 3))
            fi
          done < <(windows_of "$class")
          sleep 0.5
        done
      }

      first_ws=""
      first_mon=""
      while read -r app; do
        command=$(jq -r .command <<<"$app")
        class=$(jq -r .class <<<"$app")
        slot=$(jq -r .slot <<<"$app")
        mon=$(monitor_name "$(jq -r .monitor <<<"$app")")
        if [ -z "$mon" ]; then
          notify-send -a hypr-preset "Preset $name" "Monitor $(jq -r .monitor <<<"$app") is not connected: skipped $class"
          continue
        fi
        monid=$(monitor_id "$mon")
        workspace_for "$mon" "$slot"
        if [ -z "$first_ws" ]; then first_ws=$ws; first_mon=$mon; fi

        existing=$(windows_of "$class")
        if [ -n "$existing" ]; then
          # Already on its monitor: leave it where the user put it.
          if awk -v m="$monid" '$3 == m { found = 1 } END { exit !found }' <<<"$existing"; then
            continue
          fi
          while read -r addr _w _m; do place "$addr" "$ws" "$mon"; done <<<"$existing"
        else
          hyprctl dispatch exec "[workspace $ws silent] $command" >/dev/null
          watch_launch "$class" "$ws" "$mon" &
          disown
        fi
      done < <(jq -c '.apps[]' <<<"$preset")

      if [ -n "$first_ws" ]; then
        hyprctl dispatch focusmonitor "$first_mon" >/dev/null
        hyprctl dispatch workspace "$first_ws" >/dev/null
      fi
    '';
  };
in
{
  config = lib.mkIf on {
    assertions = [{
      assertion = unknownMonitors == [ ];
      message = "customConfig.homeManager.hyprland.presets names monitors not in customConfig.desktop.monitors: ${lib.concatStringsSep ", " unknownMonitors}";
    }];

    home.packages = [ hyprPreset ];

    wayland.windowManager.hyprland.settings.bind = lib.mapAttrsToList
      (n: p: "$mainMod, ${p.key}, exec, hypr-preset ${n}")
      (lib.filterAttrs (_: p: p.key != null) presets);
  };
}
