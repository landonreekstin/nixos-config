# ~/nixos-config/modules/nixos/profiles/flatpak.nix
{ config, pkgs, lib, inputs, ... }:

{

  imports = [
    inputs.nix-flatpak.nixosModules.nix-flatpak
  ];

  config = lib.mkIf config.customConfig.packages.flatpak.enable {
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
    services.flatpak.packages = config.customConfig.packages.flatpak.packages;

    # The Flathub mcpelauncher build exits immediately (255, printing only
    # "SAFE_MODE before exec: (null)") when QT_STYLE_OVERRIDE is set. nixpkgs'
    # own mcpelauncher-ui-qt derivation wraps the binary to unset that variable
    # for exactly this reason; the Flathub build carries no such wrapper.
    #
    # The century-series Hyprland theme exports QT_STYLE_OVERRIDE=adwaita-dark
    # (themes/century-series/hyprland.nix), so every launch from rofi or the app
    # menu inherited it and died, while launching from a sanitised environment
    # worked — which is what made this look like an intermittent failure.
    # Strip it for this one app rather than dropping the session-wide Qt theming.
    services.flatpak.overrides = lib.optionalAttrs
      (builtins.elem "io.mrarm.mcpelauncher" config.customConfig.packages.flatpak.packages)
      {
        "io.mrarm.mcpelauncher" = {
          Environment.QT_STYLE_OVERRIDE = "";
          Context.unset-environment = [ "QT_STYLE_OVERRIDE" ];
        };
      };

  };
}
