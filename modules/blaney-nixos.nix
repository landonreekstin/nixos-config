# ~/nixos-config/modules/blaney-nixos.nix
# insideabush's own NixOS modules (blaney-pc, vm-blaney): the ones only his hosts use, kept
# out of the shared module library. His hosts import this next to the library's
# modules/nixos/default.nix. These files are on their way to his own repo
# (docs/runbooks/lando/02-split-blaney-repo.md), so they reach library files only through
# `inputs.self`, never by a relative path out of this set.
{ ... }:

{
  imports = [
    ./nixos/blaney-hm-options.nix
    ./nixos/common/blaney-commands.nix
    ./nixos/programs/vibe-projects.nix
    ./nixos/programs/vibenote.nix
    ./nixos/programs/keyripple.nix
    ./nixos/services/remote-admin.nix
    ./nixos/services/net-watch.nix
  ];

  # His home-manager modules, loaded for every managed user next to the library's.
  home-manager.sharedModules = [ ./blaney-home.nix ];
}
