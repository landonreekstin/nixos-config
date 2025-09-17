# ~/nixos-config/modules/home-manager/services/password-manager.nix
{ config, lib, pkgs, customConfig, ... }:

{
  # This makes the module's configuration conditional on our custom option.
  config = lib.mkIf customConfig.services.passwordManager.enable {

    # 1. Enable KeePassXC
    programs.keepassxc = {
      enable = true;
      # Recommended setting to prevent conflicts with Home Manager's declarative setup.
      settings.Browser.UpdateBinaryPath = false;
    };

    # 2. Enable and configure Syncthing
    services.syncthing = {
      enable = true;
      # Enable the tray icon for easier access on desktop environments.
      tray.enable = true; 

      # By setting these to false, you can add new devices (like your phone)
      # and folders through the Syncthing Web UI without Nix undoing your changes
      # on the next rebuild. This is crucial for your use case.
      overrideDevices = false;
      overrideFolders = false;

      settings = {
        folders = {
          # Use the path from our custom option to define the folder to sync.
          "${customConfig.services.passwordManager.folderPath}" = {
            # You can change this ID, but it must be consistent across devices.
            id = "keepass-database"; 
            label = "KeePass Database"; # This is the name you'll see in the GUI
            # The path on disk where the files will be stored.
            path = customConfig.services.passwordManager.folderPath;
          };
        };
      };
    };

  };
}