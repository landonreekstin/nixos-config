# ../../modules/home-manager/common/git.nix
{ config, lib, customConfig, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = customConfig.user.name; # The display name
      user.email = customConfig.user.email;
    };
  };
}