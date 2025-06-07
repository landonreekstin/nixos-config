# ../../modules/home-manager/common/git.nix
{ config, lib, ... }:
{
  programs.git = {
    enable = true;
    userName = config.hmCustomConfig.user.name; # The display name
    userEmail = config.hmCustomConfig.user.email;
  };
}