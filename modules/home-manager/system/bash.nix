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
      rb = "rebuild && reboot";
      ipr = "sudo input-remapper-gtk";
    };

    # On blaney-pc these three are the config-chat entry of `vibe` instead, which also hands every
    # chat the blaney-pc rules (modules/nixos/common/blaney-commands.nix). A shell function would
    # shadow the shim commands pointing him there, so they are left out.
    initExtra = lib.optionalString (customConfig.user.name != "insideabush") ''
      ccnc() {
        cd "$HOME/nixos-config" || return
        # `claude remote-control` drops an empty <uuid>.jsonl into this project's
        # history every time the server starts, and `claude -c` "continues" the
        # newest file even when it is empty — a fresh session after every
        # boot/rebuild. Resume the newest session that has a user message instead.
        local last
        last=$(sudo sh -c 'cd "$1" 2>/dev/null || exit 0
          for f in $(ls -t -- *.jsonl 2>/dev/null); do
            grep -q "\"type\":\"user\"" "$f" && { echo "''${f%.jsonl}"; exit 0; }
          done' _ "/root/.claude/projects/$(pwd -P | sed 's/[^a-zA-Z0-9]/-/g')")
        if [ -n "$last" ]; then sudo claude -r "$last"; else sudo claude -c; fi
      }
      ccn() {
        cd "$HOME/nixos-config" && sudo claude
      }
      ccnr() {
        cd "$HOME/nixos-config" && sudo claude -r
      }
    '' + ''
      claude-auto-update-failed() {
        cd "$HOME/nixos-config" && sudo claude "The latest weekly auto-update PR failed CI. Investigate the failure (check the open 'chore(flake): weekly update' PR with gh pr checks / CI logs), diagnose the cause, and fix it on the update/* branch. See the 'Automated Weekly Flake Updates' section in CLAUDE.md for the workflow. Keep me posted with a brief summary of what broke and how you fixed it."
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
            emulation)
              PS1='\[\033[1;34m\][emulation] \[\033[0;34m\]\w\[\033[0m\] ❯ '
              ;;
            vibe-python)
              PS1='\[\033[1;33m\][python app] \[\033[0;32m\]\w\[\033[0m\] ❯ '
              ;;
            vibe-web)
              PS1='\[\033[1;36m\][web app] \[\033[0;36m\]\w\[\033[0m\] ❯ '
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
