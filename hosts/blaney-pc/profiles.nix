# ~/nixos-config/hosts/blaney-pc/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    gaming.enable = true;
    development.gbdk.enable = true;
    # Toolchains for his own vibe-coded apps, reached through each project's .envrc
    # (customConfig.programs.vibeProjects in ./apps.nix).
    development.vibe-python.enable = true;
    development.vibe-web.enable = true;
  };
}
