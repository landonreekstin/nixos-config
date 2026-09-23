# ~/nixos-config/modules/nixos/homelab/samba.nix
{ config, lib, pkgs, ... }:

let
  # Pull the customConfig settings into a local variable for easier access.
  cfg = config.customConfig.homelab.samba;
in
{
  options.customConfig.homelab.samba = with lib; {
    enable = mkOption { 
      type = types.bool; 
      default = false; 
      description = "Enable Samba file sharing service."; 
    };
    private = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable a separate, private Samba share on a custom port.";
      };
      port = mkOption {
        type = types.port;
        default = 4445; # A non-standard port for the private share
        description = "The TCP port for the private Samba service to listen on.";
      };
      path = mkOption {
        type = types.str;
        default = "/mnt/private";
        description = "The absolute path for the private share.";
      };
      user = mkOption {
        type = types.str;
        # This cleverly defaults to the main user defined for the system
        default = config.customConfig.user.name;
        defaultText = "config.customConfig.user.name";
        description = "The user that will be forced for file operations on the private share.";
      };
    };
  };

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
          # Also set the ncalrpc directory to avoid conflicts
          ncalrpc dir = /run/samba-private/ncalrpc

          [private]
          # Values are NOT quoted: smb.conf takes the rest of the line verbatim, so a
          # quoted value keeps its quotes. `force user = "lando"` never resolved to the
          # real account, which silently reduced every client to the *group* rights of
          # the share (`lando:users 775` worked, an owner-only `lando:users 700` did
          # not) -- exactly the rights force user exists to grant. The main share does
          # not have the bug because services.samba generates its config.
          path = ${cfg.private.path}
          browseable = yes
          read only = no
          guest ok = no
          force user = ${cfg.private.user}
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
        # Never serve the share unless its path is a REAL mountpoint.
        #
        # The private share lives on a nofail LUKS drive. When that drive failed to
        # enumerate (2026-09-14), the mount was skipped, the path was left as a bare
        # directory on the root filesystem, and smbd happily exported it writable —
        # so anything written to the "private" share would have landed unencrypted
        # on /, and could have filled the root disk. RequiresMountsFor ties this unit
        # to the mount; ConditionPathIsMountPoint makes it skip cleanly rather than
        # serve the wrong directory.
        unitConfig = {
          RequiresMountsFor = cfg.private.path;
          ConditionPathIsMountPoint = cfg.private.path;
        };
        serviceConfig = {
          Type = "notify";
          # We point the smbd binary to our custom config file.
          ExecStart = ''
            ${pkgs.samba}/bin/smbd --foreground --no-process-group --configfile=/etc/smb-private.conf
          '';
          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          # Create the /run/samba-private directory needed for the pid file.
          RuntimeDirectory = "samba-private";
          RuntimeDirectoryMode = "0755";
        };
        preStart = ''
          # Create the ncalrpc subdirectory that Samba needs
          ${pkgs.coreutils}/bin/mkdir -p /run/samba-private/ncalrpc
        '';
      };

      # 3. Ensure our new service is started at boot.
      systemd.targets.multi-user.wants = [ "samba-private.service" ];

      # 4. Open the custom port in the NixOS firewall.
      networking.firewall.allowedTCPPorts = [ cfg.private.port ];
    })
  ];
}
