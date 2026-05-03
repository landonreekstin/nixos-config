# ~/nixos-config/hosts/blaney-pc/default.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }: # Standard module arguments. `config` is the final NixOS config.

{
  imports = [
    # Hardware-specific configuration for this host
    ./hardware-configuration.nix
    
    # Top level nixos modules import. All other nixos modules and option definitions are nested.
    ../../modules/nixos/default.nix

  ];

  customConfig = {
    
    user = {
      name = "insideabush";
      email = "cblaney00@gmail.com";
      updateCmdPermission = false; 
    };
    
    system = {
      hostName = "blaney-pc"; # Actual hostname for this machine
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/New_York"; # As per your old core.nix
      locale = "en_US.UTF-8"; # As per your old core.nix
    };

    bootloader.plymouth = {
      enable = true;
      theme = "hexa_retro";
    };
    
    desktop = {
      environments = [ "kde" "hyprland" ];
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
              command = "flatpak run org.chromium.Chromium";
              tooltip = "Web Browser";
            }
            {
              label = "CODE";
              command = "${pkgs.vscode}/bin/code";
              tooltip = "IDE";
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
        enable = true; # false will go to TTY but not autolaunch a DE
        type = "ly";
        ly.theme = "century-series";
        ly.animationFile = ../../assets/ly/f15-animation-240x67.dur; # 1080p: 240x67 chars
      };
    };

    hardware = {
      unstable = true;
      nvidia = {
        enable = true; # Set to true if Optiplex has an NVIDIA GPU needing proprietary drivers
      };
      peripherals = {
        enable = true; # Enable peripheral configurations
        openrgb.enable = true; # Enable OpenRGB for RGB control
        openrazer.enable = true; # Enable OpenRazer for Razer device support
        ckb-next.enable = false; # Enable CKB-Next for Corsair device support
        input-remapper.enable = true;
        solaar.enable = true;
      };
    };

    programs = {
      partydeck.enable = true;
    };

    homeManager = {
      enable = true; # Enable Home Manager for this host
      themes = {
        plasmaOverride = true;
        kde = "windows7-alt";
        hyprland = "century-series";
        wallpaper = ../../assets/wallpapers/windows7-wallpaper.jpg;
        pinnedApps = [
          "applications:org.kde.konsole.desktop"
          "applications:systemsettings.desktop"
          "applications:org.kde.dolphin.desktop"
          "applications:org.chromium.Chromium.desktop"
          "applications:net.lutris.Lutris.desktop"
          "applications:com.heroicgameslauncher.hgl.desktop"
          "applications:steam.desktop"
          "applications:com.discordapp.Discord.desktop"
          "applications:com.spotify.Client.desktop"
          "applications:org.kde.plasma-systemmonitor.desktop"
          "applications:org.kde.kcalc.desktop"
          "applications:polychromatic.desktop"
          "applications:input-remapper-gtk.desktop"
          "applications:openrgb.desktop"
          "applications:io.github.nuttyartist.notes.desktop"
        ];
      };
      librewolf = {
        enable = true;
        overrideConfig = false;
      };
    };

    packages = {
      nixos = with pkgs; [
      ];
      unstable-override = [
        "obs-studio"
        "vscode"
        #"librewolf"
        #"brave"
        #"chromium"
        "desmume"
        "mgba"
        #"claude-code" 
        "signal-desktop"     
      ];
      homeManager = with pkgs; [
        kitty
        vscode
        #librewolf
        #brave
        #chromium
        #discord-canary
        #discord
        obs-studio
        notes
        CuboCore.corepaint
        kdePackages.kdenlive
        desmume
        mgba
        claude-code
        wireguard-ui
        signal-desktop
        (callPackage ../../pkgs/worldmonitor { })
      ];
      flatpak = {
        enable = true;
        packages = [
          "com.spotify.Client"
          "com.discordapp.Discord"
          "org.chromium.Chromium"
        ];
      };
    };

    apps = {
      defaultBrowser = "chromium";
    };

    profiles = {
      gaming.enable = true;
      development.gbdk.enable = true;
    };

    services = {
      ssh.enable = false;
      vscodeServer.enable = false;
    };

  };

  # === Additional nixos configuration for this host ===

  # Same NVIDIA + Linux 7.0 fbcon fixes as gaming-pc, adapted for native 1080p.
  # nvidia-drm.fbdev=1: expose NVIDIA as fbdev so fbcon can use it.
  # initcall_blacklist: prevent simpledrm from claiming fb0 at EFI GOP res first.
  # fbcon=font:VGA8x16: Linux 7.0 DPI auto-scaling would select a 16x32 font;
  #   forcing 8x16 gives the correct 240x67 terminal at 1920x1080.
  boot.kernelParams = [
    "nvidia-drm.fbdev=1"
    "initcall_blacklist=simpledrm_platform_driver_init"
    "fbcon=font:VGA8x16"
  ];

  # fbcon defers console take-over until ~4s after Ly starts. Pre-set the tty1
  # window size so Ly reads 240x67 at startup instead of the default 80x25.
  # No fbset needed — Plymouth resets to 1920x1080 which is already correct.
  systemd.services.fbset-native-res = {
    description = "Pre-set TTY size for Ly before fbcon takes over";
    wantedBy = [ "display-manager.service" ];
    before    = [ "display-manager.service" ];
    after     = [ "plymouth-quit.service" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/stty -F /dev/tty1 rows 67 cols 240";
    };
  };

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };
  
}
