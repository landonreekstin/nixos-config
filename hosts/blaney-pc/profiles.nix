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
    # REA for the "take apart a program or game" projects in `vibe`. Only the tools:
    # `re` and ~/reverse-engineering run Claude without sudo, and his Claude login is
    # root's. See docs/hosts/blaney-vibe-projects.md.
    development.reverse-engineering = {
      enable = true;
      workspace.enable = false;
    };
    # Engines + the gamedev skills for the "make a game" projects in `vibe`. Only the
    # tools, like reverse-engineering above. See docs/hosts/blaney-vibe-projects.md.
    development.gamedev = {
      enable = true;
      workspace.enable = false;
      # lando's games, worked on from `vibe` through blaney/ branches and PRs.
      sharedProjects.prin-rpg = { repo = "landonreekstin/prin-rpg"; title = "prin-rpg (the Principia campus game)"; };
      sharedProjects.sub-of-seas = { repo = "landonreekstin/sub-of-seas"; title = "sub-of-seas (the co-op WWII submarine game)"; };
    };
  };
}
