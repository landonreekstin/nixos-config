# ~/nixos-config/hosts/vm-sandbox/home.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

{
  customConfig.homeManager = {
    enable = true;
    themes = {
      plasmaOverride = true;
      kde = "windows7-alt";      # aerothemeplasma (source-built)
      hyprland = "century-series";
      xfce = "windows7";         # B00merang GTK/xfwm4 + aero cursor/sounds
      wallpaper = ../../assets/wallpapers/windows7-wallpaper.jpg;
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
