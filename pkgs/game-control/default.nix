# ~/nixos-config/pkgs/game-control/default.nix
# The game-control dashboard's source (app.py + templates/), from its own repo.
# modules/nixos/homelab/game-control.nix runs it with uvicorn from this path.
# To update: bump `rev` and `hash` — see docs/companion-repos.md#game-control.
{ fetchFromGitHub }:

fetchFromGitHub {
  owner = "landonreekstin";
  repo = "game-control";
  rev = "e0d4f32bc2a256821f63e56e15d9ae5777ae6a9d";
  hash = "sha256-6KMoWV2J9g+0JRn+0zNwIeXqV02Qd428QvFyoW2FPL4=";
}
