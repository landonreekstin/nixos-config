# ~/nixos-config/modules/nixos/desktop/kde.nix
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    
  ];
  # ==> Configuration (Applied only if profile is enabled) <==
  config = lib.mkIf (lib.elem "pantheon" config.customConfig.desktop.environments) {

    # Enable Pantheon Desktop Environment itself
    services.xserver.desktopManager.pantheon.enable = true;
    programs.xwayland.enable = true;

    services.pantheon.apps.enable = true;

    # Add packages useful for KDE environment
    environment.systemPackages = with pkgs; [
      
    ];

  };
}