# ~/nixos-config/modules/nixos/programs/options.nix
{ lib, pkgs, ... }:

# Program options that no NixOS module here implements. partydeck and claudeCode
# are declared by their own modules; firefox is read only by
# modules/home-manager/programs/firefox.nix, and flatpak has no consumer at all
# (the live one is customConfig.packages.flatpak, which programs/flatpak.nix reads).
{
  options.customConfig.programs = with lib; {
    firefox = {
      enable = lib.mkEnableOption "Enable Firefox/Librewolf configuration via Home Manager.";

      package = lib.mkOption {
        type = with lib.types; package;
        default = pkgs.firefox;
        defaultText = "pkgs.firefox";
        description = "The package to use for the Firefox configuration (e.g., pkgs.librewolf or pkgs.firefox).";
      };

      extensions = lib.mkOption {
        type = with lib.types; listOf package;
        default = [];
        description = "List of Firefox extensions to install.";
        example = ''
          with pkgs.nur.repos.rycee.firefox-addons; [
            ublock-origin
            privacy-badger
          ];
        '';
      };

      bookmarks = lib.mkOption {
        # The actual type is very complex, so 'anything' is sufficient here
        # since the firefox module itself will validate the structure.
        type = with lib.types; anything;
        default = [];
        description = "A declarative list of bookmarks and folders to configure.";
        example = ''
          [
            {
              name = "NixOS Search";
              url = "https://search.nixos.org/";
              keyword = "nix";
            }
            "separator"
            {
              name = "Reading List";
              toolbar = true; # Add this folder to the bookmarks toolbar
              bookmarks = [
                { name = "Some Blog"; url = "https://example.com"; }
              ];
            }
          ]
        '';
      };
    };
    flatpak = {
      enable = mkOption {
        type = types.bool;
        default = false; # Default to false, enable explicitly for Flatpak support
        description = "Enable Flatpak packages for Spotify and Discord.";
      };
    };
  };
}
