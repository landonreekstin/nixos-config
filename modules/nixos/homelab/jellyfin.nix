# ~/nixos-config/modules/nixos/homelab/jellyfin.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.jellyfin;
in
{
  # Define our custom options for the Jellyfin module
  options.customConfig.homelab.jellyfin = {
    enable = lib.mkEnableOption "Enable the Jellyfin media server";
    
    hwTranscoding = lib.mkEnableOption "Enable hardware video transcoding";
  };

  # Configure the system if Jellyfin is enabled
  config = lib.mkIf cfg.enable {
    
    # Enable the Jellyfin service itself.
    services.jellyfin = {
      enable = true;
      # Open the default port (8096) in the firewall.
      openFirewall = true;
    };

    # This block will be applied only if hwTranscoding is also enabled.
    hardware.vaapi = lib.mkIf cfg.hwTranscoding {
      # Enables the VA-API drivers needed for Intel Quick Sync.
      enable = true;
      # Some applications require this specific driver.
      drivers = [ pkgs.intel-media-driver ];
    };

    # Add the jellyfin user to the 'render' group to grant it permission
    # to use the hardware transcoding device.
    users.users.jellyfin.extraGroups = lib.mkIf cfg.hwTranscoding [ "render" ];
  };
}