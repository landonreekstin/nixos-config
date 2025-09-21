# Create new file: ~/nixos-config/modules/home-manager/programs/firefox.nix

{ config, lib, pkgs, customConfig, ... }:

let
  # A shortcut to our custom options for this module
  cfg = customConfig.programs.firefox;

  # Use the primary username from customConfig to name the Firefox profile.
  # This makes the module reusable across different hosts/users.
  userName = customConfig.user.name;
in
# Only evaluate the contents of this block if the user has enabled it.
lib.mkIf cfg.enable {

  programs.firefox = {
    # Enable the actual Home Manager firefox module
    enable = true;

    # Use the package defined in our custom options (defaults to librewolf)
    package = cfg.package;

    # Configure settings for a specific profile. We name it after the user.
    profiles.${userName} = {

      # Assign the extensions from our custom options
      extensions = {
        packages = cfg.extensions;
      };

      # Assign the bookmarks from our custom options
      bookmarks = {
        # This is required. It tells Home Manager it's okay to overwrite
        # the bookmarks.html file on each rebuild. Without this, your
        # bookmarks would never update after the first time.
        force = true;
        settings = [
          {
            name = "Bookmarks Toolbar";
            toolbar = true;
            bookmarks = cfg.bookmarks;
          }
        ];
      };

      # We can add more settings here in the future, such as:
      # settings = {
      #   "browser.startup.homepage" = "https://nixos.org";
      # };
    };
  };
}