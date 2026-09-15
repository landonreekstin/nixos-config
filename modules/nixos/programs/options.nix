# ~/nixos-config/modules/nixos/programs/options.nix
{ lib, pkgs, ... }:

# Program options that no NixOS module here implements. partydeck and claudeCode
# are declared by their own modules; flatpak has no consumer at all (the live one
# is customConfig.packages.flatpak, which programs/flatpak.nix reads).
#
# customConfig.programs.firefox used to live here. It was dead: its only consumer,
# modules/home-manager/programs/firefox.nix, was never listed in
# modules/home-manager/programs/default.nix, so the package, extensions and
# bookmarks gaming-pc set through it had no effect. Browser configuration now
# lives at customConfig.homeManager.browser.{firefox,librewolf}, implemented by
# modules/home-manager/programs/browser/.
{
  options.customConfig.programs = with lib; {
    flatpak = {
      enable = mkOption {
        type = types.bool;
        default = false; # Default to false, enable explicitly for Flatpak support
        description = "Enable Flatpak packages for Spotify and Discord.";
      };
    };
  };
}
