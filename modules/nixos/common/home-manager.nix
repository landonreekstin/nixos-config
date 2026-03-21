# ~/nixos-config/modules/nixos/common/home-manager.nix
{ inputs, ... }:
{
  home-manager = {
    # Overwrite existing .hm-backup files on each rebuild instead of failing.
    # Without this, HM fails when a backup file already exists from a previous run.
    overwriteBackup = true;

    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";

    # Load the shared HM module set for every managed user on every host.
    sharedModules = [
      inputs.plasma-manager.homeModules.plasma-manager
      ../../home-manager/default.nix
    ];
  };
}
