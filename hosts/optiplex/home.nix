# ~/nixos-config/hosts/optiplex/home.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

{
  customConfig.homeManager = {
    enable = true;
    themes = {
      plasmaOverride = false;
      kde = "windows7-alt";
      hyprland = "century-series";
      wallpaper = ../../assets/wallpapers/windows7-wallpaper.jpg;
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
        "applications:org.kde.plasma-systemmonitor.desktop"
        "applications:org.kde.kcalc.desktop"
        "applications:code.desktop"
        "applications:polychromatic.desktop"
        "applications:input-remapper-gtk.desktop"
        "applications:librewolf.desktop"
        "applications:OpenRGB.desktop"
        "applications:io.github.nuttyartist.notes.desktop"
      ];
    };
    librewolf = {
      enable = true;
      overrideConfig = false;
    };
  };

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };
}
