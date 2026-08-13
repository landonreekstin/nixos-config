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

    # Always return to main when the script exits so sync works correctly afterward
    trap 'git checkout main 2>/dev/null || true' EXIT

    # ---------------------------------------------------------------
    # build_host <name>: builds with timeout; sets BUILD_STATUS[name]
    #
    # A failed build is retried once. The overwhelmingly common cause of a
    # one-off FAIL is a transient DNS/network blip on this machine knocking
    # out a single fixed-output derivation (unbound forwards DoT through the
    # Mullvad tunnel, so a relay reconnect briefly kills name resolution) —
    # week 2026-W33 lost gaming-pc and optiplex to exactly that, blocking an
    # otherwise-good update for a week. The retry is near-free: everything
    # that already built is in the store, so only the failed fetch reruns.
    # A TIMEOUT is never retried — that would just double an already-capped run.
    # ---------------------------------------------------------------
    declare -A BUILD_STATUS

    build_host() {
      local host="$1"
      local logfile="/tmp/flake-updater-build-''${host}.log"
      local attempt ec

      for attempt in 1 2; do
        if [ "''${attempt}" -eq 1 ]; then
          log "Building ''${host}..."
        else
          log "Retrying ''${host} (attempt ''${attempt}/2)..."
        fi

        # NOTE: `ec=$?` must stay inside the else branch. A bare `if …; fi` with
        # no else returns 0 when the condition is false, so reading $? after the
        # `fi` would silently capture 0 instead of the build's exit code.
        if timeout "''${BUILD_TIMEOUT}" \
            nix build ".#nixosConfigurations.''${host}.config.system.build.toplevel" \
            --no-link --max-jobs auto --cores 0 \
            > "''${logfile}" 2>&1; then
          BUILD_STATUS["''${host}"]="PASS"
          if [ "''${attempt}" -eq 1 ]; then
            log "✓ ''${host}: PASS"
          else
            log "✓ ''${host}: PASS (on retry)"
          fi
          return
        else
          ec=$?
          if [ "''${ec}" -eq 124 ]; then
            BUILD_STATUS["''${host}"]="TIMEOUT"
            log "⏱ ''${host}: TIMEOUT (exceeded ${toString cfg.buildTimeoutMinutes}min)"
            return
          fi

          if [ "''${attempt}" -eq 1 ]; then
            log "''${host} build failed (exit ''${ec}) — retrying once in 60s (transient DNS/network is the usual cause)"
            tail -5 "''${logfile}" | sed 's/^/    /' >&2
            sleep 60
          fi
        fi
      done

      BUILD_STATUS["''${host}"]="FAIL"
      log "✗ ''${host}: FAIL (failed twice)"
      tail -5 "''${logfile}" | sed 's/^/    /' >&2
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

This PR auto-merges on the **following Monday's run** (~''${AUTO_MERGE_DAYS} days after creation) unless the \`''${BLOCK_LABEL}\` label is applied.

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

    # Probe REST mergeable_state (clean/unstable/blocked/dirty/behind/unknown).
    # GraphQL's `mergeable` field is a known GitHub quirk: it can stay UNKNOWN
    # for weeks on untouched PRs, which previously wedged this loop and let
    # week 29 + 30 pile up behind week 31 (PRs #71, #84, #91 in Jul 2026).
    # A GET on the REST pulls endpoint triggers GitHub's mergeability compute,
    # so an initial UNKNOWN is retried once after a short delay.
    probe_merge_state() {
      local pr="$1"
      ${pkgs.gh}/bin/gh api "repos/''${REPO}/pulls/''${pr}" \
        --jq '.mergeable_state' 2>/dev/null || echo "unknown"
    }

    for PR_NUM in ''${OPEN_PRS}; do
      LABELS=$(${pkgs.gh}/bin/gh pr view "''${PR_NUM}" \
        --repo "''${REPO}" \
        --json labels -q '[.labels[].name] | join(",")')

      if echo "''${LABELS}" | grep -qF "''${BLOCK_LABEL}"; then
        log "PR #''${PR_NUM} has block label '${cfg.blockLabel}' — skipping auto-merge"
        continue
      fi

      MERGE_STATE=$(probe_merge_state "''${PR_NUM}")
      if [ "''${MERGE_STATE}" = "unknown" ]; then
        # First GET wakes GitHub's background computation; give it a moment and retry once.
        sleep 5
        MERGE_STATE=$(probe_merge_state "''${PR_NUM}")
      fi

      case "''${MERGE_STATE}" in
        clean|unstable|blocked|behind)
          # clean    = all checks passing
          # unstable = non-required check failing (our CI is advisory)
          # blocked  = ruleset/protection would block a non-admin; admin PAT may still
          #            succeed via bypass, so we still try and let the merge log the outcome
          # behind   = base branch moved; --merge creates a merge commit anyway
          ;;
        dirty)
          log "PR #''${PR_NUM} has merge conflicts — flagging '${cfg.blockLabel}' and skipping"
          ${pkgs.gh}/bin/gh pr edit "''${PR_NUM}" --repo "''${REPO}" \
            --add-label "''${BLOCK_LABEL}" 2>/dev/null || true
          continue
          ;;
        unknown|*)
          log "PR #''${PR_NUM} mergeability=''${MERGE_STATE} after retry — skipping this run"
          continue
          ;;
      esac

      CREATED=$(${pkgs.gh}/bin/gh pr view "''${PR_NUM}" \
        --repo "''${REPO}" \
        --json createdAt -q '.createdAt')
      AGE=$(( ($(date +%s) - $(date -d "''${CREATED}" +%s)) / 86400 ))
      log "PR #''${PR_NUM} is ''${AGE} days old, mergeable_state=''${MERGE_STATE} (threshold: ''${AUTO_MERGE_DAYS})"

      if [ "''${AGE}" -ge "''${AUTO_MERGE_DAYS}" ]; then
        log "Auto-merging PR #''${PR_NUM}"
        # --admin bypasses the protect-main-merges ruleset (which blocks non-admin
        # contributors like cblaney00 from merging to main). The updater's PAT
        # belongs to the repo admin, so the bypass is legitimate.
        MERGE_ERR=$(${pkgs.gh}/bin/gh pr merge "''${PR_NUM}" --repo "''${REPO}" --merge --admin --delete-branch 2>&1) \
          && log "PR #''${PR_NUM} merged" \
          || log "Auto-merge failed for PR #''${PR_NUM}: ''${MERGE_ERR}"
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
  options.customConfig.homelab.flakeUpdater = with lib; {
    enable = mkEnableOption "weekly automated flake update orchestrator";
    repoDir = mkOption {
      type = types.str;
      default = "/home/lando/nixos-config";
      description = "Absolute path to the nixos-config git repository on this machine.";
    };
    repoOwner = mkOption {
      type = types.str;
      default = "landonreekstin";
      description = "GitHub repository owner (user or org).";
    };
    repoName = mkOption {
      type = types.str;
      default = "nixos-config";
      description = "GitHub repository name.";
    };
    gitUser = mkOption {
      type = types.str;
      default = "lando";
      description = "Local unix user to run git operations as (must have SSH access to GitHub).";
    };
    allHosts = mkOption {
      type = types.listOf types.str;
      default = [ "gaming-pc" "optiplex" "blaney-pc" "justus-pc" "asus-laptop" "asus-m15" "atl-mini-pc" "optiplex-nas" "mini-server" ];
      description = "All host names to build and include in the PR build matrix.";
    };
    blockLabel = mkOption {
      type = types.str;
      default = "update-blocked";
      description = "GitHub PR label that prevents auto-merge.";
    };
    autoMergeDays = mkOption {
      type = types.int;
      default = 6;
      description = ''
        Days after PR creation before auto-merging (if not blocked). Set to 6, not 7,
        because the updater runs Mondays 03:00 UTC but PRs open Mondays 04-09 UTC (after
        the beta-host build finishes), so the next Monday's check sees ~6d20h — integer 6.
        A threshold of 7 would defer the merge another full week for a 13-day soak.
      '';
    };
    betaHost = mkOption {
      type = types.str;
      default = "gaming-pc";
      description = "Host built first; PR is opened immediately after it completes so the beta soak starts ASAP.";
    };
    buildTimeoutMinutes = mkOption {
      type = types.int;
      default = 45;
      description = "Per-host build timeout in minutes. Hosts exceeding this are marked TIMEOUT in the PR table.";
    };
    githubTokenFile = mkOption {
      type = types.path;
      default = "/run/secrets/github-token";
      description = "Path to file containing a GitHub fine-grained PAT with contents:write and pull_requests:write.";
    };
  };

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
        # Headroom for the whole run: 9 hosts, each now able to retry once,
        # with a per-host cap of buildTimeoutMinutes. Must stay comfortably
        # above that product or a slow week gets killed mid-flight.
        TimeoutStartSec = "12h";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "flake-updater";
      };
    };

  };
}
