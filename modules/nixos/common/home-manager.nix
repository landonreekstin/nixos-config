# ~/nixos-config/modules/nixos/common/home-manager.nix
{ ... }:
{
  # Overwrite existing .hm-backup files on each rebuild instead of failing.
  # Without this, HM fails when a backup file already exists from a previous run.
  home-manager.overwriteBackup = true;
}
