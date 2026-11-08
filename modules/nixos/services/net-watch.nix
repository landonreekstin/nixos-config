# ~/nixos-config/modules/nixos/services/net-watch.nix
{ config, pkgs, lib, ... }:

# A background recorder of every bad internet moment, and whose fault it was. Every few
# seconds it pings, from the inside out, the router (over each connection the machine has),
# two big servers on the internet, and does a DNS lookup, then blames the first layer that
# failed:
#
#   THIS COMPUTER     no connection is up, one connection can't reach the router while
#                     another can (this PC's cable/port/Wi-Fi card), or lag while this PC
#                     is itself downloading heavily
#   ROUTER            the router doesn't answer (ARP) on any connection, its DNS fails, or it is
#                     laggy/losing packets itself
#   INTERNET PROVIDER the router is fine but nothing past it answers, or only past it is slow
#
# On top of that, the services he uses, each blamed on their own side only when the
# general checks above are fine at the time (otherwise on whatever is failing):
#
#   DISCORD'S SIDE    discord.com not answering (probed), or a voice call stuck on
#                     "No Route" (read from Discord's own log)
#   CLAUDE'S SIDE     api.anthropic.com not answering (probed), or an API error / usage
#                     limit shown in a Claude Code chat (read from its chat files)
#   LANDO'S SIDE      while the homelab VPN is switched on: no handshake from his end, his
#                     NAS not answering through it, or a game he hosts being blocked
#
# Service failures include the service's own status page ("Discord says: ...").
# Discord "No Route" and Claude errors from before the recorder started are imported
# once, as NOT SURE (there were no probes then to say whose fault it was).
#
# Files (in /var/lib/net-watch, world-readable):
#   events.log   "start|seconds|cause|what happened", one per finished event, read by
#                `net-log` (blaney-commands.nix)
#   now          the problems going on right now ("OK|..." when none)
#   samples.log  the raw numbers of every bad probe, for diagnosing (capped at ~5 MB)
let
  cfg = config.customConfig.services.netWatch;
  home = config.customConfig.user.home;

  watcher = pkgs.writeShellScript "net-watch" ''
    set -u
    PATH=${lib.makeBinPath (with pkgs; [ iproute2 iputils dnsutils curl jq wireguard-tools gawk coreutils findutils gnugrep gnused ])}
    DIR=/var/lib/net-watch
    EVENTS=$DIR/events.log SAMPLES=$DIR/samples.log NOW=$DIR/now
    INTERVAL=${toString cfg.interval}
    OUTSIDE="1.1.1.1 8.8.8.8"
    NAMES=(google.com wikipedia.org github.com cloudflare.com amazon.com)
    DISCORD_LOGS=${home}/.var/app/com.discordapp.Discord/config/discord/logs
    CLAUDE_DIRS="/root/.claude/projects ${home}/.claude/projects"
    VPN=${cfg.vpn.interface}
    STARTED=$(date +%s)

    # "loss avg" from 4 quick pings (avg 0 when nothing came back).
    pinger() {
      ping -n -q -c 4 -i 0.25 -W 1 "$@" 2>/dev/null | awk '
        /packet loss/ { for (i = 1; i <= NF; i++) if ($i ~ /%$/) { sub("%", "", $i); loss = $i } }
        /^rtt|^round-trip/ { split($4, a, "/"); avg = a[2] }
        END { printf "%d %d\n", (loss == "" ? 100 : loss), avg }'
    }

    # TCP connect to host port: "open", "closed" (refused: nothing listening) or "blocked"
    # (no answer at all).
    tcp() {
      timeout 4 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null
      case $? in 0) echo open ;; 124) echo blocked ;; *) echo closed ;; esac
    }

    # A Statuspage site's one-line summary, or nothing.
    status_says() {
      local s
      s=$(curl -sS -m 6 "$1/api/v2/status.json" 2>/dev/null | jq -r '.status | select(.indicator != "none") | .description' 2>/dev/null)
      [ -n "$s" ] && echo " ($2 says: $s)"
    }

    fmt_dur() {
      local s=$1
      if [ "$s" -ge 3600 ]; then printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60))
      elif [ "$s" -ge 60 ]; then printf '%dm%02ds' $((s / 60)) $((s % 60))
      else printf '%ds' "$s"; fi
    }

    clean() { tr -d '|\n' <<< "$1" | cut -c1-140; }

    log_event() { echo "$(date -d @"$1" '+%F %T')|$2|$3|$(clean "$4")" >> "$EVENTS"; }

    # Per check (net, discord, claude, vpn, game): the open problem, and the one it might be
    # turning into. report KEY CAUSE TEXT NEED STEP — an empty CAUSE means the check passed.
    # A problem opens after NEED bad probes in a row and closes after two good ones.
    declare -A cur ctext since cand candtext bad good
    close() {
      local k=$1
      [ -n "''${cur[$k]:-}" ] && log_event "''${since[$k]}" $((t - since[$k])) "''${cur[$k]}" "''${ctext[$k]}"
      cur[$k]=""
    }
    report() {
      local k=$1 c=$2 x=$3 need=$4 step=$5
      if [ -n "$c" ]; then
        good[$k]=0
        if [ "$c|$x" = "''${cand[$k]:-}|''${candtext[$k]:-}" ]; then
          bad[$k]=$(( ''${bad[$k]:-0} + 1 ))
        else
          cand[$k]=$c candtext[$k]=$x bad[$k]=1
        fi
        if [ "''${bad[$k]}" -ge "$need" ] && [ "$c|$x" != "''${cur[$k]:-}|''${ctext[$k]:-}" ]; then
          close "$k"
          cur[$k]=$c ctext[$k]=$x since[$k]=$((t - (bad[$k] - 1) * step))
        fi
      else
        bad[$k]=0 cand[$k]=""
        good[$k]=$(( ''${good[$k]:-0} + 1 ))
        [ "''${good[$k]}" -ge 2 ] && close "$k"
      fi
    }

    # Who to blame for a service failing at time $1: the general problem open then, if any.
    net_blame() {
      if [ "$1" -lt "$STARTED" ]; then echo "NOT SURE"
      elif [ -n "''${cur[net]:-}" ]; then echo "''${cur[net]}"
      else echo "$2"; fi
    }

    # --- Discord: voice "No Route", from Discord's own log -----------------------------
    nr_since=""
    discord_lines() {
      local f=$DISCORD_LOGS/renderer_js.log offf=$DIR/discord.offset off size
      [ -f "$f" ] || return 0
      size=$(stat -c %s "$f")
      if [ -f "$offf" ]; then
        off=$(cat "$offf")
        [ "$size" -lt "$off" ] && off=0
      else
        # First run: the rotated older log first, then all of the current one.
        cat "$DISCORD_LOGS/renderer_js.old.log" 2>/dev/null
        off=0
      fi
      tail -c +$((off + 1)) "$f" | head -c $((size - off))
      echo "$size" > "$offf"
    }
    check_discord_log() {
      local line ts e note
      while IFS= read -r line; do
        ts=$(date -d "''${line:1:19} UTC" +%s 2>/dev/null) || continue
        case "$line" in
          *"=> NO_ROUTE"*) nr_since=$ts ;;
          *"NO_ROUTE =>"*)
            if [ -n "$nr_since" ]; then
              note=""
              [ "$nr_since" -lt "$STARTED" ] && note=" (from before the recorder, so it can't tell whose fault)"
              log_event "$nr_since" $((ts - nr_since)) "$(net_blame "$nr_since" "DISCORD'S SIDE")" \
                "Discord voice stuck on \"No Route\" (couldn't reach the voice server)$note"
              nr_since=""
            fi ;;
        esac
      done < <(discord_lines | grep -a '\[Connection(default)\] Connection state change')
    }

    # --- Claude: errors shown in Claude Code chats -------------------------------------
    check_claude_log() {
      local last mark=$DIR/claude.mark lastf=$DIR/claude.last newest ts text e cause
      last=$(cat "$lastf" 2>/dev/null || echo "")
      newest=$last
      local args=()
      [ -f "$mark" ] && args=(-newer "$mark")
      touch "$mark.next"
      while IFS=$'\t' read -r ts text; do
        [[ "$ts" > "$last" ]] || continue
        [[ "$ts" > "$newest" ]] && newest=$ts
        e=$(date -d "$ts" +%s 2>/dev/null) || continue
        case "$text" in
          *limit*) cause="CLAUDE'S SIDE" text="Hit your Claude usage limit (your plan, not the internet): $text" ;;
          *ertificate*) cause=$(net_blame "$e" "THIS COMPUTER") text="Claude couldn't connect, security certificate problem (often this PC's clock): $text" ;;
          *) cause=$(net_blame "$e" "CLAUDE'S SIDE") text="Claude error: $text$( [ "$e" -ge "$STARTED" ] && status_says https://status.claude.com Claude)" ;;
        esac
        [ "$e" -lt "$STARTED" ] && [ "$cause" = "NOT SURE" ] && text="$text (from before the recorder)"
        log_event "$e" 0 "$cause" "$text"
      done < <(find $CLAUDE_DIRS -name '*.jsonl' "''${args[@]}" -print0 2>/dev/null \
                 | xargs -0 -r grep -h '"isApiErrorMessage":true' 2>/dev/null \
                 | jq -R -r 'try (fromjson | select(.isApiErrorMessage == true)
                     | [.timestamp, ((.message.content | if type == "array" then .[0].text else . end) // "")] | @tsv)
                     catch empty' 2>/dev/null \
                 | sort)
      mv "$mark.next" "$mark"
      [ -n "$newest" ] && echo "$newest" > "$lastf"
    }

    n=0 last_rx=0 last_t=0 last_dev=""

    while true; do
      t=$(date +%s)
      routes=$(ip -4 route show default)
      dev=$(awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "dev") print $(i + 1) }' <<< "$routes")
      gw=$(awk 'NR == 1 { print $3 }' <<< "$routes")

      # This machine's own download speed on the main connection (MB/s, whole number).
      rx=$(cat /sys/class/net/"$dev"/statistics/rx_bytes 2>/dev/null || echo 0)
      mbs=0
      if [ "$dev" = "$last_dev" ] && [ "$last_t" -gt 0 ] && [ "$t" -gt "$last_t" ]; then
        mbs=$(( (rx - last_rx) / (t - last_t) / 1000000 ))
      fi
      last_rx=$rx last_t=$t

      cause="" text="" detail="dev=$dev gw=$gw rx=''${mbs}MB/s"
      if [ -n "$last_dev" ] && [ -n "$dev" ] && [ "$dev" != "$last_dev" ]; then
        log_event "$t" 0 "THIS COMPUTER" "Switched connection from $last_dev to $dev"
      fi
      last_dev=$dev

      if [ -z "$dev" ]; then
        cause="THIS COMPUTER" text="No connection at all (cable unplugged, or Wi-Fi off)"
      else
        # His router (an AT&T gateway) sometimes ignores pings for minutes while working
        # fine, so "is it there" is asked with ARP, which it always answers; the pings only
        # measure lag.
        read -r gl ga <<< "$(pinger -I "$dev" "$gw")"
        detail="$detail router=$gl%/''${ga}ms"
        alive=yes
        if [ "$gl" -eq 100 ] && ! arping -q -c 2 -w 2 -I "$dev" "$gw"; then alive=no; fi
        detail="$detail arp=$alive"
        if [ "$alive" = no ]; then
          # Can another of this machine's connections still reach the router?
          other=""
          for d in $(awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") print $(i + 1) }' <<< "$routes"); do
            [ "$d" = "$dev" ] && continue
            arping -q -c 2 -w 2 -I "$d" "$gw" && other=$d
          done
          if [ -n "$other" ]; then
            cause="THIS COMPUTER" text="Lost the router on $dev but $other still reached it (this PC's cable, port or card)"
          else
            cause="ROUTER" text="Router stopped answering (or the cable from it)"
          fi
        else
          worst=100 sum=0 cnt=0
          for ip in $OUTSIDE; do
            read -r ol oa <<< "$(pinger "$ip")"
            detail="$detail $ip=$ol%/''${oa}ms"
            [ "$ol" -lt "$worst" ] && worst=$ol
            [ "$ol" -lt 100 ] && sum=$((sum + oa)) cnt=$((cnt + 1))
          done
          oavg=$(( cnt > 0 ? sum / cnt : 0 ))
          name=''${NAMES[$((n % ''${#NAMES[@]}))]}
          if dig +time=2 +tries=2 +short "$name" A 2>/dev/null | grep -q '^[0-9]'; then dns=ok; else dns=fail; fi
          detail="$detail dns($name)=$dns"

          if [ "$worst" -eq 100 ]; then
            cause="INTERNET PROVIDER" text="Internet down past the router (router itself was fine)"
          elif [ "$dns" = fail ]; then
            cause="ROUTER" text="Website names stopped working (router's DNS lookup failed)"
          elif [ "$worst" -ge 25 ] || [ "$oavg" -ge ${toString cfg.slowMs} ]; then
            # Lag is only the router's when its own pings were answered and bad too (it
            # skipping pings while the internet is fine is not lag).
            if [ "$gl" -lt 100 ] && { [ "$gl" -ge 25 ] || [ "$ga" -ge 30 ]; }; then
              cause="ROUTER" text="Router laggy or losing data"
            elif [ "$mbs" -ge ${toString cfg.busyMBs} ]; then
              cause="THIS COMPUTER" text="Internet laggy while this PC was downloading fast (it filled the line)"
            else
              cause="INTERNET PROVIDER" text="Internet laggy or losing data past the router"
            fi
          fi
        fi
      fi
      # A full drop counts at once; lag must last two probes in a row.
      need=1
      case "$text" in *laggy*) need=2 ;; esac
      report net "$cause" "$text" "$need" "$INTERVAL"

      # Services, every third probe, only while the general checks pass (a general
      # problem is already being recorded as the cause).
      if [ $((n % 3)) -eq 0 ]; then
        step=$((INTERVAL * 3))
        dc="" dt="" cc="" ct="" vc="" vt="" gc="" gt=""
        if [ -z "$cause" ]; then
          code=$(curl -sS -m 8 -o /dev/null -w '%{http_code}' https://discord.com/api/v10/gateway 2>/dev/null)
          detail="$detail discord=$code"
          if [ "$code" != 200 ]; then
            dc="DISCORD'S SIDE" dt="Discord not answering$(status_says https://discordstatus.com Discord)"
          fi
          code=$(curl -sS -m 8 -o /dev/null -w '%{http_code}' https://api.anthropic.com/v1/messages 2>/dev/null)
          detail="$detail claude=$code"
          if [ "$code" = 000 ] || [ "$code" -ge 500 ]; then
            cc="CLAUDE'S SIDE" ct="Claude's servers not answering$(status_says https://status.claude.com Claude)"
          fi

          # Lando's VPN: only while he has it switched on.
          if ip link show "$VPN" >/dev/null 2>&1; then
            hs=$(wg show "$VPN" latest-handshakes 2>/dev/null | awk '{ print $2; exit }')
            age=$(( t - ''${hs:-0} ))
            detail="$detail vpn-handshake=''${age}s"
            if [ "''${hs:-0}" -eq 0 ] || [ "$age" -gt 180 ]; then
              vc="LANDO'S SIDE" vt="Lando's VPN switched on but his end isn't answering"
            else
              nas=$(tcp ${cfg.vpn.nas} ${toString cfg.vpn.nasPort})
              detail="$detail vpn-nas=$nas"
              if [ "$nas" != open ]; then
                vc="LANDO'S SIDE" vt="VPN connected, but Lando's server didn't answer through it"
              else
                ${lib.concatStrings (lib.mapAttrsToList (name: g: ''
                  ${lib.optionalString (g.whileRunning != null) "if pgrep -f ${lib.escapeShellArg g.whileRunning} >/dev/null; then"}
                  st=$(tcp ${cfg.vpn.nas} ${toString g.port})
                  detail="$detail ${name}=$st"
                  if [ "$st" != open ] && [ -z "$gc" ]; then
                    gc="LANDO'S SIDE"
                    case $st in
                      blocked) gt="Couldn't reach Lando's ${name} game over the VPN (no answer, blocked on the way or his PC is off)" ;;
                      *) gt="Lando's ${name} game isn't running on his end (his side answered, but nothing was hosting)" ;;
                    esac
                  fi
                  ${lib.optionalString (g.whileRunning != null) "fi"}
                '') cfg.vpn.games)}
              fi
            fi
          fi
        fi
        report discord "$dc" "$dt" 2 "$step"
        report claude "$cc" "$ct" 2 "$step"
        report vpn "$vc" "$vt" 2 "$step"
        report game "$gc" "$gt" 2 "$step"
        check_discord_log
        check_claude_log
      fi
      n=$((n + 1))

      problems=""
      for k in net discord claude vpn game; do
        [ -n "''${cur[$k]:-}" ] && problems="$problems''${problems:+$'\n'}PROBLEM|''${cur[$k]}|''${ctext[$k]}|$(fmt_dur $((t - since[$k])))"
      done
      [ -n "$problems$cause" ] && echo "$(date '+%F %T') ''${cause:-OK} | $detail" >> "$SAMPLES"
      echo "''${problems:-OK|$detail}" > "$NOW.tmp"
      mv "$NOW.tmp" "$NOW"

      if [ "$(stat -c %s "$SAMPLES" 2>/dev/null || echo 0)" -gt 5000000 ]; then
        tail -n 20000 "$SAMPLES" > "$SAMPLES.tmp" && mv "$SAMPLES.tmp" "$SAMPLES"
      fi
      sleep $(( INTERVAL - ($(date +%s) - t) > 1 ? INTERVAL - ($(date +%s) - t) : 1 ))
    done
  '';
in
{
  options.customConfig.services.netWatch = {
    enable = lib.mkEnableOption "the background recorder of internet drops and slowdowns";
    interval = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "Seconds between probes (services are probed every third one).";
    };
    slowMs = lib.mkOption {
      type = lib.types.int;
      default = 150;
      description = "Average ping to the internet (ms) above which it counts as laggy.";
    };
    busyMBs = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "This machine's own download rate (MB/s) above which lag is blamed on it.";
    };
    vpn = {
      interface = lib.mkOption {
        type = lib.types.str;
        default = "wg-homelab";
        description = "The homelab WireGuard interface; checked only while it exists.";
      };
      nas = lib.mkOption {
        type = lib.types.str;
        default = "192.168.1.76";
        description = "The homelab address reached through the VPN.";
      };
      nasPort = lib.mkOption {
        type = lib.types.port;
        default = 8096;
        description = "An always-on TCP port there (Jellyfin) that proves the tunnel works.";
      };
      games = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            port = lib.mkOption { type = lib.types.port; };
            whileRunning = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                `pgrep -f` pattern: check the port only while this is running (for a game
                Lando only hosts sometimes). Null checks it always (an always-on server).
              '';
            };
          };
        });
        default = { };
        example = { batman = { port = 7845; whileRunning = "libexec/batman/batman.*--join"; }; };
        description = "Game ports on `nas` (over the VPN) whose failure is recorded.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.net-watch = {
      description = "Record internet drops and slowdowns, and whose fault they were";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = watcher;
        Restart = "always";
        RestartSec = 5;
        StateDirectory = "net-watch";
        StateDirectoryMode = "0755";
        UMask = "0022";
        Nice = 10;
      };
    };
  };
}
