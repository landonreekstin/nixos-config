# ~/nixos-config/modules/nixos/homelab/flake-updater.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.flakeUpdater;
  gitEmail = config.customConfig.user.email;

  hostsStr = lib.strings.concatStringsSep " " cfg.allHosts;

  updaterScript = pkgs.writeShellScript "flake-updater" ''
    set -euo pipefail

    log() { echo "[flake-updater] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

    WEEK=$(date +%Y-W%V)
    BRANCH="update/''${WEEK}"
    REPO="${cfg.repoOwner}/${cfg.repoName}"
    BLOCK_LABEL="${cfg.blockLabel}"
    AUTO_MERGE_DAYS=${toString cfg.autoMergeDays}
    HOSTS=(${hostsStr})

    export GH_TOKEN=$(cat "${cfg.githubTokenFile}")
    export GIT_SSH_COMMAND="ssh -i /home/${cfg.gitUser}/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new -o BatchMode=yes"

    cd "${cfg.repoDir}"

    # ---------------------------------------------------------------
    # Path A: Branch already exists → auto-merge check
    # ---------------------------------------------------------------
    if git ls-remote --exit-code origin "refs/heads/''${BRANCH}" > /dev/null 2>&1; then
      log "Branch ''${BRANCH} already exists — running auto-merge check"

      PR_NUM=$(${pkgs.gh}/bin/gh pr list \
        --repo "''${REPO}" \
        --head "''${BRANCH}" \
        --state open \
        --json number -q '.[0].number // empty')

      if [ -z "''${PR_NUM}" ]; then
        log "No open PR for ''${BRANCH} — may already be merged or closed"
        exit 0
      fi

      LABELS=$(${pkgs.gh}/bin/gh pr view "''${PR_NUM}" \
        --repo "''${REPO}" \
        --json labels -q '[.labels[].name] | join(",")')

      if echo "''${LABELS}" | grep -qF "''${BLOCK_LABEL}"; then
        log "PR #''${PR_NUM} has block label '${cfg.blockLabel}' — skipping auto-merge"
        exit 0
      fi

      CREATED=$(${pkgs.gh}/bin/gh pr view "''${PR_NUM}" \
        --repo "''${REPO}" \
        --json createdAt -q '.createdAt')
      AGE=$(( ($(date +%s) - $(date -d "''${CREATED}" +%s)) / 86400 ))
      log "PR #''${PR_NUM} is ''${AGE} days old (threshold: ''${AUTO_MERGE_DAYS})"

      if [ "''${AGE}" -ge "''${AUTO_MERGE_DAYS}" ]; then
        log "Auto-merging PR #''${PR_NUM}"
        ${pkgs.gh}/bin/gh pr merge "''${PR_NUM}" --repo "''${REPO}" --merge --delete-branch
        log "Auto-merge complete"
      else
        log "Not old enough yet (''${AGE}/''${AUTO_MERGE_DAYS} days) — nothing to do"
      fi
      exit 0
    fi

    # ---------------------------------------------------------------
    # Path B: New week → update flake, build all hosts, open PR
    # ---------------------------------------------------------------
    log "Starting weekly flake update for ''${BRANCH}"

    git fetch origin

    git -c user.name="${cfg.gitUser}" -c user.email="${gitEmail}" \
      checkout -b "''${BRANCH}" origin/main

    log "Running nix flake update..."
    nix flake update
    log "Flake update complete"

    git -c user.name="${cfg.gitUser}" -c user.email="${gitEmail}" \
      add flake.lock
    git -c user.name="${cfg.gitUser}" -c user.email="${gitEmail}" \
      commit -m "chore(flake): weekly update ''${WEEK}"

    # ---------------------------------------------------------------
    # Build each host sequentially; collect pass/fail status
    # ---------------------------------------------------------------
    declare -A BUILD_STATUS
    for host in "''${HOSTS[@]}"; do
      log "Building ''${host}..."
      if NIXPKGS_ALLOW_UNFREE=1 nix build \
          ".#nixosConfigurations.''${host}.config.system.build.toplevel" \
          --no-link \
          --max-jobs auto --cores 0 \
          > /tmp/flake-updater-build-''${host}.log 2>&1; then
        BUILD_STATUS["''${host}"]="PASS"
        log "✓ ''${host}: PASS"
      else
        BUILD_STATUS["''${host}"]="FAIL"
        log "✗ ''${host}: FAIL"
        tail -5 /tmp/flake-updater-build-''${host}.log | sed 's/^/    /' >&2
      fi
    done

    git push origin "''${BRANCH}"

    # ---------------------------------------------------------------
    # Generate PR body with build table
    # ---------------------------------------------------------------
    TABLE_ROWS=""
    for host in "''${HOSTS[@]}"; do
      if [ "''${BUILD_STATUS["''${host}"]}" = "PASS" ]; then
        TABLE_ROWS="''${TABLE_ROWS}"$'\n'"| ''${host} | ✓ PASS |"
      else
        TABLE_ROWS="''${TABLE_ROWS}"$'\n'"| ''${host} | ✗ FAIL |"
      fi
    done

    PR_BODY="## Weekly Flake Update — ''${WEEK}

### Build Results

| Host | Status |
|------|--------|''${TABLE_ROWS}

### Beta Rollout

**gaming-pc** tracks this branch immediately as the beta host and will receive the update on its next \`sync\`. All other hosts remain on \`main\` until this PR merges.

### Auto-merge

This PR auto-merges in **''${AUTO_MERGE_DAYS} days** unless the \`''${BLOCK_LABEL}\` label is applied.

**To block:** add the \`''${BLOCK_LABEL}\` label to this PR.
**To unblock:** push a fix to the branch, then remove the label.
**To roll back on gaming-pc:** \`git checkout main && rebuild\`"

    # Ensure the flake-update label exists (no-op if already present)
    ${pkgs.gh}/bin/gh label create "flake-update" \
      --repo "''${REPO}" \
      --color "0075ca" \
      --description "Automated weekly flake update" 2>/dev/null || true

    ${pkgs.gh}/bin/gh pr create \
      --repo "''${REPO}" \
      --title "chore(flake): weekly update ''${WEEK}" \
      --body "''${PR_BODY}" \
      --label "flake-update" \
      --base main

    log "Weekly update complete — PR opened for ''${BRANCH}"
  '';

in
{
  config = lib.mkIf cfg.enable {

    environment.systemPackages = [ pkgs.gh ];

    sops.secrets."github-token" = {
      sopsFile = ../../../secrets/common.yaml;
      owner = cfg.gitUser;
    };

    systemd.timers.flake-updater = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Mon *-*-* 03:00:00";
        Persistent = true;
        RandomizedDelaySec = "30min";
      };
    };

    systemd.services.flake-updater = {
      description = "Weekly NixOS flake update orchestrator";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = with pkgs; [ nix git openssh gnutar gzip coreutils gnugrep gnused ];
      environment = {
        NIXPKGS_ALLOW_UNFREE = "1";
        HOME = "/home/${cfg.gitUser}";
        NIX_REMOTE = "";
      };
      serviceConfig = {
        Type = "oneshot";
        User = cfg.gitUser;
        Group = "users";
        ExecStart = updaterScript;
        TimeoutStartSec = "4h";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "flake-updater";
      };
    };

  };
}
