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
      environments = [ "kde" "hyprland" "xfce" ];
      hyprland = {
        applications = {
          # Super+B — matches the NAV launcher entry and the KDE default browser.
          browser = "flatpak run org.chromium.Chromium";
          chat = "${pkgs.vesktop}/bin/vesktop";
        };
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
        ly = {
          theme = "century-series";
          animationFile = ../../assets/ly/f15-animation-240x67.dur; # 1080p: 240x67 chars
          ttyRows = 67;
          ttyCols = 240;
        };
      };
    };

    hardware = {
      unstable = false; # Older hardware — use stable 6.12 LTS kernel + stable NVIDIA
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
      # Notify at next login if a walk-away `rebuild-shutdown` failed.
      services.rebuildShutdownNotify.enable = true;
      themes = {
        plasmaOverride = true;
        kde = "windows7-alt";
        hyprland = "century-series";
        # Win7 XFCE session (X11) as a coexisting login choice — pick "Xfce Session" at Ly.
        # Enforced (xfceOverride) so the declared taskbar/theme is authoritative on rebuild.
        xfce = "windows7";
        xfceOverride = true;
        wallpaper = ../../assets/wallpapers/windows7-wallpaper.jpg;
        # XFCE session gets the aviation wallpaper (matches his Hyprland/century-series, which
        # also falls back to f-15 since he has no desktop.monitors yet) while KDE keeps the Win7
        # wallpaper above. Once his desktop.monitors are set up on-target, portraits can get
        # carrier-top via per-monitor wallpaper.
        xfceWallpaper = ../../assets/wallpapers/f-15-satellite.jpg;
        # XFCE taskbar mirrors the KDE pin set below, using themed/XFCE-native apps where the
        # KDE app has an equivalent (Konsole→kitty, Dolphin→Thunar, KCalc→galculator,
        # plasma-systemmonitor→xfce4-taskmanager, systemsettings→xfce4-settings-manager,
        # Notes→xpad); gaming/peripheral apps reused as-is. The org.xfce.*/galculator icons
        # resolve to Aero via the icon-alias step in windows7-xfce-gtk.nix.
        xfcePanel = {
          trayApplets = [ "network" "bluetooth" "power" "clipboard" ];
          pinnedApps = [
            { name = "Terminal";        exec = "kitty";                              icon = "kitty"; }
            { name = "System Settings"; exec = "xfce4-settings-manager";             icon = "org.xfce.settings.manager"; }
            { name = "Files";           exec = "thunar";                             icon = "system-file-manager"; }
            { name = "Chromium";        exec = "flatpak run org.chromium.Chromium";  icon = "internet-web-browser"; }
            { name = "Lutris";          exec = "lutris";                             icon = "net.lutris.Lutris"; }
            { name = "Heroic";          exec = "heroic";                             icon = "com.heroicgameslauncher.hgl"; }
            { name = "Steam";           exec = "steam";                              icon = "steam"; }
            { name = "Discord";         exec = "flatpak run com.discordapp.Discord"; icon = "com.discordapp.Discord"; }
            { name = "Spotify";         exec = "flatpak run com.spotify.Client";     icon = "com.spotify.Client"; }
            { name = "System Monitor";  exec = "xfce4-taskmanager";                  icon = "org.xfce.taskmanager"; }
            { name = "Calculator";      exec = "galculator";                         icon = "galculator"; }
            { name = "Polychromatic";   exec = "polychromatic-controller";           icon = "polychromatic"; }
            { name = "Input Remapper";  exec = "input-remapper-gtk";                 icon = "input-remapper"; }
            { name = "OpenRGB";         exec = "openrgb";                            icon = "OpenRGB"; }
            { name = "Notes";           exec = "xpad";                               icon = "xpad"; }
          ];
        };
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
        "claude-code"
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
        vesktop
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
      defaultSet = "kde";
      defaults.kde.browser = "org.chromium.Chromium.desktop";
    };

    programs.claudeCode.enable = true;

    profiles = {
      gaming.enable = true;
      development.gbdk.enable = true;
    };

    services = {
      ssh.enable = false;
      vscodeServer.enable = false;

      # Weekly automated git sync + rebuild, then power off. Desktop-safe settings:
      autoUpdate = {
        enable = true;
        shutdownAfterRebuild = true;   # power off after a successful update
        skipIfActiveSession = true;    # never rebuild/power-off while it's in use
        lowPriority = true;            # nice/ionice the rebuild
        persistent = false;            # don't fire a surprise rebuild+shutdown on next boot
      };
    };

  };

  # === Additional nixos configuration for this host ===

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };
  
}
