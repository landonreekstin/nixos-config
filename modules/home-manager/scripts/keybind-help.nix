# ~/nixos-config/modules/home-manager/scripts/keybind-help.nix
# Keyboard shortcut cheatsheet for Hyprland
{ pkgs, lib, config, customConfig, ... }:

let
  # Script to display all Hyprland keybindings in rofi
  keybindHelpScript = pkgs.writeShellScriptBin "hypr-keybinds" ''
    #!${pkgs.stdenv.shell}

    ${pkgs.rofi}/bin/rofi -dmenu -p "KEYBINDINGS" -i -no-custom -width 520 << 'EOF'
HYPRLAND KEYBINDINGS

APPLICATIONS
Super+Space         App Launcher
Super+Return        Terminal
Super+B             Browser
Super+Shift+B       Alt Browser
Super+M             Music Player
Super+D             Chat
Super+G             Gaming
Super+Shift+G       Gaming Alt
Super+I             IDE
Super+T             Editor
Super+F             File Manager TUI
Super+Shift+F       File Manager GUI
Ctrl+Shift+Esc      Task Manager

WINDOWS
Super+Q             Close Window
Super+H             Focus Left
Super+J             Focus Down
Super+K             Focus Up
Super+L             Focus Right
Super+Arrow         Swap Window
Super+Shift+H       Resize Left
Super+Shift+J       Resize Down
Super+Shift+K       Resize Up
Super+Shift+L       Resize Right
Super+Ctrl+F        Toggle Float
Super+F11           Fullscreen

WORKSPACES
Super+1-9           Workspace 1-9
Super+Shift+1-9     Move Window to WS
Super+Ctrl+Arrow    Prev/Next WS
Super+Shift+Arrow   Move Win Prev/Next

DISPLAYS
Ctrl+Super+1        Toggle Display 1
Ctrl+Super+2        Toggle Display 2
Ctrl+Super+3        Toggle Display 3
Ctrl+Super+4        Toggle Display 4

SYSTEM
Super+Escape        Lock Screen
Super+Backspace     Power Menu
Super+V             Clipboard
Super+Shift+S       Screenshot
Super+Shift+R       Reload
Ctrl+Super+R        Rebuild System
Super+Shift+Q       Exit
Super+Slash         This Menu

MEDIA
Play/Pause          Toggle Playback
Next/Prev           Skip Track
Mute                Toggle Mute
Vol Up/Down         Adjust Volume
Super+Vol Up/Down   Cycle Audio Output
Ctrl+Super+A        Cycle Audio Output

Press Escape to close
EOF
  '';

in
{
  home.packages = [
    keybindHelpScript
  ];
}
