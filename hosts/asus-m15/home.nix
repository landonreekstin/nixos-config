# ~/nixos-config/hosts/asus-m15/home.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

{
  customConfig.homeManager = {
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

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };
}
