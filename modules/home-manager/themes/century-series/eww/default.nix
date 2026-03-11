# ~/nixos-config/modules/home-manager/themes/century-series/eww/default.nix
# MFD-style application launcher using Eww
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors
  colorsModule = import ../colors.nix { };
  c = colorsModule.centuryColors;

  # Check conditions
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

  # Script to get applications list in JSON format for eww
  getAppsScript = pkgs.writeShellScriptBin "mfd-get-apps" ''
    echo -n "["
    first=true
    ${pkgs.findutils}/bin/find /run/current-system/sw/share/applications \
      ~/.local/share/applications \
      ~/.nix-profile/share/applications \
      /etc/profiles/per-user/*/share/applications \
      -name "*.desktop" 2>/dev/null | sort -u | while read -r file; do
      name=$(${pkgs.gnugrep}/bin/grep -m1 "^Name=" "$file" 2>/dev/null | cut -d= -f2 | sed 's/"/\\"/g')
      exec=$(${pkgs.gnugrep}/bin/grep -m1 "^Exec=" "$file" 2>/dev/null | cut -d= -f2 | sed 's/ %.*//' | sed 's/"/\\"/g')
      icon=$(${pkgs.gnugrep}/bin/grep -m1 "^Icon=" "$file" 2>/dev/null | cut -d= -f2)
      nodisplay=$(${pkgs.gnugrep}/bin/grep -m1 "^NoDisplay=" "$file" 2>/dev/null | cut -d= -f2)
      if [ -n "$name" ] && [ "$nodisplay" != "true" ]; then
        if [ "$first" = true ]; then
          first=false
        else
          echo -n ","
        fi
        echo -n "{\"name\":\"$name\",\"exec\":\"$exec\",\"icon\":\"$icon\"}"
      fi
    done
    echo "]"
  '';

  # Script to launch app and close MFD
  launchAppScript = pkgs.writeShellScriptBin "mfd-launch" ''
    exec_cmd="$@"
    ${pkgs.eww}/bin/eww close mfd-launcher
    nohup $exec_cmd >/dev/null 2>&1 &
    disown
  '';

  # Script to toggle the MFD launcher
  toggleMfdScript = pkgs.writeShellScriptBin "mfd-toggle" ''
    if ${pkgs.eww}/bin/eww active-windows | grep -q "mfd-launcher"; then
      ${pkgs.eww}/bin/eww close mfd-launcher
    else
      ${pkgs.eww}/bin/eww update current-mode="apps"
      ${pkgs.eww}/bin/eww update search-text=""
      ${pkgs.eww}/bin/eww open mfd-launcher
    fi
  '';

  # Power action scripts
  powerLockScript = pkgs.writeShellScriptBin "mfd-lock" ''
    ${pkgs.eww}/bin/eww close mfd-launcher
    ${pkgs.swaylock-effects}/bin/swaylock
  '';

  powerLogoutScript = pkgs.writeShellScriptBin "mfd-logout" ''
    ${pkgs.eww}/bin/eww close mfd-launcher
    hyprctl dispatch exit
  '';

  powerRebootScript = pkgs.writeShellScriptBin "mfd-reboot" ''
    ${pkgs.eww}/bin/eww close mfd-launcher
    systemctl reboot
  '';

  powerShutdownScript = pkgs.writeShellScriptBin "mfd-shutdown" ''
    ${pkgs.eww}/bin/eww close mfd-launcher
    systemctl poweroff
  '';

  # Web search script
  webSearchScript = pkgs.writeShellScriptBin "mfd-websearch" ''
    query="$@"
    ${pkgs.eww}/bin/eww close mfd-launcher
    ${pkgs.xdg-utils}/bin/xdg-open "https://duckduckgo.com/?q=$query" &
  '';

  # File search script (returns JSON)
  fileSearchScript = pkgs.writeShellScriptBin "mfd-filesearch" ''
    query="$1"
    if [ -z "$query" ] || [ ''${#query} -lt 2 ]; then
      echo "[]"
      exit 0
    fi
    echo -n "["
    first=true
    ${pkgs.fd}/bin/fd --type f --max-results 20 "$query" $HOME 2>/dev/null | while read -r file; do
      name=$(basename "$file")
      if [ "$first" = true ]; then
        first=false
      else
        echo -n ","
      fi
      echo -n "{\"name\":\"$name\",\"path\":\"$file\"}"
    done
    echo "]"
  '';

  # Open file script
  openFileScript = pkgs.writeShellScriptBin "mfd-openfile" ''
    ${pkgs.eww}/bin/eww close mfd-launcher
    ${pkgs.xdg-utils}/bin/xdg-open "$1" &
  '';

in {
  config = mkIf centurySeriesThemeCondition {
    # Install eww and helper scripts
    home.packages = [
      pkgs.eww
      pkgs.fd
      pkgs.xdg-utils
      getAppsScript
      launchAppScript
      toggleMfdScript
      powerLockScript
      powerLogoutScript
      powerRebootScript
      powerShutdownScript
      webSearchScript
      fileSearchScript
      openFileScript
    ];

    # Eww configuration
    xdg.configFile."eww/eww.yuck".text = ''
      ; MFD Launcher - Century Series Theme
      ; Multi-Function Display style application launcher

      ; Variables
      (defvar search-text "")
      (defvar web-query "")
      (defvar current-mode "apps")  ; apps, pwr, sys, files, web

      ; Poll for apps - runs once on daemon start, cached
      (defpoll apps-list :interval "3600s"
        :initial "[]"
        `mfd-get-apps`)

      ; System stats for SYS page
      (defpoll sys-cpu :interval "2s" :initial "0"
        `top -bn1 | grep "Cpu(s)" | awk '{print int($2)}'`)
      (defpoll sys-mem :interval "2s" :initial "0"
        `free | grep Mem | awk '{print int($3/$2 * 100)}'`)
      (defpoll sys-disk :interval "30s" :initial "0"
        `df -h / | tail -1 | awk '{print $5}' | tr -d '%'`)
      (defpoll sys-uptime :interval "60s" :initial "0:00"
        `uptime -p | sed 's/up //'`)

      ; Left MFD buttons
      (defwidget mfd-left-buttons []
        (box :class "mfd-buttons mfd-left"
             :orientation "v"
             :space-evenly true
             :valign "center"
          (button :class "mfd-btn" :onclick "mfd-toggle" "ESC")
          (button :class "mfd-btn" :onclick "" "L2")
          (button :class "mfd-btn" :onclick "" "L3")
          (button :class "mfd-btn" :onclick "" "L4")
          (button :class "mfd-btn" :onclick "" "L5")))

      ; Right MFD buttons
      (defwidget mfd-right-buttons []
        (box :class "mfd-buttons mfd-right"
             :orientation "v"
             :space-evenly true
             :valign "center"
          (button :class "mfd-btn" :onclick "" "R1")
          (button :class "mfd-btn" :onclick "" "R2")
          (button :class "mfd-btn" :onclick "" "R3")
          (button :class "mfd-btn" :onclick "" "R4")
          (button :class "mfd-btn" :onclick "" "R5")))

      ; Top MFD buttons
      (defwidget mfd-top-buttons []
        (box :class "mfd-buttons mfd-top"
             :orientation "h"
             :space-evenly true
             :halign "center"
          (button :class "mfd-btn" :onclick "" "T1")
          (button :class "mfd-btn" :onclick "" "T2")
          (button :class "mfd-btn" :onclick "" "T3")
          (button :class "mfd-btn" :onclick "" "T4")
          (button :class "mfd-btn" :onclick "" "T5")))

      ; Bottom MFD buttons - mode switchers
      (defwidget mfd-bottom-buttons []
        (box :class "mfd-buttons mfd-bottom"
             :orientation "h"
             :space-evenly true
             :halign "center"
          (button :class {current-mode == "apps" ? "mfd-btn mfd-btn-active" : "mfd-btn"}
                  :onclick "eww update current-mode=apps" "APPS")
          (button :class {current-mode == "sys" ? "mfd-btn mfd-btn-active" : "mfd-btn"}
                  :onclick "eww update current-mode=sys" "SYS")
          (button :class {current-mode == "files" ? "mfd-btn mfd-btn-active" : "mfd-btn"}
                  :onclick "eww update current-mode=files" "FILES")
          (button :class {current-mode == "pwr" ? "mfd-btn mfd-btn-active" : "mfd-btn"}
                  :onclick "eww update current-mode=pwr" "PWR")
          (button :class {current-mode == "web" ? "mfd-btn mfd-btn-active" : "mfd-btn"}
                  :onclick "eww update current-mode=web" "WEB")))

      ; Search input
      (defwidget search-bar []
        (box :class "search-container"
             :orientation "h"
             :space-evenly false
          (label :class "search-prompt" :text "SEARCH:")
          (input :class "search-input"
                 :onchange "eww update search-text={}"
                 :value search-text)))

      ; Single app entry with filter support
      (defwidget app-entry [name exec icon search]
        (revealer :transition "slidedown"
                  :reveal {search == "" || matches(name, "(?i).*''${search}.*")}
                  :duration "150ms"
          (button :class "app-item"
                  :onclick "mfd-launch ''${exec}"
            (box :orientation "h" :space-evenly false :spacing 12
              (image :class "app-icon"
                     :path icon
                     :image-width 24
                     :image-height 24)
              (label :class "app-name" :text name :halign "start")))))

      ; Apps list
      (defwidget apps-list []
        (scroll :class "apps-scroll" :vscroll true :hscroll false :vexpand true
          (box :class "apps-container"
               :orientation "v"
               :space-evenly false
               :spacing 0
               :vexpand true
            (for app in apps-list
              (app-entry :name {app.name} :exec {app.exec} :icon {app.icon} :search search-text)))))

      ; ============ PWR PAGE ============
      (defwidget pwr-page []
        (box :class "pwr-container"
             :orientation "v"
             :space-evenly false
             :valign "center"
             :halign "center"
             :vexpand true
          (label :class "page-title" :text "POWER CONTROL")
          (box :orientation "h" :spacing 20 :halign "center"
            (button :class "pwr-btn pwr-lock" :onclick "mfd-lock"
              (box :orientation "v" :space-evenly false
                (label :class "pwr-icon" :text "")
                (label :class "pwr-label" :text "LOCK")))
            (button :class "pwr-btn pwr-logout" :onclick "mfd-logout"
              (box :orientation "v" :space-evenly false
                (label :class "pwr-icon" :text "")
                (label :class "pwr-label" :text "LOGOUT"))))
          (box :orientation "h" :spacing 20 :halign "center"
            (button :class "pwr-btn pwr-reboot" :onclick "mfd-reboot"
              (box :orientation "v" :space-evenly false
                (label :class "pwr-icon" :text "")
                (label :class "pwr-label" :text "REBOOT")))
            (button :class "pwr-btn pwr-shutdown" :onclick "mfd-shutdown"
              (box :orientation "v" :space-evenly false
                (label :class "pwr-icon" :text "")
                (label :class "pwr-label" :text "SHUTDOWN"))))))

      ; ============ SYS PAGE ============
      (defwidget sys-page []
        (box :class "sys-container"
             :orientation "v"
             :space-evenly false
             :vexpand true
          (label :class "page-title" :text "SYSTEM STATUS")
          (box :class "sys-stats" :orientation "v" :spacing 12
            (box :orientation "h" :space-evenly false
              (label :class "sys-label" :text "CPU:")
              (progress :class "sys-bar cpu-bar" :value sys-cpu)
              (label :class "sys-value" :text "''${sys-cpu}%"))
            (box :orientation "h" :space-evenly false
              (label :class "sys-label" :text "MEM:")
              (progress :class "sys-bar mem-bar" :value sys-mem)
              (label :class "sys-value" :text "''${sys-mem}%"))
            (box :orientation "h" :space-evenly false
              (label :class "sys-label" :text "DISK:")
              (progress :class "sys-bar disk-bar" :value sys-disk)
              (label :class "sys-value" :text "''${sys-disk}%"))
            (box :orientation "h" :space-evenly false
              (label :class "sys-label" :text "UPTIME:")
              (label :class "sys-value uptime" :text sys-uptime)))))

      ; ============ WEB SEARCH PAGE ============
      (defwidget web-page []
        (box :class "web-container"
             :orientation "v"
             :space-evenly false
             :valign "center"
             :halign "center"
             :vexpand true
          (label :class "page-title" :text "WEB SEARCH")
          (label :class "web-hint" :text "Press Enter to search")
          (input :class "web-input"
                 :onchange "eww update web-query={}"
                 :onaccept "mfd-websearch {}"
                 :value web-query)))

      ; ============ FILES PAGE (placeholder) ============
      (defwidget files-page []
        (box :class "files-container"
             :orientation "v"
             :space-evenly false
             :valign "center"
             :halign "center"
             :vexpand true
          (label :class "page-title" :text "FILE SEARCH")
          (label :class "files-hint" :text "File search coming soon")
          (label :class "files-hint" :text "Use terminal: fd <query>")))

      ; ============ MAIN SCREEN ============
      ; Main MFD screen content - switches based on mode
      (defwidget mfd-screen []
        (overlay :class "mfd-screen" :vexpand true :hexpand true
          ; Apps page
          (box :class "page-content"
               :orientation "v"
               :space-evenly false
               :vexpand true
               :visible {current-mode == "apps"}
            (search-bar)
            (apps-list))
          ; PWR page
          (box :class "page-content"
               :vexpand true
               :visible {current-mode == "pwr"}
            (pwr-page))
          ; SYS page
          (box :class "page-content"
               :vexpand true
               :visible {current-mode == "sys"}
            (sys-page))
          ; WEB page
          (box :class "page-content"
               :vexpand true
               :visible {current-mode == "web"}
            (web-page))
          ; FILES page
          (box :class "page-content"
               :vexpand true
               :visible {current-mode == "files"}
            (files-page))))

      ; Complete MFD frame
      (defwidget mfd-frame []
        (box :class "mfd-frame"
             :orientation "h"
             :space-evenly false
             :hexpand true
             :vexpand true
          (mfd-left-buttons)
          (box :class "mfd-center"
               :orientation "v"
               :space-evenly false
               :hexpand true
               :vexpand true
            (mfd-top-buttons)
            (mfd-screen)
            (mfd-bottom-buttons))
          (mfd-right-buttons)))

      ; Window definition
      (defwindow mfd-launcher
        :monitor 0
        :geometry (geometry :x "0%"
                           :y "0%"
                           :width "580px"
                           :height "520px"
                           :anchor "center")
        :stacking "overlay"
        :exclusive false
        :focusable true
        (mfd-frame))
    '';

    xdg.configFile."eww/eww.scss".text = ''
      // Century Series MFD Theme
      // Cold War Aviation Cockpit Aesthetic

      // Color variables
      $bg-primary: ${c.bg-primary};
      $bg-secondary: ${c.bg-secondary};
      $bg-tertiary: ${c.bg-tertiary};
      $border-primary: ${c.border-primary};
      $border-active: ${c.border-active};
      $accent-amber: ${c.accent-amber};
      $accent-amber-dim: ${c.accent-amber-dim};
      $accent-green: ${c.accent-green};
      $text-primary: ${c.text-primary};
      $text-secondary: ${c.text-secondary};
      $warning-red: ${c.warning-red};
      $metal: ${c.metal};

      // Main MFD frame - the outer bezel
      .mfd-frame {
        background-color: $bg-tertiary;
        border: 4px solid $metal;
        padding: 0;
      }

      // MFD button strips
      .mfd-buttons {
        background-color: $bg-tertiary;
        padding: 8px 4px;

        &.mfd-left, &.mfd-right {
          min-width: 50px;
        }

        &.mfd-top, &.mfd-bottom {
          min-height: 40px;
        }
      }

      // Individual MFD buttons
      .mfd-btn {
        background-color: $bg-secondary;
        color: $text-secondary;
        border: 2px solid $border-primary;
        border-radius: 2px;
        padding: 8px 12px;
        margin: 2px;
        font-family: "JetBrains Mono", monospace;
        font-size: 10px;
        font-weight: bold;
        min-width: 40px;
        min-height: 28px;

        &:hover {
          background-color: $border-active;
          color: $text-primary;
          border-color: $border-active;
        }

        &:active, &.mfd-btn-active {
          background-color: $accent-amber;
          color: $bg-primary;
          border-color: $accent-amber;
        }
      }

      // Center section containing top buttons, screen, bottom buttons
      .mfd-center {
        background-color: $bg-tertiary;
      }

      // The actual MFD screen area
      .mfd-screen {
        background-color: $bg-primary;
        border: 3px solid $border-primary;
        margin: 4px;
        padding: 0;
        min-width: 420px;
        min-height: 320px;
      }

      // Page content wrapper - consistent sizing
      .page-content {
        background-color: $bg-primary;
        min-width: 420px;
        min-height: 320px;
      }

      // Search bar
      .search-container {
        background-color: $bg-secondary;
        border-bottom: 2px solid $border-primary;
        padding: 12px 16px;
      }

      .search-prompt {
        color: $accent-amber;
        font-family: "JetBrains Mono", monospace;
        font-size: 11px;
        font-weight: bold;
        margin-right: 12px;
      }

      .search-input {
        background-color: transparent;
        border: none;
        color: $accent-green;
        font-family: "JetBrains Mono", monospace;
        font-size: 11px;
        min-width: 300px;

        &:focus {
          outline: none;
        }
      }

      // Apps scroll area
      .apps-scroll {
        background-color: $bg-primary;
        min-height: 280px;
      }

      .apps-container {
        padding: 8px;
        background-color: $bg-primary;
      }

      // Individual app entries
      .app-item {
        background-color: $bg-secondary;
        border: 1px solid $border-primary;
        border-radius: 0;
        padding: 8px 12px;
        margin: 2px 0;

        &:hover {
          background-color: $accent-amber;
          border-color: $accent-amber;

          .app-name {
            color: $bg-primary;
          }
        }
      }

      // Hide gaps for filtered items
      revealer {
        transition: none;

        &:not(.visible) {
          min-height: 0;
          min-width: 0;
          padding: 0;
          margin: 0;
        }
      }

      .app-icon {
        min-width: 24px;
        min-height: 24px;
      }

      .app-name {
        color: $text-primary;
        font-family: "JetBrains Mono", monospace;
        font-size: 11px;
      }

      // Page titles
      .page-title {
        color: $accent-amber;
        font-family: "JetBrains Mono", monospace;
        font-size: 14px;
        font-weight: bold;
        margin-bottom: 20px;
        padding: 8px;
        border-bottom: 2px solid $border-primary;
      }

      // ============ PWR PAGE ============
      .pwr-container {
        padding: 20px;
      }

      .pwr-btn {
        background-color: $bg-secondary;
        border: 2px solid $border-primary;
        border-radius: 4px;
        padding: 20px 30px;
        margin: 10px;
        min-width: 100px;
        min-height: 80px;

        &:hover {
          border-color: $accent-amber;
        }

        &.pwr-lock:hover { border-color: $accent-green; }
        &.pwr-logout:hover { border-color: $accent-amber; }
        &.pwr-reboot:hover { border-color: #e6a855; }
        &.pwr-shutdown:hover { border-color: $warning-red; }
      }

      .pwr-icon {
        color: $text-primary;
        font-size: 24px;
        margin-bottom: 8px;
      }

      .pwr-label {
        color: $text-secondary;
        font-family: "JetBrains Mono", monospace;
        font-size: 10px;
        font-weight: bold;
      }

      // ============ SYS PAGE ============
      .sys-container {
        padding: 20px;
      }

      .sys-stats {
        padding: 12px;
      }

      .sys-label {
        color: $accent-amber;
        font-family: "JetBrains Mono", monospace;
        font-size: 11px;
        font-weight: bold;
        min-width: 60px;
      }

      .sys-bar {
        min-width: 250px;
        min-height: 16px;
        margin: 0 12px;
        background-color: $bg-secondary;
        border: 1px solid $border-primary;
        border-radius: 0;

        progress {
          background-color: $accent-green;
          border-radius: 0;
        }

        &.cpu-bar progress { background-color: $accent-amber; }
        &.mem-bar progress { background-color: $accent-green; }
        &.disk-bar progress { background-color: #6a9fb5; }
      }

      .sys-value {
        color: $text-primary;
        font-family: "JetBrains Mono", monospace;
        font-size: 11px;
        min-width: 50px;

        &.uptime {
          color: $accent-green;
        }
      }

      // ============ WEB PAGE ============
      .web-container {
        padding: 20px;
      }

      .web-hint {
        color: $text-secondary;
        font-family: "JetBrains Mono", monospace;
        font-size: 10px;
        margin-bottom: 12px;
      }

      .web-input {
        background-color: $bg-secondary;
        border: 2px solid $border-primary;
        color: $accent-green;
        font-family: "JetBrains Mono", monospace;
        font-size: 12px;
        padding: 10px 14px;
        min-width: 250px;

        &:focus {
          border-color: $accent-amber;
          outline: none;
        }
      }

      // ============ FILES PAGE ============
      .files-container {
        padding: 8px;
      }

      .files-hint {
        color: $text-secondary;
        font-family: "JetBrains Mono", monospace;
        font-size: 10px;
        padding: 8px;
      }

      .files-scroll {
        background-color: $bg-primary;
        min-height: 250px;
      }

      .files-list {
        padding: 4px;
      }

      .file-item {
        background-color: $bg-secondary;
        border: 1px solid $border-primary;
        padding: 6px 12px;
        margin: 2px 0;

        &:hover {
          background-color: $accent-amber;
          border-color: $accent-amber;

          .file-name {
            color: $bg-primary;
          }
        }
      }

      .file-name {
        color: $text-primary;
        font-family: "JetBrains Mono", monospace;
        font-size: 10px;
      }
    '';
  };
}
