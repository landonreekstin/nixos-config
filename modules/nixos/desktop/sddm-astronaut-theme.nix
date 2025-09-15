# ~/nixos-config/modules/nixos/desktop/sddm-astronaut-theme.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.desktop.displayManager;

  sddm-astronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = cfg.sddmEmbeddedTheme;
  };

  sddmAstronautThemeEnabled = (cfg.enable)
                            && (cfg.type == "sddm")
                            && (cfg.sddmTheme == "sddm-astronaut");
in
{
  config = lib.mkIf sddmAstronautThemeEnabled {
    services.displayManager.sddm = {
      #package = pkgs.kdePackages.sddm;
      theme = "sddm-astronaut-theme";
      #settings = {
      #  Theme = {
      #    Current = "sddm-astronaut-theme";
      #  };
      #};
      extraPackages = with pkgs; [
        sddm-astronaut
        kdePackages.qtmultimedia # For video backgrounds
        kdePackages.qtsvg        # For SVG icons and elements
        # qtvirtualkeyboard is often needed for the on-screen keyboard in the theme
        kdePackages.qtvirtualkeyboard
      ];
    };
    environment.systemPackages = with pkgs; [
      sddm-astronaut
    ];
  };
}