# ~/nixos-config/modules/nixos/profiles/default.nix
# This file serves as the import point for profile modules.
# Each profile declares its own customConfig.profiles.* options, so there is no
# options.nix here. Development profiles live in ../development/, which is
# imported separately by modules/nixos/default.nix.
# Other profiles like 'server' could be added here later.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./gaming.nix
    ./htpc.nix
  ];
}