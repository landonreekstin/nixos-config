# ~/nixos-config/modules/home-manager/scripts/keybind-help.nix
# Keyboard shortcut cheatsheet for Hyprland
{ pkgs, lib, config, customConfig, ... }:

let
  # Script to display all Hyprland keybindings in wofi
  keybindHelpScript = pkgs.writeShellScriptBin "hypr-keybinds" ''
    #!${pkgs.stdenv.shell}

    # Get keybindings from hyprctl and format them
    # Uses jq to parse JSON output from hyprctl binds -j

    format_binds() {
      ${pkgs.hyprland}/bin/hyprctl binds -j 2>/dev/null | ${pkgs.jq}/bin/jq -r '
        # Map dispatcher names to human-readable descriptions
        def describe_dispatcher:
          if . == "exec" then "Run"
          elif . == "killactive" then "Close Window"
          elif . == "togglefloating" then "Toggle Float"
          elif . == "movefocus" then "Focus"
          elif . == "swapwindow" then "Swap Window"
          elif . == "resizeactive" then "Resize"
          elif . == "workspace" then "Workspace"
          elif . == "movetoworkspace" then "Move to WS"
          elif . == "fullscreen" then "Fullscreen"
          elif . == "exit" then "Exit Hyprland"
          else .
          end;

        # Map direction args to arrows/descriptions
        def describe_arg:
          if . == "l" then "←"
          elif . == "r" then "→"
          elif . == "u" then "↑"
          elif . == "d" then "↓"
          elif . == "e+1" then "Next"
          elif . == "e-1" then "Prev"
          elif (. | test("^[0-9]+$")) then "WS \(.)"
          elif (. | test("^-?[0-9]+ -?[0-9]+$")) then ""
          else .
          end;

        # Format modmask to readable string
        def format_mods:
          (if (.modmask // 0) == 0 then ""
           else
             (if ((.modmask // 0) % 2) == 1 then "Shift+" else "" end) +
             (if (((.modmask // 0) / 4) | floor % 2) == 1 then "Ctrl+" else "" end) +
             (if (((.modmask // 0) / 8) | floor % 2) == 1 then "Alt+" else "" end) +
             (if (((.modmask // 0) / 64) | floor % 2) == 1 then "Super+" else "" end)
           end);

        .[] |
        select(.key != null and .key != "") |
        "\(format_mods)\(.key | ascii_upcase)  →  \(.dispatcher | describe_dispatcher) \(.arg | describe_arg)"
      ' | sort -t'→' -k1,1 | uniq
    }

    # Add static descriptions for special bindings
    static_binds() {
      cat << 'BINDS'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  HYPRLAND KEYBINDINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

▸ APPLICATIONS
  Super+Space        App Launcher (wofi)
  Super+Return       Terminal (kitty)
  Super+B            Browser
  Super+Shift+B      Alt Browser
  Super+M            Music Player
  Super+D            Chat (Discord)
  Super+G            Gaming (Lutris)
  Super+Shift+G      Gaming Alt (Steam)
  Super+I            IDE (VSCode)
  Super+T            Editor (Kate)
  Super+F            File Manager (TUI)
  Super+Shift+F      File Manager (GUI)
  Ctrl+Shift+Esc     Task Manager

▸ WINDOWS
  Super+Q            Close Window
  Super+H/J/K/L      Focus Left/Down/Up/Right
  Super+Arrows       Swap Window Direction
  Super+Shift+HJKL   Resize Window
  Super+Ctrl+F       Toggle Floating
  Super+F11          Fullscreen
  Super+[            Dwindle Layout
  Super+]            Master Layout
  Super+Mouse1       Move Window (drag)
  Super+Mouse2       Resize Window (drag)

▸ WORKSPACES
  Super+Ctrl+1-9     Go to Workspace 1-9
  Super+Ctrl+Shift+N Move Window to WS N
  Super+Ctrl+←/→     Prev/Next Workspace
  Super+Shift+←/→    Move Window Prev/Next WS

▸ SYSTEM
  Super+L            Lock Screen
  Super+V            Clipboard History
  Super+Shift+S      Screenshot (region)
  Super+Shift+R      Reload Hyprland
  Super+Shift+Q      Exit Hyprland
  Super+/            This Help Menu

▸ MEDIA
  XF86AudioPlay      Play/Pause
  XF86AudioNext      Next Track
  XF86AudioPrev      Previous Track
  XF86AudioMute      Toggle Mute
  XF86Audio↑/↓       Volume Up/Down

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Press Escape to close
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BINDS
    }

    # Display in wofi
    static_binds | ${pkgs.wofi}/bin/wofi --dmenu \
      --prompt "Keybindings" \
      --width 500 \
      --height 600 \
      --cache-file /dev/null \
      --insensitive \
      --allow-markup \
      --hide-scroll
  '';

in
{
  home.packages = [
    keybindHelpScript
    pkgs.jq  # For JSON parsing
  ];
}
