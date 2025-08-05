# ~/nixos-config/modules/nixos/common/users-groups.nix
{ config, pkgs, lib, ... }:
let
  cfg = config.customConfig; # Shortcut
in
{

  users.users.${cfg.user.name} = {
    isNormalUser = true;
    description = cfg.user.name;
    extraGroups = [ "networkmanager" "wheel" "video" "audio" ]; # Common groups, can be an option
    openssh.authorizedKeys.keys = lib.mkIf (cfg.services.ssh.enable) [ # Simpler: if SSH service is on for host, apply these keys for this user
      # Ensure this user is the one these keys are for. If keys are specific to 'lando'
      # you might need: lib.mkIf (cfg.services.ssh.enable && cfg.user.name == "lando")
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILMzC5MBalzHuf4Bzd29KuvfaPSR91s7X+xg1OhZjnnu"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILiUu/xNgEdcsIuaLekWDzty1JGyk2Asy7eqnbriPkmE"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAHx/cuuV/hFddQhYcoTGLWfbxbNfMPBYzkmD5cnriFM"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYktBy6Y6JHbuCNaRAGI3xD8Zfdf9p+Ya+Z7W5EczjI"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICSrv2XS/TnsS3msswQl7jvaGK6luOoca2HExxT1Hwip"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOIskZoPWjwNZiMshj1N4qsotaRneJH7Noa195EiZj3e"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP2HwEWfiXzoAxXnMiP9FLZAbOgcdxhTtcWtxYxooNEQ"

    ];
    shell = cfg.user.shell;
    home = cfg.user.home;
  };
}