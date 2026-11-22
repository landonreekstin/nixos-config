# ~/nixos-config/modules/blaney-home.nix
# insideabush's own home-manager modules, loaded by ./blaney-nixos.nix through
# home-manager.sharedModules. Their options are declared on the NixOS side, in
# ./nixos/blaney-hm-options.nix (home-manager modules here get customConfig as a plain
# attrset and cannot declare options).
{ ... }:

{
  imports = [
    ./home-manager/development/vibe-projects.nix
    ./home-manager/services/rebuild-shutdown-notify.nix
    ./home-manager/services/shutdown-guard.nix
    ./home-manager/services/release-notes.nix
  ];
}
