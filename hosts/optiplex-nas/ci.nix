# ~/nixos-config/hosts/optiplex-nas/ci.nix
{ config, pkgs, lib, ... }:

{
  # === Self-hosted GitHub Actions runner (CI `build` job) ===
  # Realizes the fragile host toplevels (aerothemeplasma's ~13 C++ derivations, the
  # openrazer out-of-tree module) on every PR so source-build regressions fail CI instead
  # of a user's rebuild. This host is chosen because its Nix store is warm from the nightly
  # flake-updater, making incremental builds cheap. The runner uses an outbound long-poll,
  # so it needs no inbound firewall port.
  #
  # SETUP (before merging to main — cross-machine verify per CLAUDE.md): add
  # `github-runner-token` to secrets/optiplex-nas.yaml (a GitHub PAT with repo
  # Administration read/write, needed to register a self-hosted runner), rebuild on this
  # host, and confirm the runner appears as "idle" under repo → Settings → Actions →
  # Runners. Until the secret exists this service fails activation, so it must be verified
  # here before the PR is merged.
  sops.secrets."github-runner-token" = {
    # Sourced from defaultSopsFile (secrets/optiplex-nas.yaml); root-owned by default —
    # the github-runner setup reads it as root during pre-start.
  };

  services.github-runners.nixos-config-ci = {
    enable = true;
    url = "https://github.com/landonreekstin/nixos-config";
    tokenFile = config.sops.secrets."github-runner-token".path;
    name = "optiplex-nas";
    extraLabels = [ "nixos" ]; # "self-hosted" + arch labels are added automatically
    replace = true;
    # Job steps call `nix build` and actions/checkout (git) — put them on the runner PATH.
    extraPackages = [ pkgs.nix pkgs.git ];
  };

  # Self-heal: if the runner (or a job it spawns) is ever OOM-killed, the unit lands in
  # `failed` and stays offline until manually restarted. Auto-restart so a memory spike
  # can't silently take CI's only runner offline. (Applies on the next NAS rebuild.)
  systemd.services.github-runner-nixos-config-ci.serviceConfig = {
    Restart = lib.mkForce "always";
    RestartSec = 30;
  };
}
