# ~/nixos-config/hosts/vm-blaney/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    apps = {
      defaultSet = "kde";
      defaults.kde.browser = "org.chromium.Chromium.desktop";

      # Mirrors blaney-pc: Chromium via Flatpak, no native browser installed.
      programs.browser = {
        package = null;
        command = "flatpak run org.chromium.Chromium";
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

  };
}
