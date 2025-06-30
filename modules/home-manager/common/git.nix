# ../../modules/home-manager/common/git.nix
{ config, lib, customConfig, ... }:
{
  programs.git = {
    enable = true;
    userName = customConfig.user.name; # The display name
    userEmail = customConfig.user.email;
  };
}