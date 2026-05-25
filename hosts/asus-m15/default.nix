# ~/nixos-config/hosts/asus-m15/default.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

{
  imports = [
    # Import the hardware profile for the Zephyrus M15 (GA502 model)
    inputs.nixos-hardware.nixosModules.asus-zephyrus-gu603h

    # Hardware-specific configuration generated for this host.
    # We will generate this file in the install script.
    ./hardware-configuration.nix

    ./disko-config.nix
    
    # Top level nixos modules import.
    ../../modules/nixos/default.nix
  ];

  # === Zephyrus G14 Specific Values for `customConfig` ===
  customConfig = {
    
    user = {
      name = "em";
      email = "landonreekstin@gmail.com";
      sudoPassword = true;
    };
    
    system = {
      hostName = "asus-m15";
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/Los_Angeles";
      locale = "en_US.UTF-8";
    };

    bootloader = {
      quietBoot = true;
    };
    
    desktop = {
      environments = [ "kde" "hyprland" ];
      autostart = [];
      idle = {
        lockTimeout  = 900;   # 15 min (AC)
        sleepTimeout = 1200;  # 20 min (AC)
        battery = {
          lockTimeout  = 600; # 10 min
          sleepTimeout = 900; # 15 min
        };
      };
      hyprland = {
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
              command = "${pkgs.chromium}/bin/chromium";
              tooltip = "Web Browser";
            }
            {
              label = "CODE";
              command = "${pkgs.vscode}/bin/code";
              tooltip = "IDE";
            }
            {
              label = "AUDIO";
              command = "flatpak run com.spotify.Client";
              tooltip = "Music Player";
            }
            {
              label = "COMM";
              command = "flatpak run com.discordapp.Discord";
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
        enable = true;
        # HTPC auto-login requires SDDM (Ly does not support autoLogin/defaultSession).
        # Previous Ly F-15 login is preserved below — swap back if not running HTPC mode.
        type = "sddm";
        # ly = {
        #   theme = "century-series";
        #   animationFile = ../../assets/ly/f15-animation-240x67.dur; # 1080p: 240x67 chars
        #   ttyRows = 67;
        #   ttyCols = 240;
        # };
      };
    };

    hardware = {
      unstable = false; # Older hardware — use stable 6.12 LTS kernel + stable NVIDIA
      nvidia = {
        enable = true;
        laptop = {
          enable = true;
          intelBusID = "PCI:0:2:0";
          nvidiaID = "PCI:1:0:0"; 
        };
      };
      peripherals = {
        enable = true;
        asus.enable = true;
      };
      display.backlight.enable = true;
      kbdBacklight.enable = true;
      battery.enable = true;
    };

    programs = {
      partydeck.enable = true;
      flatpak.enable = true;
    };

    homeManager = {
      enable = true;
      themes = {
        kde = "bigsur";
        hyprland = "century-series";
        plasmaOverride = false;
        wallpaper = ../../assets/wallpapers/big-sur.jpg;
        pinnedApps = [
          "applications:org.kde.konsole.desktop"
          "applications:systemsettings.desktop"
          "applications:org.kde.dolphin.desktop"
          "applications:chromium-browser.desktop"
          "applications:net.lutris.Lutris.desktop"
          "applications:com.heroicgameslauncher.hgl.desktop"
          "applications:steam.desktop"
          "applications:com.discordapp.Discord.desktop"
          "applications:com.spotify.Client.desktop"
        ];
      };
    };

    packages = {
      nixos = with pkgs; [

      ];
      unstable-override = [
        "vscode"
        "chromium"
        "firefox"
        "claude-code"
        "mullvad-vpn"
      ];
      homeManager = with pkgs; [
        vscode
        chromium
        firefox
        claude-code
        gopher64
        mullvad-vpn
      ];
      flatpak = {
        enable = true;
        packages = [
          "com.spotify.Client"
          "com.discordapp.Discord"
        ];
      };
    };

    apps = {
      defaultSet = "kde";
      defaults.kde.browser = "chromium.desktop";
    };

    programs.claudeCode.enable = true;

    profiles = {
      gaming.enable = true;
      development.gbdk.enable = true;
      htpc = {
        enable = true;
        autoLogin.enable = true;
        cec = {
          enable = true;
          powerOnTv = true;
          hdmiPort = 1; # adjust to the HDMI port this machine is plugged into on the TV
        };
        controllerWake.enable = true;
        virtualKeyboard.enable = true;
      };
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
      # WireGuard VPN — uncomment after in-person setup:
      #   1. wg genkey | tee /tmp/wg-private.key | wg pubkey  (note the public key)
      #   2. Add the public key to the WireGuard server as a new peer with IP 10.10.0.4/32
      #   3. ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub  (get this host's age key)
      #   4. Replace age1PLACEHOLDER_asus-m15 in .sops.yaml with the real age key
      #   5. sudo sops secrets/asus-m15.yaml  (create the file, add wireguard-private-key)
      #   6. Uncomment the block below and rebuild.
      #
      # wireguard.client = {
      #   enable = true;
      #   address = "10.10.0.4/32"; # verify this IP is free on the server
      #   dns = [ "1.1.1.1" ];
      #   privateKeyFile = config.sops.secrets.wireguard-private-key.path;
      #   peer = {
      #     publicKey = "Z1ZtZiXE59cBZvmjkvcWr5nlEtmHVJJ16P0pb4QtFiY=";
      #     allowedIPs = [ "0.0.0.0/0" ];
      #     endpoint = "68.184.198.204:51822";
      #     persistentKeepalive = 25;
      #   };
      # };
    };

  };

  services.mullvad-vpn.enable = true;

  # Resolve optiplex-nas by hostname (used by Jellyfin Media Player).
  # When WireGuard is enabled above this routes through the VPN tunnel.
  networking.hosts."192.168.1.76" = [ "optiplex-nas" ];
  # Uncomment after setting up the sops secret (step 5 above):
  # sops.secrets.wireguard-private-key = {};

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };
  
}