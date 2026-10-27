# ~/nixos-config/pkgs/game-control/default.nix
# The game-control dashboard's source (app.py + templates/), from its own repo.
# modules/nixos/homelab/game-control.nix runs it with uvicorn from this path.
# To update: bump `rev` and `hash` — see docs/companion-repos.md#game-control.
{ fetchFromGitHub }:

fetchFromGitHub {
  owner = "landonreekstin";
  repo = "game-control";
  rev = "687f3641968aad4ccca4f13cafcdcdc92533542f";
  hash = "sha256-Mf03hUo81VoLSUGjCuPhz/PSZMZ+aafB5+caG/tVR3U=";
}
