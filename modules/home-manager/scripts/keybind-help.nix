# ~/nixos-config/modules/home-manager/scripts/keybind-help.nix
# Keyboard shortcut cheatsheet for Hyprland
{ pkgs, lib, config, customConfig, ... }:

let
  # Minimal wofi config for text-only display
  wofiConfig = pkgs.writeText "wofi-keybinds.conf" ''
    width=520
    height=650
    show=dmenu
    prompt=Keybindings
    allow_images=false
    allow_markup=false
    insensitive=true
    hide_scroll=true
    cache_file=/dev/null
    image_size=0
  '';

  # Script to display all Hyprland keybindings in wofi
  keybindHelpScript = pkgs.writeShellScriptBin "hypr-keybinds" ''
    #!${pkgs.stdenv.shell}

    ${pkgs.wofi}/bin/wofi --conf ${wofiConfig} << 'EOF'
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

SYSTEM
Super+Escape        Lock Screen
Super+Backspace     Power Menu
Super+V             Clipboard
Super+Shift+S       Screenshot
Super+Shift+R       Reload
Super+Shift+Q       Exit
Super+Slash         This Menu

MEDIA
Play/Pause          Toggle Playback
Next/Prev           Skip Track
Mute                Toggle Mute
Vol Up/Down         Adjust Volume

Press Escape to close
EOF
  '';

in
{
  home.packages = [
    keybindHelpScript
  ];
}
