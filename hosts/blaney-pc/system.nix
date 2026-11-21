# ~/nixos-config/hosts/blaney-pc/system.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    user = {
      name = "insideabush";
      email = "cblaney00@gmail.com";
      updateCmdPermission = false;
    };

    system = {
      hostName = "blaney-pc"; # Actual hostname for this machine
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/New_York"; # As per your old core.nix
      locale = "en_US.UTF-8"; # As per your old core.nix
    };

    bootloader.plymouth = {
      enable = true;
      theme = "hexa_retro";
    };

  };

  # The case's power button must not power the machine off behind our back: this host runs a
  # weekly unattended update that needs it left on, so the button is bound to the Win7 power
  # flyout instead (XF86PowerOff in modules/home-manager/themes/windows7-xfce/keybindings.nix),
  # which runs the shutdown guard. Without this, logind would still hard-poweroff on the key.
  services.logind.settings.Login.HandlePowerKey = "ignore";

  # Over this machine's Wi-Fi, nix's single multiplexed HTTP/2 connection to cache.nixos.org
  # crawls at ~0.3 MB/s; one connection per download (HTTP/1.1) measured ~16 MB/s.
  nix.settings.http2 = false;

  # Keep the PC from sleeping while any Claude session is running, so overnight work
  # (work-notes, blaney-todo-unattended, a vibe chat) is never cut off. The screen may
  # still lock and turn off; only system sleep is blocked. Claude Code's process name is
  # `.claude-wrapped` (the Nix wrapper), so match that as well as plain `claude`.
  systemd.services.claude-keep-awake = {
    description = "Keep the PC awake while Claude is working";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.procps pkgs.systemd pkgs.coreutils ];
    script = ''
      while true; do
        if pgrep -x '\.?claude(-wrapped)?' >/dev/null; then
          systemd-inhibit --what=sleep:handle-lid-switch --who=Claude \
            --why="Claude is working" --mode=block sleep 60
        else
          sleep 60
        fi
      done
    '';
    serviceConfig.Restart = "always";
  };
}
