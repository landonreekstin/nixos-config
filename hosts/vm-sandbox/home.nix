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
    librewolf = {
      enable = true;             # browser config surface
      overrideConfig = false;
    };
  };

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };
}
