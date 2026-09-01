# ~/nixos-config/hosts/optiplex/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    apps.programs.browserAlt = { package = pkgs.chromium; exe = "chromium"; };
    apps.programs.chat = { package = pkgs.discord; exe = "discord"; };

    programs = {
      partydeck.enable = false;
      claudeCode.enable = true;
    };

    packages = {
      nixos = with pkgs; [
        firefox
        kitty
        claude-code
      ];
      unstable-override = [
        "vscode"
        #"librewolf"
        "ungoogled-chromium"
        "claude-code"
      ];
      # vscode comes from customConfig.apps.programs.ide.
      homeManager = with pkgs; [
        jamesdsp
        remmina
        ungoogled-chromium
        notes
      ];
      flatpak = {
        enable = true;
        packages = [
          "com.spotify.Client"
          "com.discordapp.Discord"
        ];
      };
    };

  };
}
