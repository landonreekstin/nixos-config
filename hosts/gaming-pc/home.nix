# ~/nixos-config/hosts/optiplex/home.nix
{ pkgs, config, lib, inputs, ... }:

{

  imports = [
    # === Common User Environment Modules ===
    ../../modules/home-manager/default.nix

    # === Theme Module ===
    ../../modules/home-manager/themes/future-aviation/default.nix
  ];

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; # Your existing setting
    extraSpecialArgs = { inherit inputs; };
    # Use the username from customConfig
    users.${config.customConfig.user.name} = { pkgs', lib', config'', ... }: { # config'' here is the HM config being built for this user
      imports = [ ./home.nix ];

      # Set the VALUES for hmCustomConfig options
      # These will be part of the 'config''' object that ./home.nix receives
      hmCustomConfig = {
        user = {
          name = config.customConfig.user.name; # 'config' here is the outer NixOS config
          email = config.customConfig.user.email;
          loginName = config.customConfig.user.name;
          homeDirectory = "/home/${config.customConfig.user.name}";
          shell = config.customConfig.user.shell;
        };
        desktop = config.customConfig.desktop.environment;
        theme = config.customConfig.homeManager.theme.name;
        systemStateVersion = config.customConfig.system.stateVersion;
        packages = config.customConfig.packages.homeManager;
      };
    };
  };

}
