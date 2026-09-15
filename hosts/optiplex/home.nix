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
    browser.librewolf = {
      enable = true;
      overrideConfig = false;

      # LibreWolf wipes cookies and site storage on close by default, and these
      # hosts have always done that. The preset now writes the pref explicitly
      # rather than omitting it when false, so without this line the rebuild
      # would silently stop the wipe — a behaviour change on a host that cannot
      # be checked from here. Flip it to false deliberately, in person.
      privacy.sanitizeOnShutdown = true;

      # search.force and containersForce rewrite search.json.mozlz4 and
      # containers.json on this host's existing profile, and the old librewolf
      # module managed neither. Left off until this host can be checked in
      # person; the rest of the preset matches what it already had.
      personal.search.enable = false;
      personal.containers.enable = false;
    };
  };

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };
}
