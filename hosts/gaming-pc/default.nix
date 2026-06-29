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
      betaTesterHost = true;
    };

    bootloader = {
      quietBoot = false;
      configurationLimit = 3; # Boot partition is ~1GB; NVIDIA early-KMS initrds are large
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
          identifier = "DP-1";
          resolution = "2560x1440@180";
          position = "0x0";
          scale = "1.0667";
        }
        {
          name = "left";
          identifier = "DP-3";
          resolution = "preferred";
          position = "-1080x-410";
          scale = "1";
          transform = "1";
        }
        {
          name = "right";
          identifier = "DP-2";
          resolution = "preferred";
          position = "2400x-390";
          scale = "1";
          transform = "1";
        }
        {
          name = "tv";
          identifier = "HDMI-A-1";
          resolution = "preferred";
          position = "0x-1080";
          scale = "1";
          transform = "0";
        }
      ];
      autostart = [];

      idle = {
        lockTimeout = 1500; # 25 minutes
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

    hardware = {
      unstable = false;
      nvidia = {
        enable = true;
      };
      peripherals = {
        enable = true; # Enable peripheral configurations
        ckb-next = {
          enable = true;
          # Color/brightness managed at runtime via ~/.cache/ckb-color-state
        };
      };
      bluetooth = {
        waybar.enable = true;
      };
      monitors = [
        { name = "DP-1";     rotation = "Normal";    scale = 1.15; } # Main: LG 2560x1440 @ 180Hz
        { name = "HDMI-A-1"; rotation = "Rotated90"; }               # Left: Dell 1080p portrait
        { name = "DP-2";     rotation = "Rotated90"; }               # Right: Samsung 1080p portrait
        { name = "DP-3";     rotation = "Normal"; }                  # Above: Hisense TV 1080p
      ];
    };

    apps = {
      defaultSet = "kde";
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
      librewolf.enable = true;
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

        # Build all host configs and push their store paths to the NAS binary cache.
        # Run after a big nixpkgs update to warm the cache for all machines.
        # Usage: cache-push-all
        (writeShellScriptBin "cache-push-all" ''
          set -euo pipefail
          NAS="ssh://lando@192.168.1.76"
          FLAKE="/home/lando/nixos-config"
          HOSTS="gaming-pc optiplex blaney-pc justus-pc asus-laptop asus-m15 atl-mini-pc optiplex-nas"

          for host in $HOSTS; do
            echo "==> [$host] evaluating..."
            drv=$(NIXPKGS_ALLOW_UNFREE=1 nix eval --impure --raw \
              "$FLAKE#nixosConfigurations.$host.config.system.build.toplevel" 2>/dev/null) || {
              echo "    SKIP: eval failed for $host"
              continue
            }
            echo "==> [$host] building $drv"
            nix build "$drv" --no-link || {
              echo "    SKIP: build failed for $host"
              continue
            }
            echo "==> [$host] pushing to NAS cache..."
            nix copy --to "$NAS" "$drv"
            echo "==> [$host] done"
          done

          echo ""
          echo "cache-push-all complete."
        '')
      ];
      unstable-override = [
        "obs-studio"
        "vscode"
        "librewolf"
        "brave"
        "ungoogled-chromium"
        #"claude-code"
        "gurk-rs"
        "vlc"
        "signal-desktop"
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
        vlc
        signal-desktop
        keepassxc
      ];
      flatpak = {
        enable = true;
        packages = [];
      };
    };

    programs.claudeCode.enable = true;

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
      localDns.server = "192.168.1.76";
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
    };

    homelab = {
      nasClient.enable = true;
      localCA.trustCA = true;
    };

  };

  # === Additional nixos configuration for this host ===

  # RTX 4070 Ti Super (Ada Lovelace): open kernel modules recommended for Turing+ with driver 560+.
  # The shared nvidia.nix sets open=false as a safe default; override it here for this host.
  hardware.nvidia.open = lib.mkForce true;

  # Load NVIDIA modules in the initrd for early KMS so Plymouth can render during boot.
  # Without this, Plymouth starts before NVIDIA loads and finds no framebuffer (simpledrm
  # is blacklisted), resulting in a black screen instead of the splash animation.
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  programs.zoom-us.enable = true;

  # Enable the Samba client-side name resolution daemon (nmbd).
  # This allows the PC to discover other Samba hosts (like optiplex-nas)
  # on the local network by their hostname.
  services.samba.nmbd.enable = true;
  networking.firewall.allowedTCPPorts = [ 139 445 4445 ];
  networking.firewall.allowedUDPPorts = [ 137 138 ];
  networking.extraHosts = ''
    192.168.1.76  optiplex-nas
  '';
  # Blacklist the Realtek RTW8852CE wireless driver.
  # The rtw89_8852ce firmware crashes periodically (SER errors), causing a brief
  # PCIe bus stall that makes the wired NIC (r8169/enp8s0) temporarily unreachable too.
  # Gaming-pc is a desktop with wired Ethernet — Wi-Fi is not needed.
  boot.blacklistedKernelModules = [ "rtw89_8852ce" "rtw89_8852c" "rtw89pci" "rtw89core" ];
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "wifi-enable" ''
      exec sudo modprobe rtw89_8852ce
    '')
  ];

  # Enable TCP MTU probing / blackhole detection.
  # WireGuard tunnel MTU (~1420) is smaller than standard Ethernet (1500). If a packet
  # is too large to traverse the tunnel, the intermediate router sends back ICMP
  # "fragmentation needed". With probing enabled, the kernel detects when these are
  # dropped (blackhole) and adaptively reduces MSS, preventing SSH/TCP stalls.
  boot.kernel.sysctl."net.ipv4.tcp_mtu_probing" = 1;

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
      systemd.user.services.audio-spkr-balance = {
        Unit = {
          Description = "Set speaker balance compensation on SPKR output (pro-output-3)";
          After = [ "pipewire-pulse.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.pulseaudio}/bin/pactl set-sink-channel-volumes alsa_output.pci-0000_01_00.1.pro-output-3 80% 100%";
          Restart = "on-failure";
          RestartSec = "2";
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
  };
  
}
