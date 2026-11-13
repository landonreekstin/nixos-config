# ~/nixos-config/hosts/blaney-pc/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    gaming.enable = true;
    # Quest 2 over USB (WiVRn) + the DCS / War Thunder / Phasmophobia VR launchers. See docs/vr.md.
    vr.enable = true;
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
      # lando's games, worked on from `vibe`. prin-rpg is on our Forgejo (docs/forgejo.md)
      # and he commits to main; sub-of-seas is on GitHub, through blaney/ branches and PRs.
      forgejo.tokenFile = config.sops.secrets.forgejo-token.path;
      sharedProjects.prin-rpg = {
        repo = "lando/prin-rpg"; forge = "forgejo"; blaneyCommitsToMain = true;
        title = "prin-rpg (the Principia campus game)";
      };
      sharedProjects.sub-of-seas = { repo = "landonreekstin/sub-of-seas"; title = "sub-of-seas (the co-op WWII submarine game)"; };
    };
  };

  # This host's Forgejo access token, for the `homelab` git credential helper
  # (gamedev.forgejo.tokenFile above, docs/forgejo.md).
  sops.secrets.forgejo-token = {
    sopsFile = ../../secrets/blaney-pc-forgejo.yaml;
    owner = config.customConfig.user.name;
  };
}
