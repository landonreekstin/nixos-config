# ~/nixos-config/modules/nixos/homelab/audiobookshelf.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.audiobookshelf;
in
{
  options.customConfig.homelab.audiobookshelf = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable Audiobookshelf, the audiobook server and player for the library
        Bookshelf fills. Web player plus iOS/Android apps with progress sync.
        Its root user and libraries live in its own database and are set in
        the first-run UI - see docs/audiobooks.md.
      '';
    };

    port = mkOption {
      type = types.port;
      # nixpkgs defaults to 8000, which is too generic a port to be safe here.
      default = 13378;
      description = "Port Audiobookshelf listens on. Fronted by nginx as books.lan.";
    };
  };

  config = lib.mkIf cfg.enable {

    services.audiobookshelf = {
      enable = true;
      # Bind on all interfaces for the same reason as navidrome.nix: VPN peers
      # and anything without the .lan zone reach services by IP.
      host = "0.0.0.0";
      port = cfg.port;
      openFirewall = true;
    };

    # Library dirs are 2775 lando:media; group membership keeps them readable
    # regardless of the umask an import landed with.
    users.users.audiobookshelf.extraGroups = [ "media" ];

  };
}
