# ~/nixos-config/hosts/atl-mini-pc/home.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

{
  customConfig.homeManager = {
    enable = true; # Enable Home Manager for this host
    themes = {
      kde = "default";
      wallpaper = ../../assets/wallpapers/soviet-retro-future.jpg;
    };
  };

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };
}
