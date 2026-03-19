# ~/nixos-config/modules/home-manager/system/bash.nix
{ config, lib, pkgs, customConfig, ... }:

let
  colorMap = {
    "black"   = "0;30";
    "red"     = "0;31";
    "green"   = "0;32";
    "yellow"  = "0;33";
    "blue"    = "0;34";
    "magenta" = "0;35";
    "cyan"    = "0;36";
    "white"   = "0;37";

    "bright-black"   = "1;30";
    "bright-red"     = "1;31";
    "bright-green"   = "1;32";
    "bright-yellow"  = "1;33";
    "bright-blue"    = "1;34";
    "bright-magenta" = "1;35";
    "bright-cyan"    = "1;36";
    "bright-white"   = "1;37";
  };

  color = colorMap.${customConfig.user.shell.bash.color};

  # Git branch symbol (Nerd Font)
  branchSym = "";

  defaultPS1 = ''\n\[\033[${color}m\][\[\e]0;\u@\h: \w\a\]\u@\h:\[\033[1;34m\]\w\[\033[${color}m\]$(parse_git_branch)]\$\[\033[0m\] '';

in
{
  programs.bash = lib.mkIf (customConfig.user.shell.bash.enable) {
    enable = true;

    shellAliases = {
      c = "clear";
      rb = "sudo reboot";
      ipr = "sudo input-remapper-gtk";
    };

    initExtra = ''
      ncc() {
        cd /home/lando/nixos-config && sudo claude -c .
      }
    '';

    bashrcExtra = ''
      parse_git_branch() {
        local branch
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
        [ -n "$branch" ] && echo " (${branchSym} $branch)"
      }

      update_ps1() {
        # When inside kitty, a theme may activate starship — skip manual PS1
        [ -n "$KITTY_WINDOW_ID" ] && return

        if [ -n "$DEV_ENV_NAME" ]; then
          case "$DEV_ENV_NAME" in
            kernel-dev)
              PS1='\[\033[1;32m\][kernel-dev] \[\033[0;32m\]\w\[\033[0m\] ❯ '
              ;;
            fpga-dev)
              PS1='\[\033[1;36m\][fpga-dev] \[\033[0;36m\]\w\[\033[0m\] ❯ '
              ;;
            embedded-linux)
              PS1='\[\033[1;33m\][embedded-linux] \[\033[0;32m\]\w\[\033[0m\] ❯ '
              ;;
            gbdk-dev)
              PS1='\[\033[1;35m\][gbdk-dev] \[\033[0;34m\]\w\[\033[0m\] ❯ '
              ;;
            *)
              PS1="${defaultPS1}"
              ;;
          esac
        else
          PS1="${defaultPS1}"
        fi
      }

      _ps1_prompt_wrapper() {
        if [[ "$PROMPT_COMMAND" != *"_ps1_prompt_wrapper"* ]]; then
          PROMPT_COMMAND="''${PROMPT_COMMAND:+$PROMPT_COMMAND; }_ps1_prompt_wrapper"
        fi
        update_ps1
      }

      update_ps1
      PROMPT_COMMAND="''${PROMPT_COMMAND:+$PROMPT_COMMAND; }_ps1_prompt_wrapper"
    '';

    # Auto-launch the first DE on TTY1 when no display manager is configured
    profileExtra =
      let
        des = customConfig.desktop.environments;
        firstDE = if des != [] then lib.head des else "none";
        launchCmd =
          if firstDE == "hyprland" then "exec ${pkgs.hyprland}/bin/Hyprland"
          else if firstDE == "kde" then "exec dbus-run-session startplasma-wayland"
          else if firstDE == "cosmic" then "exec cosmic-session"
          else null;
      in
      lib.mkIf (customConfig.desktop.displayManager.type == "none" && launchCmd != null) ''
        if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
          ${launchCmd}
        fi
      '';
  };

  # === Enable direnv ===
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
