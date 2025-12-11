# ~/nixos-config/modules/nixos/homelab/samba.nix
{ config, lib, pkgs, ... }:

let
  # Pull the customConfig settings into a local variable for easier access.
  cfg = config.customConfig.homelab.samba;
in
{
  # We use mkMerge to combine multiple conditional blocks into the final config.
  config = lib.mkMerge [

    # --- BLOCK 1: ORIGINAL "PUBLIC" SAMBA SHARE ---
    (lib.mkIf cfg.enable {
      # This is your existing configuration for the main share.
      services.samba = {
        enable = true;
        winbindd.enable = true;
        nmbd.enable = true;
        openFirewall = true;
        settings = {
          global = {
            "log level" = 3; # Add this line
          };
          storage = {
            path = "/mnt/storage";
            browseable = "yes";
            "read only" = "no";
            "guest ok" = "no";
            "force user" = config.customConfig.user.name;
            "create mask" = "0664";
            "directory mask" = "0775";
            "inherit permissions" = "yes";
          };
        };
      };

      # WS-Discovery for the main share.
      services.samba-wsdd = {
        enable = true;
        openFirewall = true;
      };
    })

    # --- BLOCK 2: NEW "PRIVATE" SAMBA SHARE ---
    (lib.mkIf cfg.private.enable {

      # 1. Dynamically create a separate config file for our private instance.
      #    This file will be placed in /etc/smb-private.conf on the system.
      environment.etc."smb-private.conf" = {
        text = ''
          [global]
          # This is the crucial part: listen on a different port.
          smb ports = ${toString cfg.private.port}

          # Give it a different NetBIOS name to avoid conflicts.
          netbios name = ${config.customConfig.system.hostName}-private
          workgroup = WORKGROUP
          server string = Private Samba Server
          security = user
          map to guest = bad user
          # Use a different PID file location so it doesn't clash with the main service.
          pid directory = /run/samba-private

          [private]
          path = "${cfg.private.path}"
          browseable = yes
          read only = no
          guest ok = no
          force user = "${cfg.private.user}"
          # Set sane default permissions for new files and directories.
          create mask = 0664
          directory mask = 0775
        '';
      };

      # 2. Define the new systemd service to run the private Samba daemon.
      systemd.services.samba-private = {
        description = "Private Samba SMB Daemon";
        after = [ "network.target" ];
        wants = [ "network.target" ];
        serviceConfig = {
          Type = "notify";
          # We point the smbd binary to our custom config file.
          ExecStart = ''
            ${pkgs.samba}/bin/smbd --foreground --no-process-group --configfile=/etc/smb-private.conf
          '';
          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          # Create the /run/samba-private directory needed for the pid file.
          RuntimeDirectory = "samba-private";
        };
      };

      # 3. Ensure our new service is started at boot.
      systemd.targets.multi-user.wants = [ "samba-private.service" ];

      # 4. Open the custom port in the NixOS firewall.
      networking.firewall.allowedTCPPorts = [ cfg.private.port ];
    })
  ];
}