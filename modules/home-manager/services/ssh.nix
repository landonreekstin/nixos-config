{ config, lib, pkgs, customConfig, ... }:

let
    sshEnable = customConfig.services.ssh.enable;
    isLandoPC = customConfig.user.name == "lando";
in
{
    config = lib.mkIf (sshEnable && isLandoPC) {
        services.ssh-agent.enable = true;

        programs.ssh = {

            enable = true;
            enableDefaultConfig = false;

            matchBlocks = {
            # Keepalive settings to prevent idle connections from being dropped by firewalls/NAT
            "*" = {
                serverAliveInterval = 60;
                serverAliveCountMax = 3;
            };
            "fw" = {
                hostname = "192.168.1.189";
                user = "lando";
            };

            "nas" = {
                # Behind optiplex-fw on the server subnet post-migration; .76 is now a
                # firewall alias (port 22 there hits the fw), so jump through fw to reach it.
                hostname = "192.168.100.76";
                user = "lando";
                proxyJump = "fw";
            };

            "atl-mini-pc" = {
                hostname = "192.168.1.206";
                user = "heather";
            };

            "mini-server" = {
                hostname = "192.168.100.103";
                user = "lando";
                proxyJump = "fw";
            };

            "optiplex" = {
                hostname = "192.168.100.100";
                user = "lando";
                proxyJump = "fw";
            };
            };

        };
    };
}