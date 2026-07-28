# ~/nixos-config/hosts/vm-blaney/default.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

# blaney-pc software mirror — a throwaway QEMU VM that reproduces blaney-pc's KDE/aerotheme
# + Hyprland + XFCE(windows7) software configuration so his theme/plasma/taskbar can be
# reproduced and reviewed locally on gaming-pc before pushing a `blaney/` PR to that machine.
#
# Mirrors the *software* surface faithfully, INCLUDING his XFCE windows7 taskbar (exact
# xfcePanel pins) + the apps those pins reference (gaming profile for Steam/Heroic/Lutris;
# peripheral GUIs added directly since vm-common force-disables the hardware peripherals;
# flatpaks for Chromium/Discord/Spotify) so the taskbar renders with real icons for a pre-PR
# visual check. Hardware/boot bits are still dropped: no hardware-configuration.nix, no
# plymouth, nvidia + peripherals forced off (VM has no GPU/devices → llvmpipe). NOTE the VM
# can't reproduce the NVIDIA-open kwin-wayland breakage (that's real-hardware only); pick the
# "Xfce Session" at Ly to review the taskbar.
{
  imports = [
    ../../modules/nixos/default.nix
    ../vm-common.nix
  ];

  customConfig = {

    user = {
      name = "insideabush";
      email = "cblaney00@gmail.com";
      updateCmdPermission = false;
    };

    system = {
      hostName = "vm-blaney";
      stateVersion = "25.05"; # match blaney-pc
      timeZone = "America/New_York";
      locale = "en_US.UTF-8";
    };

    desktop = {
      environments = [ "kde" "hyprland" "xfce" ];
      hyprland = {
        applications.browser = "flatpak run org.chromium.Chromium"; # mirrors blaney-pc
        launcher = {
          enable = true;
          pinnedApps = [
            { label = "TERM"; command = "${pkgs.kitty}/bin/kitty"; tooltip = "Terminal Emulator"; }
            { label = "NAV";  command = "flatpak run org.chromium.Chromium"; tooltip = "Web Browser"; }
            { label = "CODE"; command = "${pkgs.vscode}/bin/code"; tooltip = "IDE"; }
          ];
        };
      };
      displayManager = {
        enable = true;
        type = "ly";        # faithful to blaney; log in manually with initialPassword
        ly.theme = "century-series";
        # animationFile / ttyRows / ttyCols dropped — VM framebuffer geometry differs.
      };
    };

    homeManager = {
      enable = true;
      # Mirror blaney-pc: notify at next login if a walk-away rebuild-shutdown failed.
      services.rebuildShutdownNotify.enable = true;
      themes = {
        plasmaOverride = true;
        kde = "windows7-alt";      # aerothemeplasma — the thing we're here to test
        hyprland = "century-series";
        # XFCE windows7 taskbar — mirror blaney-pc EXACTLY so the pre-PR VM check shows his
        # real taskbar (pick "Xfce Session" at Ly). Keep this identical to hosts/blaney-pc.
        xfce = "windows7";
        xfceOverride = true;
        wallpaper = ../../assets/wallpapers/windows7-wallpaper.jpg;
        # Mirror blaney-pc: XFCE gets the aviation wallpaper (no desktop.monitors → f-15 on all),
        # KDE keeps Win7.
        xfceWallpaper = ../../assets/wallpapers/f-15-satellite.jpg;
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
          "applications:org.kde.plasma-systemmonitor.desktop"
          "applications:org.kde.kcalc.desktop"
        ];
      };
    };

    packages = {
      nixos = with pkgs; [ ];
      unstable-override = [ ];
      homeManager = with pkgs; [
        kitty
        notes
        # Taskbar-icon fidelity: blaney pins these peripheral GUIs, but vm-common force-disables
        # customConfig.hardware.peripherals (no devices in a VM), so install the GUI packages
        # directly here so their launcher icons resolve on the XFCE taskbar. They just won't find
        # any hardware when opened — fine for a visual taskbar check.
        polychromatic
        openrgb
        input-remapper
      ];
      flatpak = {
        enable = true;
        # blaney's flatpak apps — their taskbar icons (org.chromium.Chromium / com.discordapp.Discord
        # / com.spotify.Client) only resolve after flatpak installs them on first boot (VM has NAT
        # network). Until then those three show a fallback icon.
        packages = [
          "org.chromium.Chromium"
          "com.discordapp.Discord"
          "com.spotify.Client"
        ];
      };
    };

    apps = {
      defaultSet = "kde";
      defaults.kde.browser = "chromium.desktop";
    };

    profiles = {
      # Un-trimmed now: the taskbar pins Steam/Heroic/Lutris, so enable the gaming profile to
      # get their .desktop files + icons (already cached on gaming-pc's store — cheap to include;
      # they just won't run under llvmpipe). Needed for a faithful taskbar render.
      gaming.enable = true;
    };

    services = {
      ssh.enable = false;
      vscodeServer.enable = false;
    };

  };

  # === Host-specific NixOS configuration ===

  # Throwaway login password (ly has no autologin here; sign in as insideabush / "vm").
  users.users.${config.customConfig.user.name}.initialPassword = "vm";

  # The gaming stack (Steam/Heroic/Lutris) doesn't fit in vm-common's 20G throwaway disk.
  # Bump it for this VM only (qcow2 is thin-provisioned, so it costs host disk only as filled).
  virtualisation.vmVariant.virtualisation.diskSize = lib.mkForce 61440; # 60 GiB

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };

}
