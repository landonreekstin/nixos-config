# ~/nixos-config/hosts/gaming-pc/desktop.nix
{ config, pkgs, lib, ... }:

{
  customConfig.desktop = {
    environments = [ "kde" "hyprland" "xfce" ];
    # Remote XFCE session over RDP for remote theme work. Port 3389 stays firewalled;
    # reach it via `ssh -L 3389:localhost:3389 lando@gaming-pc` then RDP to localhost.
    xrdp.enable = true;
    monitors = [
      # `identifier` = Wayland/DRM connector name (what Hyprland matches on — desc: matching
      # is unreliable in this Hyprland build). `edid` = EDID description substring used ONLY
      # by the XFCE X11 resolver, because X11 (NVIDIA) reports DIFFERENT connector names than
      # Wayland for the same port (LG: DP-1 Wayland / DP-0 X11; Samsung: DP-2 / DP-3;
      # TV: HDMI-A-1 / HDMI-0), so one connector name can't drive both. Hyprland ignores edid.
      {
        name = "main";
        identifier = "DP-1";
        edid = "LG ULTRAGEAR";
        # XFCE wallpaper matches Hyprland/century-series (primary horizontal). Portraits keep
        # the carrier-top orientation default (also what century-series uses on verticals).
        wallpaper = ../../assets/wallpapers/f-15-satellite.jpg;
        resolution = "2560x1440@180";
        position = "0x0";
        scale = "1.0667";
      }
      {
        # Left portrait = Dell (rarely connected). edid is a placeholder — capture the exact
        # EDID product name from `xrandr --verbose` next time it's plugged in and tighten it.
        name = "left";
        identifier = "DP-3";
        edid = "DELL";
        resolution = "preferred";
        position = "-1080x-410";
        scale = "1";
        transform = "1";
      }
      {
        # Right portrait = Samsung S27R65x (serial H4TW800293) — the everyday vertical.
        name = "right";
        identifier = "DP-2";
        edid = "S27R65x";
        resolution = "preferred";
        position = "2400x-390";
        scale = "1";
        transform = "1";
      }
      {
        name = "tv";
        identifier = "HDMI-A-1";
        edid = "4Series43";
        # Matches Hyprland/century-series (secondary horizontal).
        wallpaper = ../../assets/wallpapers/f-4-cockpit.png;
        resolution = "preferred";
        position = "0x-1080";
        scale = "1";
        transform = "0";
      }
    ];
    autostart = [
      # Steam + Heroic autostart via their own app settings; add these for the session.
      { command = "discord";  desktops = [ "xfce" ]; }
      { command = "ckb-next"; desktops = [ "xfce" ]; }
    ];

    idle = {
      screensaverTimeout = 900;   # screensaver at 15 min (respects media/game inhibitors)
      lockTimeout = 1200;         # lock at 20 min
      sleepTimeout = 1800;        # display off (DPMS) at 30 min
    };

    hyprland = {
      # Pin Hyprland to the NVIDIA card (card0).
      # Early KMS loads NVIDIA first (card0), AMD iGPU second (card1); without this,
      # Hyprland may enumerate both and render on the wrong device.
      # Note: AQ_DRM_DEVICES is colon-separated, so avoid by-path names with colons.
      # With NVIDIA in the initrd, card0 = NVIDIA is stable across reboots.
      drmDevice = "/dev/dri/card0";

      utilityApps = [
        {
          command = "ckb-next";
          windowClass = "ckb-next";
        }
      ];
      # Audio sink → icon mappings for the waybar audio indicator.
      # Match is checked against the sink name (pactl list sinks short | awk '{print $2}').
      # Use "pro-output-N" to match the sink name — more reliable than description substrings
      # since descriptions like "Pro" are ambiguous across multiple HDMI/DP outputs.
      # If sinks renumber after a kernel upgrade, check: pactl list sinks | grep -E "Name:|Description:"
      audioSinkMappings = [
        {
          match = "pro-output-3";    # DP-1 audio → main 1440p monitor → speakers on 3.5mm out
          icon = "󰓃";
          class = "speakers";
          label = "SPKR";
        }
        {
          match = "pro-output-8";    # DP-2 audio → right portrait monitor → headphones on 3.5mm out
          icon = "󰋋";
          class = "headphones";
          label = "HDPH";
        }
      ];
      launcher = {
        enable = true;
        pinnedApps = [
          {
            label = "TERM";
            command = config.customConfig.apps.programs.terminal.command;
            tooltip = "Terminal Emulator";
          }
          {
            label = "NAV";
            command = config.customConfig.apps.programs.browser.command;
            tooltip = "Web Browser";
          }
          {
            label = "CODE";
            command = config.customConfig.apps.programs.ide.command;
            tooltip = "IDE";
          }
          {
            label = "AUDIO";
            command = config.customConfig.apps.programs.music.command;
            tooltip = "Music Player";
          }
          {
            label = "COMM";
            command = "${pkgs.vesktop}/bin/vesktop";
            tooltip = "Communications";
          }
          {
            label = "GAME";
            command = "steam";
            tooltip = "Gaming Platform";
          }
        ];
      };
    };
    displayManager = {
      enable = true; # false will go to TTY but not autolaunch a DE
      type = "ly";
      ly = {
        theme = "century-series"; # F-18 ASCII animation + amber cockpit UI
        ttyRows = 90;
        ttyCols = 320;
        nativeFbResolution = { width = 2560; height = 1440; };
      };
      # sddm config preserved for reference:
      # type = "sddm";
      # sddm = {
      #   theme = "sddm-astronaut";
      #   customTheme = {
      #     enable = true;
      #     wallpaper = ../../assets/wallpapers/F18_background.mp4;
      #     blur = 2.0;
      #     roundCorners = 20;
      #     colors = {
      #       formBackground = "#1e1e2e";
      #       dimBackground = "#1e1e2e";
      #       headerText = "#cdd6f4";
      #       dateText = "#cdd6f4";
      #       timeText = "#cdd6f4";
      #       placeholderText = "#a6adc8";
      #       loginButtonBackground = "#89b4fa";
      #       loginButtonText = "#1e1e2e";
      #       highlightBackground = "#89b4fa";
      #       systemButtonsIcons = "#cdd6f4";
      #     };
      #   };
      #   screensaver.enable = false;
      # };
    };
  };
}
