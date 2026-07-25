# ~/nixos-config/hosts/vm-sandbox/default.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

# Kitchen-sink ricing sandbox — a throwaway QEMU VM that turns on the fragile paradigms
# (aerothemeplasma KDE + Hyprland/century-series + browser/app config) all at once, so
# desktop/theme/app work can be iterated without touching gaming-pc. See ../vm-common.nix
# for VM sizing, guest tooling, and the nvidia/peripherals force-off.
{
  imports = [
    ../../modules/nixos/default.nix
    ../vm-common.nix
  ];

  customConfig = {

    user = {
      name = "lando";
      email = "landonreekstin@gmail.com";
      updateCmdPermission = false;
    };

    system = {
      hostName = "vm-sandbox";
      stateVersion = "25.11";
      timeZone = "America/New_York";
      locale = "en_US.UTF-8";
    };

    bootloader.quietBoot = false;

    desktop = {
      environments = [ "kde" "hyprland" "xfce" ];
      kde.kwallet.enable = false;
      displayManager = {
        enable = true;
        type = "sddm"; # sddm → autologin wired in vm-common
      };
    };

    homeManager = {
      enable = true;
      themes = {
        plasmaOverride = true;
        kde = "windows7-alt";      # aerothemeplasma (source-built)
        hyprland = "century-series";
        wallpaper = ../../assets/wallpapers/windows7-wallpaper.jpg;
      };
      librewolf = {
        enable = true;             # browser config surface
        overrideConfig = false;
      };
    };

    packages = {
      nixos = with pkgs; [ ];
      unstable-override = [ ];
      homeManager = with pkgs; [
        kitty
        notes
        vesktop  # screen-share / ScreenCast portal testing in a real Plasma Wayland session
      ];
      flatpak.enable = false;
    };

    apps = {
      defaultSet = "kde";
    };

    profiles = {
      gaming.enable = false; # keep the VM light — not testing the gaming stack here
    };

    services = {
      ssh.enable = false;
      vscodeServer.enable = false;
    };

  };

  # === Host-specific NixOS configuration ===

  # Autologin into XFCE while the windows7-xfce theme is under development (M1–M4).
  # Revert to "plasma" (or pick at the SDDM chooser) once XFCE work is verified.
  services.displayManager.defaultSession = lib.mkForce "xfce";

  # Throwaway login password (autologin covers the GUI; this is for sudo / TTY).
  users.users.${config.customConfig.user.name}.initialPassword = "vm";

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };

}
