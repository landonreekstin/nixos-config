# ~/nixos-config/modules/nixos/programs/claude-code.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig;

  # Everything below is derived from the host's primary user — this module is enabled
  # on hosts owned by lando *and* by insideabush (blaney-pc), and both run Claude via
  # `sudo claude`, so root's settings.json is the one that actually applies.
  userName = cfg.user.name;
  userGroup = config.users.users.${userName}.group;

  # The config clone is universal; hosts add their own extra working clones via
  # customConfig.programs.claudeCode.extraChownPaths.
  chownDirs = [ "${cfg.user.home}/nixos-config" ] ++ cfg.programs.claudeCode.extraChownPaths;
  chownCmd = "sudo chown -R ${userName}:${userGroup} ${lib.concatStringsSep " " chownDirs} 2>/dev/null || true";

  rcCfg = cfg.programs.claudeCode.remoteControl;

  claudeState = pkgs.writeShellApplication {
    name = "claude-state";
    runtimeInputs = with pkgs; [ kitty jq procps coreutils util-linux ];
    text = ''
      mode="''${1:-reset}"
      case "$mode" in
        notification)
          payload="$(cat 2>/dev/null || echo '{}')"
          msg="$(echo "$payload" | jq -r '.message // .notification.message // ""' 2>/dev/null || echo "")"
          shopt -s nocasematch
          if [[ "$msg" == *permission* || "$msg" == *approv* || "$msg" == *"needs your"* ]]; then
            color="red"
          else
            color="green"
          fi
          shopt -u nocasematch
          ;;
        red|green|reset) color="$mode" ;;
        *) echo "unknown mode: $mode" >&2; exit 1 ;;
      esac
      case "$color" in
        red)   tab_bg="#ff3838"; state="notification" ;;
        green) tab_bg="#00ff88"; state="stop" ;;
        reset) tab_bg="none";    state="idle" ;;
      esac

      user_id="$(id -u ${userName} 2>/dev/null || echo 1000)"
      export XDG_RUNTIME_DIR="/run/user/$user_id"

      pid="$PPID"
      kitty_pid=""
      for _ in $(seq 1 20); do
        if [ -z "$pid" ] || [ "$pid" = "1" ] || [ "$pid" = "0" ]; then break; fi
        comm="$(cat /proc/"$pid"/comm 2>/dev/null || true)"
        case "$comm" in
          kitty|.kitty-wrapped) kitty_pid="$pid"; break ;;
        esac
        pid="$(awk '/^PPid:/ {print $2}' /proc/"$pid"/status 2>/dev/null || echo "")"
      done
      if [ -z "$kitty_pid" ]; then exit 0; fi

      addr=""
      if command -v hyprctl >/dev/null 2>&1; then
        sig=""
        shopt -s nullglob
        for entry in "$XDG_RUNTIME_DIR"/hypr/*; do
          name="$(basename "$entry")"
          case "$name" in *.lock) continue ;; esac
          if [ -d "$entry" ]; then sig="$name"; break; fi
        done
        shopt -u nullglob
        if [ -n "$sig" ]; then
          export HYPRLAND_INSTANCE_SIGNATURE="$sig"
          addr="$(hyprctl -j clients 2>/dev/null | jq -r --argjson p "$kitty_pid" '.[] | select(.pid==$p) | .address' 2>/dev/null | head -n1)"
        fi
      fi

      socket_path="/tmp/kitty-$kitty_pid"
      if [ -S "$socket_path" ]; then
        if [ "$tab_bg" = "none" ]; then
          kitty @ --to "unix:$socket_path" set-tab-color >/dev/null 2>&1 || true
        else
          kitty @ --to "unix:$socket_path" set-tab-color active_bg="$tab_bg" inactive_bg="$tab_bg" >/dev/null 2>&1 || true
        fi
      fi

      state_file="/tmp/claude-state.json"
      lock="$state_file.lock"
      (
        flock -x 9
        if [ ! -f "$state_file" ]; then echo '{}' > "$state_file"; fi
        tmp="$(mktemp)"
        if jq --arg pid "$kitty_pid" \
              --arg state "$state" \
              --arg addr "$addr" \
              --arg ts "$(date +%s)" \
              'if $state == "idle" then del(.[$pid])
               else .[$pid] = {state: $state, address: $addr, ts: ($ts|tonumber)} end' \
              "$state_file" > "$tmp" 2>/dev/null; then
          mv "$tmp" "$state_file"
          chmod 644 "$state_file"
        else
          rm -f "$tmp"
        fi
      ) 9>"$lock"

      pkill -RTMIN+16 -u ${userName} waybar >/dev/null 2>&1 || true
    '';
  };

  claudeSettings = builtins.toJSON ({
    model = "opus";
    effortLevel = "high";
    hooks = {
      Stop = [{
        hooks = [
          { type = "command"; command = chownCmd; }
          { type = "command"; command = "claude-state green"; }
        ];
      }];
      PostToolUse = [{
        matcher = "Edit|Write";
        hooks = [
          { type = "command"; command = chownCmd; }
        ];
      }];
      Notification = [{
        hooks = [
          { type = "command"; command = "claude-state notification"; }
        ];
      }];
      UserPromptSubmit = [{
        hooks = [
          { type = "command"; command = "claude-state reset"; }
        ];
      }];
    };
  } // lib.optionalAttrs rcCfg.atStartup {
    # Every interactive session registers itself with Remote Control on launch, so a
    # session started over SSH is reachable from the phone without typing
    # /remote-control first.
    remoteControlAtStartup = true;
  });
in
{
  options.customConfig.programs.claudeCode = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable claude-code with uv (for uvx) and mcp-nixos MCP server.";
    };
    extraChownPaths = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/home/lando/hyprland-keys" ];
      description = ''
        Extra directories the Claude hooks chown back to the primary user after
        edits. The user's nixos-config clone is always included; list additional
        working clones here.
      '';
    };
    remoteControl = {
      atStartup = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Set `remoteControlAtStartup` in the generated settings.json, so every
          interactive Claude session connects to Remote Control on launch. Useful
          for picking up an SSH-started session from the Claude mobile app without
          running /remote-control first.
        '';
      };
      server = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Run `claude remote-control` as a persistent system service. The server
            registers an environment with Anthropic over an outbound connection and
            spawns sessions on demand from claude.ai/code or the Claude mobile app,
            so reaching this host needs neither SSH nor the VPN.
          '';
        };
        package = mkOption {
          type = types.package;
          default = pkgs.claude-code;
          defaultText = lib.literalExpression "pkgs.claude-code";
          description = "claude-code package the server unit runs.";
        };
        workingDirectory = mkOption {
          type = types.str;
          default = "${cfg.user.home}/nixos-config";
          defaultText = lib.literalExpression ''"''${config.customConfig.user.home}/nixos-config"'';
          description = ''
            Directory the server runs in, and the directory on-demand sessions get
            in `same-dir` spawn mode. Its workspace-trust flag is pre-accepted for
            root, since the server cannot answer the trust dialog itself.
          '';
        };
        spawnMode = mkOption {
          type = types.enum [ "same-dir" "worktree" "session" ];
          default = "same-dir";
          description = ''
            How the server creates sessions: `same-dir` shares workingDirectory,
            `worktree` gives each session its own git worktree, `session` serves
            exactly one session.
          '';
        };
        extraArgs = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "--capacity" "4" "--permission-mode" "acceptEdits" ];
          description = "Extra arguments appended to the `claude remote-control` invocation.";
        };
      };
    };
  };

  config = lib.mkIf config.customConfig.programs.claudeCode.enable {
    environment.systemPackages = [ pkgs.uv claudeState ];

    system.activationScripts.claudeCodeMcp = {
      text = ''
        CLAUDE_JSON="/root/.claude.json"
        MCP_NIXOS='{"type":"stdio","command":"uvx","args":["mcp-nixos"],"env":{}}'
        if [ -f "$CLAUDE_JSON" ]; then
          tmp=$(mktemp)
          if ${pkgs.jq}/bin/jq --argjson entry "$MCP_NIXOS" '.mcpServers.nixos = $entry' "$CLAUDE_JSON" > "$tmp"; then
            mv "$tmp" "$CLAUDE_JSON"
          else
            rm -f "$tmp"
          fi
        else
          echo "{\"mcpServers\":{\"nixos\":$MCP_NIXOS}}" > "$CLAUDE_JSON"
        fi
      '';
    };

    system.activationScripts.claudeCodeSettings = {
      text = ''
        mkdir -p /root/.claude
        cat > /root/.claude/settings.json <<'CLAUDE_SETTINGS_EOF'
        ${claudeSettings}
        CLAUDE_SETTINGS_EOF
      '';
    };

    # `claude remote-control` has no TTY under systemd, so it cannot answer either
    # of the two dialogs that otherwise abort it at startup: the one-time Remote
    # Control confirmation, and the per-directory workspace-trust prompt. Both are
    # recorded in root's .claude.json, so pre-accept them here — enabling the
    # option *is* the confirmation.
    system.activationScripts.claudeCodeRemoteControl =
      lib.mkIf rcCfg.server.enable {
        deps = [ "claudeCodeMcp" ];
        text = ''
          CLAUDE_JSON="/root/.claude.json"
          if [ ! -f "$CLAUDE_JSON" ]; then echo '{}' > "$CLAUDE_JSON"; fi
          tmp=$(mktemp)
          if ${pkgs.jq}/bin/jq --arg dir "${rcCfg.server.workingDirectory}" '
                .remoteDialogSeen = true
                | .projects[$dir].hasTrustDialogAccepted = true
              ' "$CLAUDE_JSON" > "$tmp"; then
            mv "$tmp" "$CLAUDE_JSON"
          else
            rm -f "$tmp"
          fi
        '';
      };

    systemd.services.claude-remote-control = lib.mkIf rcCfg.server.enable {
      description = "Claude Code Remote Control server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      # Sessions spawned by the server shell out the same way an interactive
      # `sudo claude` here does, so hand them the same PATH: the system profile,
      # the primary user's profile (claude-code itself lives there on hosts that
      # install it via Home Manager), and the setuid wrappers for sudo.
      path = [
        "/run/wrappers"
        "/run/current-system/sw"
        "/etc/profiles/per-user/${userName}"
      ];

      environment = {
        HOME = "/root";
        CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX = cfg.system.hostName;
      };

      serviceConfig = {
        Type = "simple";
        User = "root";
        WorkingDirectory = rcCfg.server.workingDirectory;
        ExecStart = lib.escapeShellArgs ([
          "${rcCfg.server.package}/bin/claude"
          "remote-control"
          "--spawn"
          rcCfg.server.spawnMode
        ] ++ rcCfg.server.extraArgs);
        # The server redraws its status block every few seconds, so stdout is noise
        # rather than information, and errors (expired auth, untrusted workspace) go
        # to stderr regardless. Stdout does carry one thing worth knowing: the
        # https://claude.ai/code?environment=env_... URL. That URL is only needed to
        # open the environment directly, which the Claude app does not require, and
        # the id changes on every restart anyway. To read it, drop a temporary
        # StandardOutput=journal override into
        # /run/systemd/system/claude-remote-control.service.d/ and restart.
        StandardInput = "null";
        StandardOutput = "null";
        StandardError = "journal";
        Restart = "always";
        RestartSec = 10;
      };

      # A failure that survives a restart (expired login, say) should stop rather
      # than hot-loop against Anthropic's servers.
      startLimitIntervalSec = 300;
      startLimitBurst = 5;
    };
  };
}
