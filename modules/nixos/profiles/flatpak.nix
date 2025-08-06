# ~/nixos-config/modules/nixos/profiles/flatpak.nix
{ config, pkgs, lib, inputs, ... }:

{

  imports = [
    inputs.nix-flatpak.nixosModules.nix-flatpak
  ];

  config = lib.mkIf config.customConfig.profiles.flatpak.enable {
    # Required to install flatpak
    xdg.portal = {
        enable = true;
        config = {
        common = {
            default = [
            "gtk"
            ];
        };
        };
        extraPortals = with pkgs; [
            xdg-desktop-portal-wlr
            kdePackages.xdg-desktop-portal-kde
            xdg-desktop-portal-gtk
        ];
    };
    
    # install flatpak binary
    services.flatpak.enable = true;
    
    # Add a new remote. Keep the default one (flathub)
    services.flatpak.remotes = lib.mkOptionDefault [{
        name = "flathub-beta";
        location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
    }];

    services.flatpak.update.auto.enable = true;
    services.flatpak.uninstallUnmanaged = false;

    # Add here the flatpaks you want to install
    services.flatpak.packages = [
        #{ appId = "com.brave.Browser"; origin = "flathub"; }
        #"com.obsproject.Studio"
        #"im.riot.Riot"
        "com.spotify.Client"
        #"com.discordapp.Discord"
    ];

  };
}
