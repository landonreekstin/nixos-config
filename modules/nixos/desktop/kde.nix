# ~/nixos-config/modules/nixos/desktop/kde.nix
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    
  ];
  # ==> Configuration (Applied only if profile is enabled) <==
  config = lib.mkIf config.customConfig.programs.kde.enable {

    # Enable Plasma6 Desktop Environment itself
    services.desktopManager.plasma6.enable = true;

    # Add packages useful for KDE environment
    environment.systemPackages = with pkgs; [
      
    ];

  };
}