# ~/nixos-config/modules/nixos/homelab/flake-updater.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.flakeUpdater;
  gitEmail = config.customConfig.user.email;

  # Beta host is built first; PR opens immediately after so the soak starts ASAP.
  # Remaining hosts are built after with a per-host timeout.
  betaHost = cfg.betaHost;
  remainingHostsStr = lib.strings.concatStringsSep " "
    (lib.filter (h: h != betaHost) cfg.allHosts);
  buildTimeoutSec = toString (cfg.buildTimeoutMinutes * 60);

  updaterScript = pkgs.writeShellScript "flake-updater" ''
    set -euo pipefail

    log() { echo "[flake-updater] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

    WEEK=$(date +%Y-W%V)
    BRANCH="update/''${WEEK}"
    REPO="${cfg.repoOwner}/${cfg.repoName}"
    BLOCK_LABEL="${cfg.blockLabel}"
    AUTO_MERGE_DAYS=${toString cfg.autoMergeDays}
    BETA_HOST="${betaHost}"
    REMAINING_HOSTS=(${remainingHostsStr})
    BUILD_TIMEOUT=${buildTimeoutSec}

    export GH_TOKEN=$(cat "${cfg.githubTokenFile}")
    export GIT_SSH_COMMAND="ssh -i /home/${cfg.gitUser}/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new -o BatchMode=yes"

    cd "${cfg.repoDir}"

    # ---------------------------------------------------------------
    # build_host <name>: builds with timeout; sets BUILD_STATUS[name]
    # ---------------------------------------------------------------
    declare -A BUILD_STATUS

    build_host() {
      local host="$1"
      log "Building ''${host}..."
      local logfile="/tmp/flake-updater-build-''${host}.log"
      if timeout "''${BUILD_TIMEOUT}" \
          nix build ".#nixosConfigurations.''${host}.config.system.build.toplevel" \
          --no-link --max-jobs auto --cores 0 \
          > "''${logfile}" 2>&1; then
        BUILD_STATUS["''${host}"]="PASS"
        log "✓ ''${host}: PASS"
      else
        local ec=$?
        if [ "''${ec}" -eq 124 ]; then
          BUILD_STATUS["''${host}"]="TIMEOUT"
          log "⏱ ''${host}: TIMEOUT (exceeded ${toString cfg.buildTimeoutMinutes}min)"
        else
          BUILD_STATUS["''${host}"]="FAIL"
          log "✗ ''${host}: FAIL"
          tail -5 "''${logfile}" | sed 's/^/    /' >&2
        fi
      fi
    }

    # ---------------------------------------------------------------
    # pr_body: generate markdown table from BUILD_STATUS
    # ---------------------------------------------------------------
    pr_body() {
      local all_hosts=("''${BETA_HOST}" "''${REMAINING_HOSTS[@]}")
      local rows=""
      for host in "''${all_hosts[@]}"; do
        local status="''${BUILD_STATUS["''${host}"]:-⏳ pending}"
        case "''${status}" in
          PASS)    rows="''${rows}"$'\n'"| ''${host} | ✓ PASS |" ;;
          FAIL)    rows="''${rows}"$'\n'"| ''${host} | ✗ FAIL |" ;;
          TIMEOUT) rows="''${rows}"$'\n'"| ''${host} | ⏱ TIMEOUT |" ;;
          *)       rows="''${rows}"$'\n'"| ''${host} | ⏳ pending |" ;;
        esac
      done

      cat <<BODY
## Weekly Flake Update — ''${WEEK}

### Build Results

| Host | Status |
|------|--------|''${rows}

### Beta Rollout

**''${BETA_HOST}** tracks this branch immediately as the beta host and will receive the update on its next \`sync\`. All other hosts remain on \`main\` until this PR merges.

### Auto-merge

This PR auto-merges in **''${AUTO_MERGE_DAYS} days** unless the \`''${BLOCK_LABEL}\` label is applied.

**To block:** add the \`''${BLOCK_LABEL}\` label to this PR.
**To unblock:** push a fix to the branch, then remove the label.
**To roll back on ''${BETA_HOST}:** \`git checkout main && rebuild\`
BODY
    }

    # ---------------------------------------------------------------
    # Step 1: Auto-merge any eligible open flake-update PRs
    # Runs every invocation — fixes the old "Path A" bug where only
    # the current week's branch was checked, causing PRs to pile up.
    # ---------------------------------------------------------------
    OPEN_PRS=$(${pkgs.gh}/bin/gh pr list \
      --repo "''${REPO}" \
      --label "flake-update" \
      --state open \
      --json number \
      --jq '.[].number' 2>/dev/null || true)

    for PR_NUM in ''${OPEN_PRS}; do
      LABELS=$(${pkgs.gh}/bin/gh pr view "''${PR_NUM}" \
        --repo "''${REPO}" \
        --json labels -q '[.labels[].name] | join(",")')

      if echo "''${LABELS}" | grep -qF "''${BLOCK_LABEL}"; then
        log "PR #''${PR_NUM} has block label '${cfg.blockLabel}' — skipping auto-merge"
        continue
      fi

      CREATED=$(${pkgs.gh}/bin/gh pr view "''${PR_NUM}" \
        --repo "''${REPO}" \
        --json createdAt -q '.createdAt')
      AGE=$(( ($(date +%s) - $(date -d "''${CREATED}" +%s)) / 86400 ))
      log "PR #''${PR_NUM} is ''${AGE} days old (threshold: ''${AUTO_MERGE_DAYS})"

      if [ "''${AGE}" -ge "''${AUTO_MERGE_DAYS}" ]; then
        log "Auto-merging PR #''${PR_NUM}"
        ${pkgs.gh}/bin/gh pr merge "''${PR_NUM}" --repo "''${REPO}" --merge --delete-branch
        log "PR #''${PR_NUM} merged"
      else
        log "Not old enough yet (''${AGE}/''${AUTO_MERGE_DAYS} days) — skipping"
      fi
    done

    # ---------------------------------------------------------------
    # Step 2: If this week's branch already exists, nothing left to do
    # ---------------------------------------------------------------
    if git ls-remote --exit-code origin "refs/heads/''${BRANCH}" > /dev/null 2>&1; then
      log "Branch ''${BRANCH} already on remote — no new update needed"
      exit 0
    fi

    # ---------------------------------------------------------------
    # Step 3: New week → update flake, build, open PR, build rest
    # ---------------------------------------------------------------
    log "Starting weekly flake update for ''${BRANCH}"

    git fetch origin

    # Use -B to reset branch if it exists locally from a previous failed run
    git -c user.name="${cfg.gitUser}" -c user.email="${gitEmail}" \
      checkout -B "''${BRANCH}" origin/main

    log "Running nix flake update..."
    nix flake update
    log "Flake update complete"

    git -c user.name="${cfg.gitUser}" -c user.email="${gitEmail}" \
      add flake.lock
    git -c user.name="${cfg.gitUser}" -c user.email="${gitEmail}" \
      commit -m "chore(flake): weekly update ''${WEEK}"

    # Step 1: Build beta host first
    build_host "''${BETA_HOST}"

    # Step 2: Push branch and open PR immediately so beta soak starts
    git push origin "''${BRANCH}"

    ${pkgs.gh}/bin/gh label create "flake-update" \
      --repo "''${REPO}" \
      --color "0075ca" \
      --description "Automated weekly flake update" 2>/dev/null || true

    ${pkgs.gh}/bin/gh pr create \
      --repo "''${REPO}" \
      --title "chore(flake): weekly update ''${WEEK}" \
      --body "$(pr_body)" \
      --label "flake-update" \
      --base main

    PR_NUM=$(${pkgs.gh}/bin/gh pr list \
      --repo "''${REPO}" \
      --head "''${BRANCH}" \
      --state open \
      --json number -q '.[0].number')

    log "PR #''${PR_NUM} opened — building remaining hosts"

    # Step 3: Build remaining hosts with per-host timeout
    for host in "''${REMAINING_HOSTS[@]}"; do
      build_host "''${host}"
    done

    # Step 4: Update PR body with final results
    ${pkgs.gh}/bin/gh pr edit "''${PR_NUM}" \
      --repo "''${REPO}" \
      --body "$(pr_body)"

    # Step 5: Auto-block if any host FAILED (not just timed out)
    HAS_FAILURE=0
    for host in "''${BETA_HOST}" "''${REMAINING_HOSTS[@]}"; do
      if [ "''${BUILD_STATUS["''${host}"]:-}" = "FAIL" ]; then
        HAS_FAILURE=1
        break
      fi
    done
    if [ "''${HAS_FAILURE}" -eq 1 ]; then
      log "Build failures detected — adding ''${BLOCK_LABEL} to PR #''${PR_NUM}"
      ${pkgs.gh}/bin/gh pr edit "''${PR_NUM}" --repo "''${REPO}" --add-label "''${BLOCK_LABEL}"
      log "PR #''${PR_NUM} blocked; fix the failures and remove the label to allow auto-merge"
    fi

    log "Weekly update complete — PR #''${PR_NUM} updated with full build results"
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
        TimeoutStartSec = "8h";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "flake-updater";
      };
    };

  };
}
