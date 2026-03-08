# ~/nixos-config/modules/home-manager/system/bash.nix
{ config, lib, pkgs, customConfig, ... }:

let
  # Standard ANSI color map
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

  # Theme settings
  themeCfg = customConfig.homeManager.themes.bashPrompt;
  hyprlandTheme = customConfig.homeManager.themes.hyprland;

  # Determine the color to use
  # - "themed" style uses theme-specific colors (amber for century-series)
  # - "default" style uses customConfig.user.shell.bash.color
  promptColor =
    if themeCfg.style == "themed" then
      if hyprlandTheme == "century-series" then
        "38;2;255;158;59"  # True color amber (#ff9e3b)
      else if hyprlandTheme == "future-aviation" then
        "38;2;92;207;230"  # True color cyan (#5ccfe6)
      else
        colorMap.${customConfig.user.shell.bash.color}
    else
      colorMap.${customConfig.user.shell.bash.color};

  # Secondary color for path (dimmer)
  pathColor =
    if themeCfg.style == "themed" then
      if hyprlandTheme == "century-series" then
        "38;2;127;218;137"  # Phosphor green (#7fda89)
      else if hyprlandTheme == "future-aviation" then
        "38;2;92;207;230"  # Cyan
      else
        "1;34"  # Bright blue default
    else
      "1;34";  # Bright blue default

  # Build prompt components
  showHost = themeCfg.showHostname;
  showGit = themeCfg.showGitBranch;

  # Git branch function (only included if showGitBranch is true)
  gitBranchFunc = lib.optionalString showGit ''
    # Get current git branch
    parse_git_branch() {
      local branch
      branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
      if [ -n "$branch" ]; then
        echo " ($branch)"
      fi
    }
  '';

  # Build the PS1 string based on configuration
  # Format: [user@host:path (branch)]$ or [user:path (branch)]$ if no hostname
  hostPart = if showHost then ''\u@\h'' else ''\u'';
  gitPart = if showGit then ''$(parse_git_branch)'' else "";

  # Standard prompt (outside dev environments)
  standardPS1 = ''\n\[\033[${promptColor}m\][\[\e]0;${hostPart}: \w\a\]${hostPart}:\[\033[${pathColor}m\]\w\[\033[${promptColor}m\]${gitPart}]\$\[\033[0m\] '';

in
{
  programs.bash = lib.mkIf (customConfig.user.shell.bash.enable) {
    enable = true;

    shellAliases = {
      c = "clear";
      rb = "sudo reboot";
      ipr = "sudo input-remapper-gtk";
    };

    bashrcExtra = ''
      ${gitBranchFunc}

      # Function to update PS1 based on dev environment
      update_ps1() {
        if [ -n "$DEV_ENV_NAME" ]; then
          case "$DEV_ENV_NAME" in
            kernel-dev)
              PS1='\[\033[1;32m\][kernel-dev]\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\]\$ '
              ;;
            fpga-dev)
              PS1='\[\033[1;36m\][fpga-dev]\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\]\$ '
              ;;
            embedded-linux)
              PS1='\[\033[1;33m\][embedded-linux]\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\]\$ '
              ;;
            gbdk-dev)
              PS1='\[\033[1;35m\][gbdk-dev]\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\]\$ '
              ;;
            *)
              PS1="${standardPS1}"
              ;;
          esac
        else
          PS1="${standardPS1}"
        fi
      }

      # Wrapper that ensures it stays in PROMPT_COMMAND
      _ps1_prompt_wrapper() {
        if [[ "$PROMPT_COMMAND" != *"_ps1_prompt_wrapper"* ]]; then
          PROMPT_COMMAND="''${PROMPT_COMMAND:+$PROMPT_COMMAND; }_ps1_prompt_wrapper"
        fi
        update_ps1
      }

      # Set initial PS1
      update_ps1

      # Add wrapper to PROMPT_COMMAND
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
