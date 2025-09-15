# ~/nixos-config/hosts/justus-pc/default.nix
{ inputs, pkgs, lib, config, ... }: # Standard module arguments. `config` is the final NixOS config.

{
  imports = [
    # Hardware-specific configuration for this host
    ./hardware-configuration.nix
    
    # Top level nixos modules import. All other nixos modules and option definitions are nested.
    ../../modules/nixos/default.nix

    # Host specific disk configuration
    ./disko-config.nix

  ];

  # These values are for the options defined in `../../modules/nixos/common-options.nix`.
  customConfig = {
    
    user = {
      name = "justus";
      email = "cblaney00@gmail.com";
      updateCmdPermission = false; 
    };
    
    system = {
      hostName = "justus-pc"; # Actual hostname for this machine
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/New_York";
      locale = "en_US.UTF-8"; 
    };

    bootloader = {
      quietBoot = true;
    };
    
    desktop = {
      environments = [ "kde" ];
      displayManager = {
        enable = true; # false will go to TTY but not autolaunch a DE
        type = "sddm";
        sddmTheme = "sddm-astronaut";
        sddmEmbeddedTheme = "hyprland_kath";
      };
    };

    hardware = {
      nvidia = {
        enable = true;
      };
    };

    programs = {
      partydeck.enable = false;
      flatpak.enable = true;
    };

    homeManager = {
      enable = true; # Enable Home Manager for this host
    };

    packages = {
      nixos = with pkgs; [
        vim
        wget
        fd
        htop
        pavucontrol
        g810-led
        openrgb
      ];
      homeManager = with pkgs; [
        vscode
        librewolf
        brave
        discord-canary
        discord
        spotify
        notes
        CuboCore.corepaint
        kdePackages.kdenlive
      ];
    };

    apps = {
      defaultBrowser = "librewolf";
    };

    profiles = {
      gaming.enable = true;
    };

    services = {
      ssh.enable = false;
      vscodeServer.enable = false;
    };

  };

  # === Additional nixos configuration for this host ===
  services.mullvad-vpn.enable = true;
  services.hardware.openrgb.enable = true; # Enable OpenRGB for RGB control
  #services.g810-led.package = pkgs.g810-led; # Ensure the g810-led package is available
  #services.g810-led.enable = true; # Enable Logitech G810 keyboard LED control

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; # Your existing setting
    extraSpecialArgs = { inherit inputs; customConfig = config.customConfig; };
    # Use the username from customConfig
    users.${config.customConfig.user.name} = { pkgs', lib', config'', ... }: { # config'' here is the HM config being built for this user
      imports = [
        # === Common User Environment Modules ===
        ../../modules/home-manager/default.nix

        # === Theme Module ===
        ../../modules/home-manager/themes/future-aviation/default.nix
      ];
    };
  };
  
}
