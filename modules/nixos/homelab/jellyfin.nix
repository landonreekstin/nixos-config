# ~/nixos-config/modules/nixos/homelab/jellyfin.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.jellyfin;
in
{
  # Configure the system if Jellyfin is enabled.
  config = lib.mkIf cfg.enable {
    
    # Enable the Jellyfin service.
    services.jellyfin = {
      enable = true;
      openFirewall = true;
    };

    # This block is now the corrected way to enable hardware transcoding.
    nixpkgs.config.packageOverrides = pkgs: {
      vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
    };
    hardware.graphics = lib.mkIf cfg.hwTranscoding {
      # Add the correct Intel VA-API driver to the system.
      # The Dell Optiplex 7040 has a 6th Gen Intel CPU, so intel-media-driver is correct.
      extraPackages = with pkgs; [
        intel-media-driver
      ];
    };

    # This part remains correct: grant the 'jellyfin' user access to the render device.
    users.users.jellyfin.extraGroups = lib.mkIf cfg.hwTranscoding [ "render" ];
  };
}