# ~/nixos-config/modules/nixos/desktop/sddm-windows7-theme.nix
{ config, pkgs, lib, ... }:

let
  dmCfg = config.customConfig.desktop.displayManager;
  sddmCfg = dmCfg.sddm;

  sddmWindows7ThemeEnabled = (dmCfg.enable)
                           && (dmCfg.type == "sddm")
                           && (sddmCfg.theme == "sddm-windows7");
in
{
  config = lib.mkIf sddmWindows7ThemeEnabled {
    services.displayManager.sddm = {
      theme = "sddm-theme-mod";
      
      # Fix QtMultimedia missing error by providing necessary packages
      extraPackages = [
        pkgs.kdePackages.qtmultimedia
        pkgs.kdePackages.qtsvg
        pkgs.kdePackages.qtvirtualkeyboard
      ];
      
      # Ensure startup sound can play by removing startup file before each session
      setupScript = ''
        rm -f /tmp/sddm.startup
      '';
      
      settings = {
        General = {
          HideShells = "/run/current-system/sw/bin/nologin";
          HideUsers = "nixbld1,nixbld2,nixbld3,nixbld4,nixbld5,nixbld6,nixbld7,nixbld8,nixbld9,nixbld10,nixbld11,nixbld12,nixbld13,nixbld14,nixbld15,nixbld16,nixbld17,nixbld18,nixbld19,nixbld20,nixbld21,nixbld22,nixbld23,nixbld24,nixbld25,nixbld26,nixbld27,nixbld28,nixbld29,nixbld30,nixbld31,nixbld32";
        };
        Theme = {
          CursorTheme = "aero-drop";
          forceUserSelect = "true";
          enableStartup = "false";
          playSound = "true";
        };
      };
    };
  };
}