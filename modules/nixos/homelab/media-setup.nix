# ~/nixos-config/modules/nixos/homelab/media-setup.nix
{ config, lib, ... }:

let
  # A shortcut to the options for this module
  cfg = config.customConfig.homelab.mediaSetup;
  # A shortcut to the arr service options
  arrCfg = config.customConfig.homelab.arr;
in
{
  # This is the actual NixOS configuration that will be applied when the module is enabled.
  config = lib.mkIf cfg.enable {

    # 1. Create the shared 'media' group
    users.groups.media = {};

    # 2. Add all relevant service users to the 'media' group automatically
    #    if their respective services are enabled. This makes the module robust.
    users.users = {
      # Add main user (e.g., "lando")
      ${cfg.user}.extraGroups = [ "media" ];

      jellyfin = lib.mkIf config.customConfig.homelab.jellyfin.enable {
        extraGroups = [ "media" ];
      };
      #transmission = lib.mkIf config.customConfig.homelab.transmission.enable {
      #  extraGroups = [ "media" ];
      #};
      prowlarr = lib.mkIf arrCfg.prowlarr.enable {
        extraGroups = [ "media" ];
      };
      sonarr = lib.mkIf arrCfg.sonarr.enable {
        extraGroups = [ "media" ];
      };
      radarr = lib.mkIf arrCfg.radarr.enable {
        extraGroups = [ "media" ];
      };
      bazarr = lib.mkIf arrCfg.bazarr.enable {
        extraGroups = [ "media" ];
      };
    };

    # 3. Declaratively create directories and set their permissions.
    #    This is the core fix for your "Access denied" problem.
    systemd.tmpfiles.rules = [
      # Set ownership and permissions on the top-level mount points
      "d ${cfg.storagePath} 0775 ${cfg.user} media -"
      "d ${cfg.cachePath}   0775 ${cfg.user} media -"

      # Create and manage main storage subdirectories
      "d ${cfg.storagePath}/downloads 0775 ${cfg.user} media -"
      "d ${cfg.storagePath}/downloads/torrents 0775 ${cfg.user} media -"
      "d ${cfg.storagePath}/media 0775 ${cfg.user} media -"
      "d ${cfg.storagePath}/media/movies 0775 ${cfg.user} media -"
      "d ${cfg.storagePath}/media/tv 0775 ${cfg.user} media -"
      
      # Create and manage cache subdirectories
      "d ${cfg.cachePath}/torrents 0775 ${cfg.user} media -"
      "d ${cfg.cachePath}/torrents/incomplete 0775 ${cfg.user} media -"
    ];
  };
}