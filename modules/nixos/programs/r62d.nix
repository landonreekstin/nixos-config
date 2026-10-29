# ~/nixos-config/modules/nixos/programs/r62d.nix
{ config, pkgs, lib, ... }:

# R62D (pkgs/r62d): insideabush's tactical 5v5 browser game, as an app.
#
#   r62d          start the game server here if it isn't running, then open the game
#                 full screen in its own Firefox window (kiosk mode, its own profile)
#   r62d-server   just the server (port 6262; friends open http://<this PC>:6262)
#
# Profiles and match history are kept in ~/.local/share/r62d/data. The server's log is
# ~/.local/share/r62d/server.log. Friends on the VPN connect to this machine's VPN address.
let
  cfg = config.customConfig.programs.r62d;
  r62d = pkgs.callPackage ../../../pkgs/r62d (import ../../../pkgs/vibe-local-src.nix config.customConfig "r62d");

  launcher = pkgs.writeShellApplication {
    name = "r62d";
    runtimeInputs = [ r62d pkgs.coreutils pkgs.procps pkgs.xdg-utils ];
    text = ''
      data="''${XDG_DATA_HOME:-$HOME/.local/share}/r62d"
      mkdir -p "$data"
      up() { (exec 3<>/dev/tcp/127.0.0.1/6262) 2>/dev/null; }
      if ! up; then
        nohup r62d-server > "$data/server.log" 2>&1 &
        for _ in $(seq 1 30); do up && break; sleep 0.5; done
      fi
      profile="$data/firefox-kiosk"
      # already open? don't start a second window
      pgrep -f "r62d/firefox-kiosk" > /dev/null && exit 0
      if ! command -v firefox > /dev/null; then exec xdg-open "http://localhost:6262"; fi
      mkdir -p "$profile"
      cat > "$profile/user.js" <<'PREFS'
      user_pref("browser.shell.checkDefaultBrowser", false);
      user_pref("browser.aboutwelcome.enabled", false);
      user_pref("browser.startup.homepage_override.mstone", "ignore");
      user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
      user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
      user_pref("browser.sessionstore.resume_from_crash", false);
      user_pref("media.autoplay.default", 0);
      user_pref("full-screen-api.warning.timeout", 0);
      user_pref("browser.tabs.warnOnClose", false);
      user_pref("dom.disable_beforeunload", true);
      user_pref("permissions.default.shortcuts", 2);
      PREFS
      exec firefox --kiosk --no-remote --profile "$profile" "http://localhost:6262/?app=1"
    '';
  };

  desktop = pkgs.makeDesktopItem {
    name = "r62d";
    desktopName = "R62D";
    comment = "Tactical 5v5 with friends";
    exec = "r62d";
    icon = "${r62d}/share/icons/hicolor/scalable/apps/r62d.svg";
    categories = [ "Game" ];
  };
in
{
  options.customConfig.programs.r62d = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "R62D, insideabush's tactical 5v5 browser game (r62d command + menu entry).";
    };
    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open TCP 6262 so friends can join a game hosted on this machine.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ r62d launcher desktop ];
    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [ 6262 ];
  };
}
