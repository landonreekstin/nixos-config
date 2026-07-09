# ~/nixos-config/modules/nixos/programs/claude-code.nix
{ config, pkgs, lib, ... }:

let
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

      user_id="$(id -u lando 2>/dev/null || echo 1002)"
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

      pkill -RTMIN+16 -u lando waybar >/dev/null 2>&1 || true
    '';
  };

  claudeSettings = builtins.toJSON {
    model = "opus";
    effortLevel = "high";
    hooks = {
      Stop = [{
        hooks = [
          { type = "command"; command = "sudo chown -R lando:users /home/lando/hyprland-keys /home/lando/nixos-config 2>/dev/null || true"; }
          { type = "command"; command = "claude-state green"; }
        ];
      }];
      PostToolUse = [{
        matcher = "Edit|Write";
        hooks = [
          { type = "command"; command = "sudo chown -R lando:users /home/lando/hyprland-keys /home/lando/nixos-config 2>/dev/null || true"; }
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
  };
in
{
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
  };
}
