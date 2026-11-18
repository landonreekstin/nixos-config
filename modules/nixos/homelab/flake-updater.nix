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
  ntfyTopicFile = if cfg.ntfyTopicFile == null then "" else toString cfg.ntfyTopicFile;

  # Two modes, one script:
  #   run  (Monday timer) — sync + auto-merge open update PRs, then cut this week's
  #                         branch (carrying forward an unmerged one), build, open the PR.
  #   sync (daily timer)  — merge origin/main into every open update branch, so a
  #                         conflict shows up (and alerts) the day it appears instead of
  #                         silently wedging the Monday merge (2026-W46, PR #307).
  # Env knobs for testing by hand (as the git user):
  #   DRY_RUN=1   log every push / gh write / alert instead of doing it; builds are evals
  #   WEEK=YYYY-WNN  pretend it is that week
  updaterScript = pkgs.writeShellScript "flake-updater" ''
    set -euo pipefail

    MODE="''${1:-run}"
    log() { echo "[flake-updater/''${MODE}] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

    WEEK="''${WEEK:-$(date +%Y-W%V)}"
    BRANCH="update/''${WEEK}"
    REPO="${cfg.repoOwner}/${cfg.repoName}"
    BLOCK_LABEL="${cfg.blockLabel}"
    AUTO_MERGE_DAYS=${toString cfg.autoMergeDays}
    BETA_HOST="${betaHost}"
    REMAINING_HOSTS=(${remainingHostsStr})
    BUILD_TIMEOUT=${buildTimeoutSec}
    DRY_RUN="''${DRY_RUN:-0}"
    NTFY_TOPIC_FILE="${ntfyTopicFile}"
    GH=${pkgs.gh}/bin/gh
    GIT_ID=(-c "user.name=${cfg.gitUser}" -c "user.email=${gitEmail}")
    SYNC_WT="$HOME/.cache/flake-updater-sync"

    export GH_TOKEN=$(cat "${cfg.githubTokenFile}")
    export GIT_SSH_COMMAND="ssh -i /home/${cfg.gitUser}/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new -o BatchMode=yes"

    cd "${cfg.repoDir}"

    # One updater at a time: the Monday run waits for a sync in progress; a sync
    # that finds the Monday run going just skips (the run syncs on its own).
    mkdir -p "$HOME/.cache"
    exec 9>"$HOME/.cache/flake-updater.lock"
    if [ "''${MODE}" = "sync" ]; then
      flock -n 9 || { log "Weekly run in progress — skipping sync"; exit 0; }
    else
      flock 9
    fi

    remove_sync_wt() {
      git worktree remove --force "''${SYNC_WT}" 2>/dev/null || true
      rm -rf "''${SYNC_WT}"
      git worktree prune 2>/dev/null || true
    }

    on_exit() {
      remove_sync_wt
      if [ "''${MODE}" = "run" ]; then
        # Return to main so `update` works correctly afterward
        git checkout -q main 2>/dev/null || true
        if [ "''${DRY_RUN}" = "1" ]; then
          git branch -D "''${BRANCH}" >/dev/null 2>&1 || true
        fi
      fi
    }
    trap on_exit EXIT

    # dry <cmd...>: run it, or under DRY_RUN=1 only log it.
    dry() {
      if [ "''${DRY_RUN}" = "1" ]; then
        log "DRY_RUN: would run: $*"
      else
        "$@"
      fi
    }

    # ---------------------------------------------------------------
    # notify <title> <body> [click-url] [priority]
    # Push alert through ntfy.sh. Never fails the run: a missing topic or a
    # failed push is only logged. Keep the title ASCII (it is an HTTP header).
    # ---------------------------------------------------------------
    notify() {
      local title="$1" body="$2" url="''${3:-}" prio="''${4:-default}"
      if [ -z "''${NTFY_TOPIC_FILE}" ] || [ ! -r "''${NTFY_TOPIC_FILE}" ]; then
        log "ALERT (no ntfy topic configured): ''${title} — ''${body}"
        return 0
      fi
      if [ "''${DRY_RUN}" = "1" ]; then
        log "DRY_RUN: would alert: ''${title} — ''${body}"
        return 0
      fi
      local topic
      topic=$(tr -d '[:space:]' < "''${NTFY_TOPIC_FILE}")
      local args=(-fsS -m 15 -o /dev/null
        -H "Title: ''${title}" -H "Tags: warning" -H "Priority: ''${prio}")
      if [ -n "''${url}" ]; then
        args+=(-H "Click: ''${url}")
      fi
      if curl "''${args[@]}" -d "''${body}" "https://ntfy.sh/''${topic}"; then
        log "Alert sent: ''${title}"
      else
        log "Alert push failed: ''${title}"
      fi
    }

    pr_url() { echo "https://github.com/''${REPO}/pull/$1"; }

    has_block_label() {
      ''${GH} pr view "$1" --repo "''${REPO}" --json labels \
        -q '.labels[].name' 2>/dev/null | grep -xF "''${BLOCK_LABEL}" >/dev/null
    }

    # ---------------------------------------------------------------
    # block_pr <pr> <reason>
    # Adds the block label, explains why on the PR, and pushes an alert — but
    # only when the label is new, so the daily sync can't alert every day about
    # the same stuck PR.
    # ---------------------------------------------------------------
    block_pr() {
      local pr="$1" reason="$2"
      if has_block_label "''${pr}"; then
        log "PR #''${pr} already has '$BLOCK_LABEL' — not re-alerting (''${reason})"
        return 0
      fi
      log "Blocking PR #''${pr}: ''${reason}"
      dry ''${GH} pr edit "''${pr}" --repo "''${REPO}" --add-label "''${BLOCK_LABEL}" >/dev/null || true
      dry ''${GH} pr comment "''${pr}" --repo "''${REPO}" --body "**flake-updater added \`''${BLOCK_LABEL}\`:** ''${reason}

Logs: \`journalctl -u flake-updater -u flake-updater-sync\` on optiplex-nas. Fix it on the branch, then remove the label so the next Monday run can merge it." >/dev/null || true
      notify "Update PR #''${pr} blocked" "''${reason}" "$(pr_url "''${pr}")" high
    }

    # ---------------------------------------------------------------
    # merge_main_in <dir>: merge origin/main into the checkout at <dir>.
    # 0 = merged (or nothing to do); 2 = conflicts (merge aborted, files in
    # CONFLICT_FILES). A flake.lock-only conflict is resolved by keeping the
    # update branch's lock and re-locking so any input main added gets locked.
    # ---------------------------------------------------------------
    CONFLICT_FILES=""
    merge_main_in() {
      local dir="$1"
      CONFLICT_FILES=""
      if git -C "''${dir}" "''${GIT_ID[@]}" merge -q --no-edit origin/main >/dev/null 2>&1; then
        return 0
      fi
      CONFLICT_FILES=$(git -C "''${dir}" diff --name-only --diff-filter=U | tr '\n' ' ' | sed 's/ $//')
      if [ "''${CONFLICT_FILES}" = "flake.lock" ]; then
        git -C "''${dir}" checkout -q --ours flake.lock
        (cd "''${dir}" && nix flake lock 2>&1 | tail -3)
        git -C "''${dir}" add flake.lock
        git -C "''${dir}" "''${GIT_ID[@]}" commit -q --no-edit
        log "flake.lock-only conflict resolved (kept the update's lock, re-locked)"
        return 0
      fi
      git -C "''${dir}" merge --abort 2>/dev/null || true
      CONFLICT_FILES="''${CONFLICT_FILES:-<merge failed without conflict markers>}"
      return 2
    }

    # ---------------------------------------------------------------
    # eval_all <dir>: evaluate every nixosConfiguration (vm-* and installer
    # included — the same set CI checks). Failing hosts go in EVAL_FAILED.
    # ---------------------------------------------------------------
    EVAL_FAILED=""
    eval_all() {
      local dir="$1" hosts h
      EVAL_FAILED=""
      hosts=$(nix eval --impure --raw "''${dir}#nixosConfigurations" \
        --apply 'c: builtins.concatStringsSep " " (builtins.attrNames c)' 2>/dev/null) || {
        EVAL_FAILED="<flake>"; return 1; }
      for h in ''${hosts}; do
        if ! nix eval --impure "''${dir}#nixosConfigurations.''${h}.config.system.build.toplevel.drvPath" \
            > "/tmp/flake-updater-eval-''${h}.log" 2>&1; then
          EVAL_FAILED="''${EVAL_FAILED:+''${EVAL_FAILED} }''${h}"
        fi
      done
      [ -z "''${EVAL_FAILED}" ]
    }

    # ---------------------------------------------------------------
    # sync_branch <branch> <pr>: bring origin/main into an open update branch,
    # in a throwaway worktree so the repo checkout is never moved.
    # 0 = branch contains main (now or already); 1 = blocked.
    # ---------------------------------------------------------------
    sync_branch() {
      local br="$1" pr="$2"
      if ! git rev-parse -q --verify "origin/''${br}" >/dev/null; then
        log "origin/''${br} not found — skipping sync"
        return 1
      fi
      if git merge-base --is-ancestor origin/main "origin/''${br}"; then
        log "''${br} already contains main"
        return 0
      fi
      log "Merging main into ''${br}..."
      remove_sync_wt
      git worktree add -q --detach "''${SYNC_WT}" "origin/''${br}"
      local rc=0
      merge_main_in "''${SYNC_WT}" || rc=$?
      if [ "''${rc}" -ne 0 ]; then
        remove_sync_wt
        block_pr "''${pr}" "Merging main into ''${br} conflicts in: ''${CONFLICT_FILES}. Merge origin/main into the branch by hand and push."
        return 1
      fi
      if ! eval_all "''${SYNC_WT}"; then
        remove_sync_wt
        block_pr "''${pr}" "With main merged in, ''${br} fails to evaluate: ''${EVAL_FAILED} (see /tmp/flake-updater-eval-<host>.log). The merge was not pushed."
        return 1
      fi
      dry git -C "''${SYNC_WT}" push -q origin "HEAD:refs/heads/''${br}"
      log "Merged main into ''${br} and pushed"
      remove_sync_wt
      return 0
    }

    # "<number> <branch>" per open flake-update PR, oldest week first.
    list_open_prs() {
      ''${GH} pr list --repo "''${REPO}" --label "flake-update" --state open \
        --json number,headRefName --jq '.[] | "\(.number) \(.headRefName)"' 2>/dev/null \
        | sort -k2 -V || true
    }

    git fetch -q origin

    # ===============================================================
    # sync mode: keep every open update branch merged with main, then stop.
    # ===============================================================
    if [ "''${MODE}" = "sync" ]; then
      while read -r num br <&3; do
        [ -n "''${num}" ] || continue
        sync_branch "''${br}" "''${num}" || true
      done 3<<< "$(list_open_prs)"
      log "Sync complete"
      exit 0
    fi

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
    #
    # NIX_DL_OPTS is what makes that retry reachable. The global nix settings
    # (common/nix-settings.nix) are tuned so a dead LAN cache never blocks a
    # desktop rebuild: download-attempts=1, stalled-download-timeout=20 and
    # fallback=true. Behind the Mullvad tunnel that combination turned one
    # stalled NAR into a 3h TIMEOUT: nix disables cache.nixos.org for the rest
    # of the invocation after a single failed download, and fallback then
    # compiles everything still missing (qtbase, ffmpeg-full, firefox, …) here.
    # 2026-W42 and W43 lost gaming-pc and optiplex that way. So the updater
    # retries downloads, waits out short stalls, and with fallback off a dead
    # substituter is a fast FAIL — the retry then starts a fresh nix process
    # with the cache re-enabled and only fetches what is still missing.
    # ---------------------------------------------------------------
    NIX_DL_OPTS=(
      --option fallback false
      --option download-attempts 5
      --option stalled-download-timeout 90
    )

    declare -A BUILD_STATUS

    build_host() {
      local host="$1"
      local logfile="/tmp/flake-updater-build-''${host}.log"
      local attempt ec

      if [ "''${DRY_RUN}" = "1" ]; then
        log "DRY_RUN: evaluating ''${host} instead of building"
        if nix eval --impure ".#nixosConfigurations.''${host}.config.system.build.toplevel.drvPath" \
            > "''${logfile}" 2>&1; then
          BUILD_STATUS["''${host}"]="PASS"
        else
          BUILD_STATUS["''${host}"]="FAIL"
        fi
        log "''${host}: ''${BUILD_STATUS["''${host}"]} (eval only)"
        return
      fi

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
            --no-link --max-jobs auto --cores 0 "''${NIX_DL_OPTS[@]}" \
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
            # The retry overwrites the log; keep the first attempt's evidence.
            cp "''${logfile}" "''${logfile%.log}.attempt1.log"
            sleep 60
          fi
        fi
      done

      BUILD_STATUS["''${host}"]="FAIL"
      log "✗ ''${host}: FAIL (failed twice)"
      tail -5 "''${logfile}" | sed 's/^/    /' >&2
    }

    # Set in Step 3; shown in the PR body.
    CARRIED_FROM=""
    NOT_CARRIED=""
    NOT_CARRIED_LOG=""

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

      local carry=""
      if [ -n "''${CARRIED_FROM}" ]; then
        carry=$'\n'"### Carried forward"$'\n\n'"Cut from \`''${CARRIED_FROM}\`, which never merged, so its fixes and features stay on the beta host. That PR is closed as superseded."$'\n'
      elif [ -n "''${NOT_CARRIED}" ]; then
        carry=$'\n'"### ⚠ Not carried forward from \`''${NOT_CARRIED}\`"$'\n\n'"That branch never merged and conflicts with main, so this week was cut from main instead. These commits are only on \`''${NOT_CARRIED}\` — port what is still needed by hand:"$'\n\n```\n'"''${NOT_CARRIED_LOG}"$'\n```\n'
      fi

      cat <<BODY
## Weekly Flake Update — ''${WEEK}

### Build Results

| Host | Status |
|------|--------|''${rows}
''${carry}
### Beta Rollout

**''${BETA_HOST}** tracks this branch immediately as the beta host and will receive the update on its next \`update\`. All other hosts remain on \`main\` until this PR merges.

### Auto-merge

This PR auto-merges on the **following Monday's run** (~''${AUTO_MERGE_DAYS} days after creation) unless the \`''${BLOCK_LABEL}\` label is applied. \`main\` is merged into this branch daily; a conflict or eval failure blocks it and sends an alert.

**To block:** add the \`''${BLOCK_LABEL}\` label to this PR.
**To unblock:** push a fix to the branch, then remove the label.
**To roll back on ''${BETA_HOST}:** \`git checkout main && rebuild\`
BODY
    }

    # ---------------------------------------------------------------
    # Step 1: Sync, then auto-merge any eligible open flake-update PRs
    # Runs every invocation — fixes the old "Path A" bug where only
    # the current week's branch was checked, causing PRs to pile up.
    # ---------------------------------------------------------------
    # Probe REST mergeable_state (clean/unstable/blocked/dirty/behind/unknown).
    # GraphQL's `mergeable` field is a known GitHub quirk: it can stay UNKNOWN
    # for weeks on untouched PRs, which previously wedged this loop and let
    # week 29 + 30 pile up behind week 31 (PRs #71, #84, #91 in Jul 2026).
    # A GET on the REST pulls endpoint triggers GitHub's mergeability compute,
    # so an initial UNKNOWN is retried once after a short delay.
    probe_merge_state() {
      local pr="$1"
      ''${GH} api "repos/''${REPO}/pulls/''${pr}" \
        --jq '.mergeable_state' 2>/dev/null || echo "unknown"
    }

    while read -r PR_NUM PR_BRANCH <&3; do
      [ -n "''${PR_NUM}" ] || continue

      # Merge main in first: most "dirty" PRs are just behind a change on main.
      sync_branch "''${PR_BRANCH}" "''${PR_NUM}" || true

      if has_block_label "''${PR_NUM}"; then
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
          block_pr "''${PR_NUM}" "GitHub reports merge conflicts with main, so it could not auto-merge."
          continue
          ;;
        unknown|*)
          log "PR #''${PR_NUM} mergeability=''${MERGE_STATE} after retry — skipping this run"
          continue
          ;;
      esac

      CREATED=$(''${GH} pr view "''${PR_NUM}" \
        --repo "''${REPO}" \
        --json createdAt -q '.createdAt')
      AGE=$(( ($(date +%s) - $(date -d "''${CREATED}" +%s)) / 86400 ))
      log "PR #''${PR_NUM} is ''${AGE} days old, mergeable_state=''${MERGE_STATE} (threshold: ''${AUTO_MERGE_DAYS})"

      if [ "''${AGE}" -ge "''${AUTO_MERGE_DAYS}" ]; then
        log "Auto-merging PR #''${PR_NUM}"
        # --admin bypasses the protect-main-merges ruleset (which blocks non-admin
        # contributors like cblaney00 from merging to main). The updater's PAT
        # belongs to the repo admin, so the bypass is legitimate.
        if MERGE_ERR=$(dry ''${GH} pr merge "''${PR_NUM}" --repo "''${REPO}" --merge --admin --delete-branch 2>&1); then
          log "PR #''${PR_NUM} merged"
        else
          log "Auto-merge failed for PR #''${PR_NUM}: ''${MERGE_ERR}"
          notify "Update PR #''${PR_NUM} failed to merge" "''${MERGE_ERR}" "$(pr_url "''${PR_NUM}")" high
        fi
      else
        log "Not old enough yet (''${AGE}/''${AUTO_MERGE_DAYS} days) — skipping"
      fi
    done 3<<< "$(list_open_prs)"

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

    git fetch -q origin

    # Carry forward: a PR still open here never merged (blocked or conflicting).
    # Cutting the new week from main would silently drop its fixes and any
    # beta-host features riding on it (2026-W46 → W47), so cut from it instead.
    STILL_OPEN=$(list_open_prs)
    PREV_BRANCH=$(echo "''${STILL_OPEN}" | awk 'NF {print $2}' | sort -V | tail -1)

    # Use -B to reset branch if it exists locally from a previous failed run
    if [ -n "''${PREV_BRANCH}" ] && git rev-parse -q --verify "origin/''${PREV_BRANCH}" >/dev/null; then
      git "''${GIT_ID[@]}" checkout -q -B "''${BRANCH}" "origin/''${PREV_BRANCH}"
      if merge_main_in "$PWD"; then
        CARRIED_FROM="''${PREV_BRANCH}"
        log "Carrying forward unmerged ''${PREV_BRANCH} (main merged in)"
      else
        NOT_CARRIED="''${PREV_BRANCH}"
        NOT_CARRIED_LOG=$(git log --oneline --no-merges "origin/main..origin/''${PREV_BRANCH}" \
          | grep -v 'chore(flake): weekly update' || true)
        log "''${PREV_BRANCH} conflicts with main (''${CONFLICT_FILES}) — cutting from main instead"
        git "''${GIT_ID[@]}" checkout -q -B "''${BRANCH}" origin/main
      fi
    else
      git "''${GIT_ID[@]}" checkout -q -B "''${BRANCH}" origin/main
    fi

    log "Running nix flake update..."
    nix flake update
    log "Flake update complete"

    git "''${GIT_ID[@]}" add flake.lock
    git "''${GIT_ID[@]}" commit -q -m "chore(flake): weekly update ''${WEEK}"

    # Step 1: Build beta host first
    build_host "''${BETA_HOST}"

    # Step 2: Push branch and open PR immediately so beta soak starts
    dry git push -q origin "''${BRANCH}"

    dry ''${GH} label create "flake-update" \
      --repo "''${REPO}" \
      --color "0075ca" \
      --description "Automated weekly flake update" 2>/dev/null || true

    dry ''${GH} pr create \
      --repo "''${REPO}" \
      --title "chore(flake): weekly update ''${WEEK}" \
      --body "$(pr_body)" \
      --label "flake-update" \
      --base main

    if [ "''${DRY_RUN}" = "1" ]; then
      PR_NUM="DRY"
    else
      PR_NUM=$(''${GH} pr list \
        --repo "''${REPO}" \
        --head "''${BRANCH}" \
        --state open \
        --json number -q '.[0].number')
    fi

    log "PR #''${PR_NUM} opened — building remaining hosts"

    # Close the PRs this week now contains. One that was not carried forward
    # stays open: its commits are not in this branch.
    while read -r OLD_NUM OLD_BRANCH <&3; do
      [ -n "''${OLD_NUM}" ] || continue
      [ "''${OLD_BRANCH}" != "''${BRANCH}" ] || continue
      if git merge-base --is-ancestor "origin/''${OLD_BRANCH}" HEAD; then
        log "Closing PR #''${OLD_NUM} (''${OLD_BRANCH}) as superseded by #''${PR_NUM}"
        dry ''${GH} pr comment "''${OLD_NUM}" --repo "''${REPO}" \
          --body "Superseded by #''${PR_NUM}: \`''${BRANCH}\` was cut from this branch, so all of its commits carry forward." >/dev/null || true
        dry ''${GH} pr close "''${OLD_NUM}" --repo "''${REPO}" --delete-branch >/dev/null || true
      fi
    done 3<<< "''${STILL_OPEN}"

    if [ -n "''${NOT_CARRIED}" ]; then
      notify "''${NOT_CARRIED} not carried forward" \
        "It conflicts with main, so ''${BRANCH} was cut from main. Its commits are listed in the new PR; port them by hand." \
        "$(pr_url "''${PR_NUM}")" high
    fi

    # Step 3: Build remaining hosts with per-host timeout
    for host in "''${REMAINING_HOSTS[@]}"; do
      build_host "''${host}"
    done

    # Step 4: Update PR body with final results
    dry ''${GH} pr edit "''${PR_NUM}" \
      --repo "''${REPO}" \
      --body "$(pr_body)" >/dev/null

    # Step 5: Auto-block if any host FAILED (not just timed out)
    FAILED_HOSTS=""
    for host in "''${BETA_HOST}" "''${REMAINING_HOSTS[@]}"; do
      if [ "''${BUILD_STATUS["''${host}"]:-}" = "FAIL" ]; then
        FAILED_HOSTS="''${FAILED_HOSTS:+''${FAILED_HOSTS} }''${host}"
      fi
    done
    if [ -n "''${FAILED_HOSTS}" ]; then
      block_pr "''${PR_NUM}" "''${WEEK} failed to build: ''${FAILED_HOSTS} (logs: /tmp/flake-updater-build-<host>.log on optiplex-nas)."
    fi

    log "Weekly update complete — PR #''${PR_NUM} updated with full build results"
  '';

  # OnFailure= target for both units: a crash of the script itself (as opposed
  # to a blocked PR, which the script reports) still reaches the phone.
  crashAlert = pkgs.writeShellScript "flake-updater-alert" ''
    unit="''${1:-flake-updater}"
    topic_file="${ntfyTopicFile}"
    [ -n "$topic_file" ] && [ -r "$topic_file" ] || exit 0
    ${pkgs.curl}/bin/curl -fsS -m 15 -o /dev/null \
      -H "Title: $unit crashed on optiplex-nas" -H "Tags: rotating_light" -H "Priority: high" \
      -d "journalctl -u $unit -b on optiplex-nas for the error." \
      "https://ntfy.sh/$(tr -d '[:space:]' < "$topic_file")"
  '';

  serviceCommon = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # A rebuild of this host mid-run must not kill a multi-hour update run.
    restartIfChanged = false;
    path = with pkgs; [ nix git openssh gnutar gzip coreutils gnugrep gnused gawk curl util-linux ];
    environment = {
      NIXPKGS_ALLOW_UNFREE = "1";
      HOME = "/home/${cfg.gitUser}";
      NIX_REMOTE = "";
    };
  };

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
    syncSchedule = mkOption {
      type = types.str;
      default = "*-*-* 15:00:00";
      description = ''
        systemd OnCalendar for the daily sync that merges main into every open update
        branch (eval-checked before pushing), so conflicts surface the day they appear.
      '';
    };
    ntfyTopicFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File holding a secret ntfy.sh topic name. When set, a blocked PR, a failed
        auto-merge, a week that could not be carried forward, or a crash of either unit
        is pushed to https://ntfy.sh/<topic> (subscribe in the ntfy app). When null,
        those alerts are only logged.
      '';
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

    systemd.services.flake-updater = serviceCommon // {
      description = "Weekly NixOS flake update orchestrator";
      unitConfig.OnFailure = [ "flake-updater-alert@flake-updater.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.gitUser;
        Group = "users";
        ExecStart = "${updaterScript} run";
        # Headroom for the whole run: 9 hosts, each now able to retry once,
        # with a per-host cap of buildTimeoutMinutes. Must stay comfortably
        # above that product or a slow week gets killed mid-flight.
        TimeoutStartSec = "12h";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "flake-updater";
      };
    };

    systemd.timers.flake-updater-sync = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.syncSchedule;
        Persistent = true;
        RandomizedDelaySec = "15min";
      };
    };

    systemd.services.flake-updater-sync = serviceCommon // {
      description = "Merge main into open flake-update branches";
      unitConfig.OnFailure = [ "flake-updater-alert@flake-updater-sync.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.gitUser;
        Group = "users";
        ExecStart = "${updaterScript} sync";
        TimeoutStartSec = "2h";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "flake-updater-sync";
      };
    };

    systemd.services."flake-updater-alert@" = {
      description = "Push an alert that %i failed";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.gitUser;
        ExecStart = "${crashAlert} %i";
      };
    };

  };
}
