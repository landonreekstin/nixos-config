# ~/nixos-config/modules/nixos/programs/quiver.nix
{ config, pkgs, lib, ... }:

# Quiver Launcher (pkgs/quiver-launcher): browse the quiverlauncher.com catalog of PC
# ports and recomps, install them, and play them from one window. Games run inside
# Quiver's FHS environment, which is why they work on NixOS at all.
#
# Known limits:
#   - Launch games from Quiver. The desktop/Steam shortcuts it can write point at paths
#     that only exist inside its FHS environment.
#   - Catalog entries shipped as .flatpak bundles need the host's flatpak CLI, which the
#     environment doesn't have. Pick another release asset for those.
#   - N64 recomps need your own ROM, chosen in the game's own first-run dialog.
let
  cfg = config.customConfig.programs.quiver;
  quiver = pkgs.callPackage ../../../pkgs/quiver-launcher { };
in
{
  options.customConfig.programs.quiver = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install Quiver Launcher, which downloads and runs PC ports and recompiled games
        (Zelda64Recomp, 2 Ship 2 Harkinian, ...) inside an FHS environment.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ quiver ];

    # Many games ship as AppImages, which can't FUSE-mount inside Quiver's bwrap
    # environment (see pkgs/quiver-launcher). With binfmt the kernel hands any AppImage
    # Quiver starts to appimage-run, which extracts it and runs it in its own FHS env.
    # It also makes AppImages run when opened anywhere else on the system.
    programs.appimage = {
      enable = true;
      binfmt = true;
      package = pkgs.appimage-run.override { extraPkgs = quiver.passthru.gameLibs; };
    };
  };
}
