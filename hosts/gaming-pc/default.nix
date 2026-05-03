# ~/nixos-config/hosts/gaming-pc/default.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }: # Standard module arguments. `config` is the final NixOS config.

{
  imports = [
    # Hardware-specific configuration for this host
    ./hardware-configuration.nix

    # Top level nixos modules import. All other nixos modules and option definitions are nested.
    ../../modules/nixos/default.nix

  ];

  # === Gaming PC Specific Values for `customConfig` ===
  # These values are for the options defined in `../../modules/nixos/common-options.nix`.
  customConfig = {

    user = {
      name = "lando";
      # home = "/home/lando"; # Defaults correctly based on user.name
      email = "landonreekstin@gmail.com";
      shell.bash.color = "blue";
      sopsPassword = true;
    };

    system = {
      hostName = "gaming-pc"; # Actual hostname for this machine
      stateVersion = "24.11"; # DO NOT CHANGE
      timeZone = "America/Chicago";
      locale = "en_US.UTF-8";
    };

    bootloader = {
      quietBoot = false;
      plymouth = {
        enable = true;
        theme = "circuit";
      };
    };

    desktop = {
      environments = [ "kde" "hyprland" ];
      monitors = [
        {
          name = "main";
          identifier = "DP-4";
          resolution = "2560x1440@180";
          position = "0x0";
          scale = "1.0667";
        }
        {
          name = "left";
          identifier = "DP-6";
          resolution = "preferred";
          position = "-1080x-410";
          scale = "1";
          transform = "1";
        }
        {
          name = "right";
          identifier = "DP-5";
          resolution = "preferred";
          position = "2400x-390";
          scale = "1";
          transform = "1";
        }
        {
          name = "tv";
          identifier = "HDMI-A-2";
          resolution = "preferred";
          position = "0x-1080";
          scale = "1";
          transform = "0";
        }
      ];
      autostart = [];

      hyprland = {
        utilityApps = [
          {
            command = "ckb-next";
            windowClass = "ckb-next";
          }
        ];
        # Audio sink → icon mappings for the waybar audio indicator.
        # Match is a substring of the sink description shown in pavucontrol.
        # Run: pactl list sinks | grep Description  to find exact strings.
        # These may need updating if sink descriptions change with display connections.
        audioSinkMappings = [
          {
            match = "Pro 7";    # DP audio → main monitor → speakers on 3.5mm out
            icon = "󰓃";
            class = "speakers";
            label = "SPKR";
          }
          {
            match = "Pro 8";    # HDMI audio → right portrait monitor → headphones on 3.5mm out
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
              command = "${pkgs.kitty}/bin/kitty";
              tooltip = "Terminal Emulator";
            }
            {
              label = "NAV";
              command = "${pkgs.librewolf}/bin/librewolf";
              tooltip = "Web Browser";
            }
            {
              label = "CODE";
              command = "${pkgs.vscode}/bin/code";
              tooltip = "IDE";
            }
            {
              label = "AUDIO";
              command = "${pkgs.unstable.spotify}/bin/spotify --enable-features=UseOzonePlatform --ozone-platform=wayland";
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
        ly.theme = "century-series"; # F-18 ASCII animation + amber cockpit UI
        # sddm config preserved below for easy rollback:
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

    hardware = {
      unstable = true;
      nvidia = {
        enable = true; # Set to true if Optiplex has an NVIDIA GPU needing proprietary drivers
      };
      peripherals = {
        enable = true; # Enable peripheral configurations
        ckb-next = {
          enable = true;
          # Color/brightness managed at runtime via ~/.cache/ckb-color-state
        };
      };
      monitors = [
        { name = "DP-4";     rotation = "Normal";    scale = 1.15; } # Main: LG 2560x1440 @ 180Hz
        { name = "HDMI-A-2"; rotation = "Rotated90"; }               # Left: Dell 1080p portrait
        { name = "DP-5";     rotation = "Rotated90"; }               # Right: Samsung 1080p portrait
        { name = "DP-6";     rotation = "Normal"; }                  # Above: Hisense TV 1080p
      ];
    };

    programs = {
      partydeck.enable = true;
      firefox = {
        enable = true;
        package = pkgs.firefox;

        extensions = with pkgs.nur.repos.rycee.firefox-addons; [
          ublock-origin
          darkreader
          facebook-container
        ];

        bookmarks = [
          { name = "YouTube"; url = "https://www.youtube.com"; }
          { name = "Netflix"; url = "https://www.netflix.com"; }
          { name = "GitHub";  url = "https://github.com"; }
        ];
      };
      flatpak.enable = true;
    };

    homeManager = {
      enable = true;
      services.updateNotification.enable = true;
      themes = {
        hyprland = "century-series";
      };
    };

    packages = {
      nixos = with pkgs; [
        kitty
        pavucontrol
        mullvad-vpn
        tmux

        # smbclient and kio-extras for Dolphin network shares
        kdePackages.kio-extras
        cifs-utils
        samba
      ];
      unstable-override = [
        "obs-studio"
        "vscode"
        "librewolf"
        "brave"
        "ungoogled-chromium"
        #"claude-code"
        "gurk-rs"
      ];
      homeManager = with pkgs; [
        jamesdsp
        remmina
        vscode
        md-tui
        librewolf
        brave
        ungoogled-chromium
        vesktop
        qbittorrent
        obs-studio
        kdePackages.konversation
        kdePackages.kdenlive
        claude-code
        (callPackage ../../pkgs/worldmonitor { })
        zoom-us
        gurk-rs
      ];
      flatpak = {
        enable = true;
        packages = [];
      };
    };

    apps = {
      defaultBrowser = "librewolf";
    };

    profiles = {
      gaming.enable = true;
      development = {
        fpga-ice40.enable = true;
        kernel.enable = true;
        embedded-linux.enable = true;
        gbdk.enable = true;
        cpp-practice.enable = true;
      };
    };

    networking = {
      wakeOnLan = {
        enable = true;
        interface = "enp8s0";
      };
      encryptedDns = {
        enable = true;
        resolver = "cloudflare";
      };
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
    };

  };

  # === Additional nixos configuration for this host ===
  programs.zoom-us.enable = true;

  # nvidia-drm.fbdev=1: expose NVIDIA as an fbdev so fbcon can use it.
  # initcall_blacklist: prevent simpledrm from loading. Without this, simpledrm
  # claims fb0 at the EFI GOP resolution (1920x1080) before NVIDIA loads, and
  # fbcon inherits that mode — leaving the TTY at 240x67 even though NVIDIA
  # later takes over fb0. Blocking simpledrm makes NVIDIA the first framebuffer.
  # fbcon=font:VGA8x16: Linux 7.0 added DPI-aware font auto-scaling; at 2560x1440
  # it selects a 16x32 font (160x45 chars) instead of 8x16 (320x90 chars).
  # Setting the font via kernel param bypasses the DPI scaling entirely.
  # setfont via userspace (KDFONTOP ioctl) does not work with NVIDIA DRM in 7.0.
  boot.kernelParams = [
    "nvidia-drm.fbdev=1"
    "initcall_blacklist=simpledrm_platform_driver_init"
    "fbcon=font:VGA8x16"
  ];

  # Plymouth sets the fbdev visible geometry to 1920x1080 (EFI GOP resolution)
  # for its splash screen. This persists after Plymouth exits, leaving fbcon
  # at 240x67 even though the virtual buffer is 2560x1440. Reset to native
  # resolution after Plymouth quits, before Ly starts, so fbcon recalculates
  # to 320x90 and the F-18 animation fills the screen.
  systemd.services.fbset-native-res = {
    description = "Reset framebuffer geometry and TTY size before Ly";
    wantedBy = [ "display-manager.service" ];
    before    = [ "display-manager.service" ];
    after     = [ "plymouth-quit.service" ];
    serviceConfig = {
      Type      = "oneshot";
      # 1. Restore framebuffer visible geometry (Plymouth resets it to 1920x1080)
      # 2. Pre-set tty1 window size to 320x90 via TIOCSWINSZ.
      #    fbcon defers console take-over until ~4s after Ly starts, so Ly reads
      #    the default VT size (80x25) and shows only a corner of the animation.
      #    Setting it here with stty ensures Ly sees 320x90 at startup.
      #    (stty uses TIOCSWINSZ, not KDFONTOP — works fine with NVIDIA DRM)
      ExecStart = [
        "${pkgs.fbset}/bin/fbset -g 2560 1440 2560 1440 32"
        "${pkgs.coreutils}/bin/stty -F /dev/tty1 rows 90 cols 320"
      ];
    };
  };

  # Enable the Samba client-side name resolution daemon (nmbd).
  # This allows the PC to discover other Samba hosts (like optiplex-nas)
  # on the local network by their hostname.
  services.samba.nmbd.enable = true;
  networking.firewall.allowedTCPPorts = [ 139 445 4445 ];
  networking.firewall.allowedUDPPorts = [ 137 138 ];
  networking.extraHosts = ''
    192.168.1.76  optiplex-nas
  '';
  # Routes through OpenBSD firewall for accessing server subnet and public IP hairpin NAT
  # Uses NetworkManager dispatcher to add routes when enp8s0 comes up
  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeText "homelab-routes" ''
        #!/bin/sh
        if [ "$1" = "enp8s0" ] && [ "$2" = "up" ]; then
          # Route to server subnet (192.168.100.x) via OpenBSD firewall
          ${pkgs.iproute2}/bin/ip route add 192.168.100.0/24 via 192.168.1.189 dev enp8s0 || true
          # Route for Astroneer public IP hairpin NAT
          ${pkgs.iproute2}/bin/ip route add 68.184.198.204/32 via 192.168.1.189 dev enp8s0 || true
        fi
      '';
      type = "basic";
    }
  ];

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {
      home.packages = [ pkgs.unstable.spotify ];
      xdg.desktopEntries.spotify = {
        name = "Spotify";
        genericName = "Music Player";
        exec = "spotify --enable-features=UseOzonePlatform --ozone-platform=wayland %U";
        icon = "spotify";
        terminal = false;
        categories = [ "Audio" "Music" "Player" "AudioVideo" ];
        mimeType = [ "x-scheme-handler/spotify" ];
      };
    };
  };
  
}
