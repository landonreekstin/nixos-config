# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/desktop.nix
#
# The structural half of the glade Hyprland desktop: the glade
# (pkgs/glade) as the desktop on every monitor, and a session that can be driven with
# the mouse alone (or steered from the keyboard), everything labelled in plain words.
# Built for insideabush on blaney-pc, who asked for exactly that.
#
# What runs and what each click or key does. Everything visual — colours, fonts,
# bar/title-bar styling — is in the other files of this desktop. Its Hyprland
# settings go to hyprDesktops.glade, which keeps them out of every other desktop
# (../../desktops.nix).
{ config, pkgs, lib, customConfig, ... }:

let
  desktop = (import ../lib.nix { inherit lib; }).state customConfig "glade";

  glade = pkgs.callPackage ../../../../../pkgs/glade { };
  colors = import ./colors.nix;
  rgb = c: "rgb(${lib.removePrefix "#" c})";

  # The bar goes on the main monitor only, like the XFCE taskbar: the glade's lower
  # monitor is the ground in front of the scene, and a bar along its top would cut
  # across the path where it carries on from the screen above. waybar takes an output
  # name or a description, so a `desc:` identifier works with its prefix dropped.
  monitors = lib.filter (m: m.enabled) customConfig.desktop.monitors;
  mainMonitor = lib.findFirst (m: m.name == "main") null monitors;
  barOutput = if mainMonitor != null then lib.removePrefix "desc:" mainMonitor.identifier else null;

  # Keep the glade up: if it ever exits it comes back after a moment, rather than
  # leaving a bare desktop with nothing to click. Hyprland ends the loop at logout.
  # Each time round it starts the glade that is installed *now*, so after a rebuild the glade can
  # switch itself to the new version when his Thunderstorm button is pressed (resume.py in pkgs/glade)
  # and come back where it was, instead of needing a restart by hand.
  gladeDesktop = pkgs.writeShellScriptBin "glade-desktop" ''
    while true; do
      exe="/etc/profiles/per-user/$USER/bin/glade"
      [ -x "$exe" ] || exe="${glade}/bin/glade"
      "$exe" > "''${XDG_RUNTIME_DIR:-/tmp}/glade.log" 2>&1
      sleep 1
    done
  '';

  # The bar's "Glade" button. Hyprland has no "minimise", so instead every monitor that
  # has windows on it moves to a fresh, empty workspace: the glade shows, and the
  # windows wait where they were — one click away in the bar's window list, which
  # switches back to them. Empty workspaces disappear by themselves once left.
  # Fresh ids start at 100 so no workspace rule bound to a low number catches them.
  gladeShow = pkgs.writeShellApplication {
    name = "glade-show";
    runtimeInputs = [ pkgs.hyprland pkgs.jq ];
    text = ''
      focused=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
      next=$(hyprctl -j workspaces | jq '[.[].id, 99] | max + 1')
      hyprctl -j monitors | jq -r '.[] | "\(.name) \(.activeWorkspace.id)"' |
        while read -r mon ws; do
          windows=$(hyprctl -j workspaces | jq --argjson ws "$ws" '[.[] | select(.id == $ws) | .windows] | add // 0')
          if [ "$windows" -gt 0 ]; then
            hyprctl --batch "dispatch focusmonitor $mon ; dispatch workspace $next" > /dev/null
            next=$((next + 1))
          fi
        done
      hyprctl dispatch focusmonitor "$focused" > /dev/null
    '';
  };

  # Hands a keyboard command to the running glade, through the pipe it reads
  # (wayland.py in pkgs/glade). Gives up after a second if no glade is listening.
  # Alt+Tab like Windows: back to the window used just before this one, whichever screen
  # it is on (Hyprland's own cyclenext stays on one screen's workspace, and his windows
  # are usually on different screens). Alt+Shift+Tab goes to the one used longest ago,
  # so pressing it again and again visits every window. Minimised windows are skipped.
  altTab = pkgs.writeShellScript "glade-alt-tab" ''
    pick=$(hyprctl clients -j | ${pkgs.jq}/bin/jq -r --arg how "$1" '
      [.[] | select(.mapped and (.workspace.name | startswith("special") | not) and .focusHistoryID > 0)]
      | sort_by(.focusHistoryID) | (if $how == "back" then first else last end) | .address // empty')
    [ -n "$pick" ] && hyprctl --batch "dispatch focuswindow address:$pick; dispatch alterzorder top"
  '';

  gladeCtl = pkgs.writeShellScriptBin "glade-ctl" ''
    pipe="''${XDG_RUNTIME_DIR:-/tmp}/glade.ctl"
    [ -p "$pipe" ] || exit 0
    timeout 1 sh -c 'printf "%s\n" "$1" > "$2"' _ "$1" "$pipe"
  '';

  # The keys that steer the glade while the "glade" submap is on: arrows (or WASD)
  # walk along the path that goes that way, Tab / Shift+Tab choose a board, Enter or
  # Space opens it, Home (or H) goes back to the glade, Backspace to the place before.
  # Esc or Super+Home hands the keyboard back; so does any window taking the focus.
  steer = lib.concatStringsSep "\n" (lib.mapAttrsToList (key: cmd: "bind = ${key}, exec, glade-ctl ${cmd}") {
    ", left" = "left"; ", A" = "left";
    ", right" = "right"; ", D" = "right";
    ", up" = "up"; ", W" = "up";
    ", down" = "down"; ", S" = "down";
    ", tab" = "next"; "SHIFT, tab" = "prev";
    ", return" = "open"; ", KP_Enter" = "open"; ", space" = "open";
    ", home" = "home"; ", H" = "home";
    ", BackSpace" = "back";
  });

  # While the moon listens (a click on it in the glade), letters go to the glade instead
  # of the windows, for its easter egg (pkgs/glade: apex.py). The glade turns this submap
  # on itself and off again once it has heard the word, after ten seconds, or as soon as
  # a window takes the focus.
  moonLetters = lib.concatMapStringsSep "\n" (c: "bind = , ${c}, exec, glade-ctl key-${c}")
    (lib.stringToCharacters "abcdefghijklmnopqrstuvwxyz");

  # Shut down through the same "update first?" check as every other shutdown path on
  # a host that has it (modules/home-manager/services/shutdown-guard.nix).
  guarded = action:
    if customConfig.homeManager.services.shutdownGuard.enable
    then "shutdown-guard && ${action}" else action;
in
{
  config = lib.mkMerge [ (lib.mkIf desktop.enabled {
    home.packages = [ glade gladeDesktop gladeShow gladeCtl pkgs.blueman ];
    # Searching the Apps menu for "wifi" found nothing: the Wi-Fi picker was called
    # "NetworkManager Dmenu". Same file name, so this replaces the stock entry.
    xdg.desktopEntries.networkmanager_dmenu = {
      name = "Wi-Fi";
      genericName = "Join a Wi-Fi network";
      exec = "networkmanager_dmenu";
      icon = "nm-device-wireless";
      categories = [ "Network" "Settings" ];
      settings.Keywords = "wifi;wi-fi;wireless;internet;network;";
    };

    hyprDesktops.glade = {
      # Title bars on every window: drag to move, double-click to maximise, and the
      # two buttons below. Built against the same nixpkgs Hyprland, so the ABI matches.
      # Patched to run a command when a drag starts and ends, for snap.nix.
      plugins = [ (pkgs.hyprlandPlugins.hyprbars.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./hyprbars-drag-hooks.patch ];
      })) ];

      settings = {
        general = {
          resize_on_border = true; # drag any edge or corner to resize
          extend_border_grab_area = 25; # wide enough to find without aiming
          hover_icon_on_border = true;
        };
        # Focus follows clicks, like Windows: hovering scrolls a window without
        # stealing the keyboard from the one he is typing in.
        input.follow_mouse = lib.mkForce 2;
        # Clicking a window in the bar's list must bring it forward even when it is
        # on another workspace.
        misc.focus_on_activate = true;

        # Every window floats: opens over the glade at its own size and can overlap,
        # like Windows. (The maximise button fills the monitor when wanted.)
        windowrule = [
          "float true, match:class .*"
          # The terminal's own default (640x400) is cramped for the Claude sessions he
          # spends his time in.
          "size 1100 700, match:class ^(kitty)$"
        ] ++ lib.optionals (mainMonitor != null) [
          # Games open on the main (top) screen. On the lower one, Windows games under
          # Proton put his clicks in the wrong place: XWayland lays the two screens out
          # side by side, not one above the other. steam_app_* is Steam and Heroic (umu)
          # games, *.exe is Lutris's wine games.
          "monitor ${mainMonitor.identifier}, match:class ^(steam_app_.*|.*\\.exe)$"
        ];

        plugin.hyprbars = {
          bar_title_enabled = true;
          on_double_click = "hyprctl dispatch fullscreen 1";
          # R -> L: the close button sits in the far right corner, where he expects it,
          # then maximise, then minimise (into the dock: dock.nix).
          "hyprbars-button" = [
            "${rgb colors.pink}, 22, ✕, hyprctl dispatch killactive, ${rgb colors.ink}"
            "${rgb colors.moss}, 22, ▢, hyprctl dispatch fullscreen 1, ${rgb colors.ink}"
            "${rgb colors.amber}, 22, –, glade-dock minimize, ${rgb colors.ink}"
          ];
        };
      };

      # exec-once is additive in hyprlang, so this joins the functional list.
      # Super+Home: show the glade and let the keyboard steer it (Super+G is Steam).
      extraConfig = ''
        exec-once = glade-desktop
        # Notifications (update reminders, rebuild results). swaync's unit is only
        # WantedBy graphical-session.target, which this session never reaches, so
        # start it explicitly, as century-series does for its own units.
        exec-once = systemctl --user start swaync
        # Bluetooth in the bar's tray, next to the network icon (nm-applet).
        exec-once = ${pkgs.blueman}/bin/blueman-applet

        # The shortcuts his hands know from Windows and macOS: Alt+Tab to switch windows,
        # Alt+F4 to close one, Win+E for files, Print Screen to snip a part of the screen
        # (same as Super+Shift+S, saved to Pictures/Screenshots).
        bind = ALT, Tab, exec, ${altTab} back
        bind = ALT SHIFT, Tab, exec, ${altTab} round
        bind = ALT, F4, killactive,
        bind = SUPER, E, exec, ${pkgs.kdePackages.dolphin}/bin/dolphin
        bind = , Print, exec, ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" ${config.home.homeDirectory}/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png

        bind = SUPER, home, exec, glade-show && glade-ctl keys
        submap = glade
        ${steer}
        bind = , escape, submap, reset
        bind = SUPER, home, submap, reset
        submap = glademoon
        ${moonLetters}
        bind = , escape, submap, reset
        submap = reset
      '';
    };
  })

  # The global app configs belong to the default desktop alone.
  (lib.mkIf desktop.isDefault {
    # The bar: big labelled buttons on the left, the open windows in the middle,
    # volume / tray / clock / power on the right. Replaces the keyboard-centric layout
    # (workspace numbers, CPU, memory) — he finds his windows in the list instead.
    programs.waybar.settings.mainBar = {
      output = lib.mkIf (barOutput != null) barOutput;
      modules-left = lib.mkForce [ "custom/glade-home" "custom/glade-apps" "custom/glade-games" ];
      modules-center = lib.mkForce [ "wlr/taskbar" ];
      modules-right = lib.mkForce [ "pulseaudio" "tray" "clock" "custom/power" ];

      "custom/glade-home" = {
        format = "🌿 Glade";
        tooltip-format = "Show the glade — your windows wait in the list in the middle";
        on-click = "glade-show";
      };
      "custom/glade-apps" = {
        format = "✿ Apps";
        tooltip-format = "Every app on the computer — click one to open it";
        on-click = "glade-dock apps -show drun -show-icons"; # a click outside closes it (dock.py)
      };
      "custom/glade-games" = {
        format = "🎮 Games";
        tooltip-format = "Every game on the computer — click one to play it";
        on-click = "glade-games"; # games.nix
      };
      "wlr/taskbar" = {
        format = "{icon} {name}"; # the app's name: a terminal's title is just "~"
        icon-size = 18;
        all-outputs = true;
        on-click = "activate";
        on-click-middle = "close";
        tooltip-format = "{title}\nClick to bring it forward, middle-click to close it";
      };
      pulseaudio = {
        format = "🔊 {volume}%";
        format-muted = "🔇 muted";
        tooltip-format = "Volume — scroll to change it, click for sound settings";
        on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
        scroll-step = 5;
      };
      "custom/power" = {
        on-click = lib.mkForce "wlogout -b 3";
        format = lib.mkForce "⏻ Power";
        tooltip-format = lib.mkForce "Lock, log out, restart or shut down";
      };
    };

    # Clicking an app in the menu opens it straight away (rofi's default is a
    # double-click), and the list follows the pointer.
    programs.rofi.extraConfig = {
      me-select-entry = "MouseSecondary";
      me-accept-entry = "MousePrimary";
      # a click outside the menu closes it (the menu fills the screen, rofi.nix)
      kb-cancel = "Escape,Control+g,Control+bracketleft,MousePrimary";
      hover-select = true;
      # apps that run inside a terminal (btop, ...) need to know which one
      terminal = customConfig.apps.programs.terminal.command;
    };

    # The power menu, in words. Styling is wlogout.nix.
    programs.wlogout = {
      enable = true;
      layout = [
        { label = "lock"; action = "swaylock"; text = "Lock"; keybind = "l"; }
        { label = "logout"; action = "hyprctl dispatch exit"; text = "Log out"; keybind = "e"; }
        { label = "suspend"; action = "systemctl suspend"; text = "Sleep"; keybind = "s"; }
        { label = "reboot"; action = "systemctl reboot"; text = "Restart"; keybind = "r"; }
        { label = "shutdown"; action = guarded "systemctl poweroff"; text = "Shut down"; keybind = "p"; }
        # The way back out with the mouse alone: wlogout closes after any action.
        { label = "cancel"; action = "true"; text = "Never mind"; keybind = "n"; }
      ];
    };
  }) ];
}
