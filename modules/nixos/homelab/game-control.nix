# ~/nixos-config/modules/nixos/homelab/game-control.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.gameControl;

  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    fastapi
    uvicorn
    jinja2
  ]);

  appSrc = ./game-control-src;

  watchdogScript = pkgs.writeShellScript "game-watchdog" ''
    set -euo pipefail

    IDLE_THRESHOLD_SECS=${toString cfg.idleThresholdSecs}
    STATE_DIR="${cfg.stateDir}"
    NOW=$(date +%s)

    log() { echo "[watchdog] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

    container_running() {
      local status
      status=$(docker inspect --format '{{.State.Status}}' "$1" 2>/dev/null || echo "missing")
      [[ "$status" == "running" ]]
    }

    # Prints integer player count, or -1 if unknown/error.
    get_players() {
      local name="$1" container="$2" mode="$3"
      case "$mode" in
        rcon)
          local out
          out=$(docker exec "$container" rcon-cli list 2>/dev/null || true)
          local n
          n=$(echo "$out" | grep -oP 'There are \K\d+' || echo "-1")
          echo "$n"
          ;;
        bedrock)
          local out
          out=$(docker exec "$container" send-command list 2>/dev/null || true)
          local n
          n=$(echo "$out" | grep -oP '(\d+)/\d+' | grep -oP '^\d+' | head -1 || echo "-1")
          echo "''${n:--1}"
          ;;
        astroneer)
          local found
          found=$(docker logs --since="''${IDLE_THRESHOLD_SECS}s" "$container" 2>&1 \
            | grep -ciE 'LOGIN|Player.*joined|PlayerConnected' || true)
          if [[ "''${found:-0}" -gt 0 ]]; then
            echo "1"
          else
            echo "0"
          fi
          ;;
      esac
    }

    check_server() {
      local name="$1" container="$2" mode="$3"
      local ts_file="$STATE_DIR/''${name}.last_active"

      if ! container_running "$container"; then
        return
      fi

      local players
      players=$(get_players "$name" "$container" "$mode")

      if [[ "$players" -gt 0 ]]; then
        echo "$NOW" > "$ts_file"
        log "$name: $players player(s) online — idle timer reset"
        return
      fi

      if [[ ! -f "$ts_file" ]]; then
        echo "$NOW" > "$ts_file"
        log "$name: no players, idle timer started"
        return
      fi

      local last_active idle_secs
      last_active=$(cat "$ts_file")
      idle_secs=$(( NOW - last_active ))

      if [[ "$idle_secs" -ge "$IDLE_THRESHOLD_SECS" ]]; then
        log "$name: idle ''${idle_secs}s — shutting down"

        if [[ "$mode" == "rcon" ]]; then
          docker exec "$container" rcon-cli save-all 2>/dev/null || true
          sleep 5
          docker exec "$container" rcon-cli stop 2>/dev/null || true
          sleep 10
        fi

        docker stop "$container"
        rm -f "$ts_file"
        log "$name: stopped"
      else
        local remaining=$(( IDLE_THRESHOLD_SECS - idle_secs ))
        log "$name: idle ''${idle_secs}s — will stop in ''${remaining}s if no one joins"
      fi
    }

    check_server "astroneer"           "astroneer-server"   "astroneer"
    check_server "minecraft-survival"  "minecraft-survival" "rcon"
    check_server "minecraft-minigames" "minecraft-minigames" "rcon"
    check_server "minecraft-bedrock"   "minecraft-bedrock"  "bedrock"
  '';
in
{
  config = lib.mkIf cfg.enable {
    sops.secrets."game-control-token" = {
      sopsFile = ../../../secrets/mini-server.yaml;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 root root - -"
    ];

    systemd.services.game-control = {
      description = "Game Control dashboard";
      after = [ "network.target" "docker.service" ];
      wants = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.docker_29 ];
      environment.PYTHONPATH = "${appSrc}";
      serviceConfig = {
        Type = "simple";
        User = "root";
        EnvironmentFile = config.sops.secrets."game-control-token".path;
        ExecStart = "${pythonEnv}/bin/uvicorn app:app --host 0.0.0.0 --port ${toString cfg.port}";
        WorkingDirectory = "${appSrc}";
        Restart = "on-failure";
        SyslogIdentifier = "game-control";
      };
    };

    systemd.timers.game-watchdog = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/5";
        Persistent = true;
      };
    };

    systemd.services.game-watchdog = {
      description = "Game server idle-shutdown watchdog";
      path = [ pkgs.docker_29 pkgs.coreutils pkgs.gnugrep ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = watchdogScript;
        SyslogIdentifier = "game-watchdog";
      };
    };
  };
}
