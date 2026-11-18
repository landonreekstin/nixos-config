# ~/nixos-config/modules/nixos/services/download-smoother.nix
{ config, pkgs, lib, ... }:

# Keeps this machine's big downloads (Steam etc.) from filling the internet line, which
# makes everything else lag ("bufferbloat": the line's queue fills up and every ping waits
# behind it). Incoming internet traffic is sent through CAKE, a queue that keeps every
# connection's packets moving, held a little under the line's speed so the queue stays
# here instead of at the ISP. The line's speed changes through the day, so the limit is
# adjusted every second from ping times: lowered when pings climb while a download fills
# it, raised again while pings stay low (a small version of cake-autorate).
#
# Only traffic from the internet is shaped (LAN addresses pass untouched), only incoming
# (downloads are what net-watch caught filling the line), and stopping the service removes
# all of it. The current limit is in /run/download-smoother/now.
let
  cfg = config.customConfig.services.downloadSmoother;

  smoother = pkgs.writeShellScript "download-smoother" ''
    set -u
    PATH=${lib.makeBinPath (with pkgs; [ iproute2 iputils kmod gawk coreutils gnugrep ])}
    DEV=${cfg.device} IFB=ifb-dl
    MIN=${toString (cfg.minMbit * 1000)} MAX=${toString (cfg.maxMbit * 1000)}
    rate=${toString (cfg.startMbit * 1000)}   # kbit/s
    base=""                                   # the line's ping with nothing queued (ms)
    cooldown=0

    setup() {
      modprobe ifb sch_cake act_mirred cls_flower 2>/dev/null
      ip link show "$IFB" >/dev/null 2>&1 || ip link add "$IFB" type ifb
      ip link set "$IFB" up
      tc qdisc replace dev "$IFB" root cake bandwidth "''${rate}kbit" besteffort triple-isolate ingress
      tc qdisc del dev "$DEV" ingress 2>/dev/null
      tc qdisc add dev "$DEV" handle ffff: ingress || return 1
      for lan in 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12; do
        tc filter add dev "$DEV" parent ffff: prio 1 protocol ip flower src_ip "$lan" action ok
      done
      tc filter add dev "$DEV" parent ffff: prio 2 matchall action mirred egress redirect dev "$IFB"
    }

    rtt() {  # the faster of two pings, in ms; empty if the internet isn't answering
      { ping -n -c1 -W1 1.1.1.1 & ping -n -c1 -W1 8.8.8.8 & wait; } 2>/dev/null \
        | awk -F'time=' '/time=/{split($2,a," "); if (m=="" || a[1]<m) m=a[1]} END{if (m!="") printf "%d", m}'
    }

    mkdir -p /run/download-smoother
    last=$(cat /sys/class/net/"$DEV"/statistics/rx_bytes 2>/dev/null || echo 0); lt=$(date +%s%N)
    while true; do
      # NetworkManager drops the ingress hook when the cable or connection comes back
      tc filter show dev "$DEV" parent ffff: 2>/dev/null | grep -q mirred || setup
      sleep 1
      now=$(cat /sys/class/net/"$DEV"/statistics/rx_bytes 2>/dev/null || echo 0); nt=$(date +%s%N)
      ms=$(( (nt - lt) / 1000000 )); [ "$ms" -gt 0 ] || ms=1
      load=$(( (now - last) * 8 / ms ))       # kbit/s actually arriving
      last=$now lt=$nt
      r=$(rtt)
      [ -n "$r" ] || continue                 # internet down: nothing to tune
      if [ -z "$base" ] || [ "$r" -lt "$base" ]; then base=$r
      elif [ $(( RANDOM % 30 )) -eq 0 ]; then base=$(( base + 1 )); fi  # slow drift up
      delta=$(( r - base ))
      busy=$(( load * 100 / rate ))           # how full the limit is, in %
      if [ "$cooldown" -gt 0 ]; then cooldown=$(( cooldown - 1 ))
      elif [ "$delta" -gt ${toString cfg.laggyMs} ] && [ "$load" -gt 5000 ]; then
        # laggy while downloading: step down, or (the line just got slower than the limit)
        # straight to a bit over what is actually getting through
        if [ "$busy" -gt 50 ]; then rate=$(( rate * 85 / 100 )); else rate=$(( load * 110 / 100 )); fi
        [ "$rate" -lt "$MIN" ] && rate=$MIN
        tc qdisc change dev "$IFB" root cake bandwidth "''${rate}kbit"
        cooldown=2                            # let the queue drain before judging again
      elif [ "$delta" -lt ${toString (cfg.laggyMs / 2)} ] && [ "$busy" -gt 70 ] && [ "$rate" -lt "$MAX" ]; then
        rate=$(( rate * 104 / 100 + 200 )); [ "$rate" -gt "$MAX" ] && rate=$MAX
        tc qdisc change dev "$IFB" root cake bandwidth "''${rate}kbit"
      fi
      echo "limit=$(( rate / 1000 ))Mbit using=$(( load / 1000 ))Mbit ping=''${r}ms base=''${base}ms" \
        > /run/download-smoother/now
    done
  '';

  cleanup = pkgs.writeShellScript "download-smoother-stop" ''
    ${pkgs.iproute2}/bin/tc qdisc del dev ${cfg.device} ingress 2>/dev/null
    ${pkgs.iproute2}/bin/ip link del ifb-dl 2>/dev/null
    exit 0
  '';
in
{
  options.customConfig.services.downloadSmoother = {
    enable = lib.mkEnableOption "keeping this machine's downloads from making the internet laggy";
    device = lib.mkOption {
      type = lib.types.str;
      description = "The network interface to the router whose downloads are smoothed.";
    };
    startMbit = lib.mkOption { type = lib.types.int; default = 60; description = "Limit at start (Mbit/s)."; };
    minMbit = lib.mkOption { type = lib.types.int; default = 10; description = "Lowest the limit goes (Mbit/s)."; };
    maxMbit = lib.mkOption { type = lib.types.int; default = 300; description = "Highest the limit goes (Mbit/s)."; };
    laggyMs = lib.mkOption {
      type = lib.types.int;
      default = 20;
      description = "Ping rise (ms) over the quiet-line ping that counts as the queue filling.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.download-smoother = {
      description = "Keep downloads from making the internet laggy";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = smoother;
        ExecStopPost = cleanup;
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
