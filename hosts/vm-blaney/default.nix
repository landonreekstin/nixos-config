# ~/nixos-config/hosts/vm-blaney/default.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

# blaney-pc software mirror — a throwaway QEMU VM that reproduces blaney-pc's KDE/aerotheme
# + Hyprland software configuration so his theme/plasma issues can be reproduced and fixed
# locally on gaming-pc before pushing a `blaney/` PR to that remote machine.
#
# Deliberately mirrors only the *software* surface. Hardware/boot bits are dropped: no
# hardware-configuration.nix, no plymouth, and ../vm-common.nix force-disables nvidia +
# peripherals (VM has no GPU/devices). The gaming stack and heavy package set are trimmed
# to keep VM builds fast — none of that affects aerothemeplasma rendering.
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
      environments = [ "kde" "hyprland" ];
      hyprland = {
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
      themes = {
        plasmaOverride = true;
        kde = "windows7-alt";      # aerothemeplasma — the thing we're here to test
        hyprland = "century-series";
        wallpaper = ../../assets/wallpapers/windows7-wallpaper.jpg;
        pinnedApps = [
          "applications:org.kde.konsole.desktop"
          "applications:systemsettings.desktop"
          "applications:org.kde.dolphin.desktop"
          "applications:org.chromium.Chromium.desktop"
          "applications:org.kde.plasma-systemmonitor.desktop"
          "applications:org.kde.kcalc.desktop"
        ];
      };
      librewolf = {
        enable = true;
        overrideConfig = false;
      };
    };

    packages = {
      nixos = with pkgs; [ ];
      unstable-override = [ ];
      homeManager = with pkgs; [
        kitty
        notes
      ];
      flatpak = {
        enable = true;
        packages = [
          "org.chromium.Chromium"
        ];
      };
    };

    apps = {
      defaultSet = "kde";
      defaults.kde.browser = "chromium.desktop";
    };

    profiles = {
      gaming.enable = false; # trimmed vs blaney-pc — not relevant to theme testing
    };

    services = {
      ssh.enable = false;
      vscodeServer.enable = false;
    };

  };

  # === Host-specific NixOS configuration ===

  # Throwaway login password (ly has no autologin here; sign in as insideabush / "vm").
  users.users.${config.customConfig.user.name}.initialPassword = "vm";

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };

}
