# ~/nixos-config/hosts/vm-blaney/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    # Un-trimmed now: the taskbar pins Steam/Heroic/Lutris, so enable the gaming profile to
    # get their .desktop files + icons (already cached on gaming-pc's store — cheap to include;
    # they just won't run under llvmpipe). Needed for a faithful taskbar render.
    gaming.enable = true;
    # Mirrors blaney-pc so the `vibe` command can be exercised in this VM.
    development.vibe-python.enable = true;
    development.vibe-web.enable = true;
  };
}
