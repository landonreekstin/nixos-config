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
  style = themeCfg.style;
  showHost = themeCfg.showHostname;
  showGit = themeCfg.showGitBranch;

  # Century Series colors (true color)
  cs = {
    amber = "38;2;255;158;59";        # #ff9e3b - main accent
    amberDim = "38;2;204;126;47";     # #cc7e2f - dimmed
    green = "38;2;127;218;137";       # #7fda89 - phosphor green
    greenBright = "38;2;57;255;20";   # #39ff14 - radar green
    panelBg = "48;2;10;14;20";        # #0a0e14 - background
    panelFg = "38;2;230;225;207";     # #e6e1cf - text
    gunmetal = "38;2;42;52;65";       # #2a3441 - frame
    red = "38;2;255;56;56";           # #ff3838 - warning
  };

  # Powerline symbols (Nerd Font)
  sym = {
    arrow = "";        # Powerline arrow
    arrowThin = "";   # Thin arrow
    branch = "";       # Git branch
    folder = "";       # Folder
    host = "";        # Computer/host
    user = "";         # User
    lock = "";         # Lock/root
    check = "";        # Success
    cross = "";        # Error
    dot = "●";          # Status dot
  };

  # Determine colors based on style
  useThemeColors = style == "themed" || style == "powerline";
  isCenturySeries = hyprlandTheme == "century-series";

  # Color assignments
  primaryColor =
    if useThemeColors && isCenturySeries then cs.amber
    else if useThemeColors && hyprlandTheme == "future-aviation" then "38;2;92;207;230"
    else colorMap.${customConfig.user.shell.bash.color};

  secondaryColor =
    if useThemeColors && isCenturySeries then cs.green
    else if useThemeColors && hyprlandTheme == "future-aviation" then "38;2;92;207;230"
    else "1;34";

  dimColor =
    if useThemeColors && isCenturySeries then cs.amberDim
    else "0;37";

  # Git functions - enhanced for powerline
  gitFunctions = ''
    # Get current git branch with icon
    __git_branch() {
      local branch
      branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
      if [ -n "$branch" ]; then
        echo "$branch"
      fi
    }

    # Get git status indicators
    __git_status() {
      local status=""
      local git_status
      git_status=$(git status --porcelain 2>/dev/null)

      if [ -n "$git_status" ]; then
        # Has changes
        if echo "$git_status" | grep -q "^[MADRC]"; then
          status+="${sym.check}"  # Staged changes
        fi
        if echo "$git_status" | grep -q "^.[MD]"; then
          status+="${sym.dot}"   # Unstaged changes
        fi
        if echo "$git_status" | grep -q "^\?\?"; then
          status+="+"            # Untracked files
        fi
      fi
      echo "$status"
    }
  '';

  # Simple git branch function for non-powerline styles
  simpleGitFunc = lib.optionalString showGit ''
    parse_git_branch() {
      local branch
      branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
      if [ -n "$branch" ]; then
        echo " (${sym.branch} $branch)"
      fi
    }
  '';

  # Build prompts for each style
  hostPart = if showHost then ''\u@\h'' else ''\u'';

  # Default style prompt
  defaultPS1 = ''\n\[\033[${primaryColor}m\][\[\e]0;${hostPart}: \w\a\]${hostPart}:\[\033[${secondaryColor}m\]\w\[\033[${primaryColor}m\]${if showGit then "$(parse_git_branch)" else ""}]\$\[\033[0m\] '';

  # Themed style prompt (same as default but with theme colors)
  themedPS1 = defaultPS1;

  # Powerline style prompt - fancy with segments
  powerlinePS1 = let
    # Reset
    reset = ''\[\033[0m\]'';

    # Colors for segments
    userBg = if isCenturySeries then "48;2;42;52;65" else "44";      # Gunmetal / Blue
    userFg = if isCenturySeries then cs.amber else "1;37";
    pathBg = if isCenturySeries then "48;2;26;31;41" else "40";      # Dark panel / Black
    pathFg = if isCenturySeries then cs.green else "1;36";
    gitBg = if isCenturySeries then "48;2;20;25;32" else "100";      # Darker / Gray
    gitFg = if isCenturySeries then cs.amber else "1;33";

    # Segment separators with color transitions
    sep1 = ''\[\033[${userBg};${if isCenturySeries then "38;2;26;31;41" else "30"}m\]${sym.arrow}'';
    sep2 = ''\[\033[${pathBg};${if isCenturySeries then "38;2;20;25;32" else "90"}m\]${sym.arrow}'';
    sep3 = ''\[\033[0;${if isCenturySeries then "38;2;20;25;32" else "90"}m\]${sym.arrow}'';

  in ''\n\[\033[${userFg};${userBg}m\] ${if showHost then "${sym.host} \\h ${sym.arrowThin} ${sym.user} \\u" else "${sym.user} \\u"} \[\033[${pathBg};${if isCenturySeries then "38;2;42;52;65" else "34"}m\]${sym.arrow}\[\033[${pathFg};${pathBg}m\] ${sym.folder} \w ''
    + (if showGit then ''\[\033[${gitBg};${if isCenturySeries then "38;2;26;31;41" else "30"}m\]${sym.arrow}\[\033[${gitFg};${gitBg}m\]$(__git_prompt_segment)'' else "")
    + ''\[\033[0m\]\[\033[${if isCenturySeries then "38;2;20;25;32" else "90"}m\]${sym.arrow}${reset}
\[\033[${primaryColor}m\]${sym.arrowThin}${reset} '';

  # Git segment for powerline
  gitSegmentFunc = lib.optionalString showGit ''
    __git_prompt_segment() {
      local branch=$(__git_branch)
      if [ -n "$branch" ]; then
        local status=$(__git_status)
        echo " ${sym.branch} $branch $status "
      fi
    }
  '';

  # Select the appropriate PS1 based on style
  selectedPS1 =
    if style == "powerline" then powerlinePS1
    else if style == "themed" then themedPS1
    else defaultPS1;

  # Combine all git functions
  allGitFuncs =
    if style == "powerline" then gitFunctions + gitSegmentFunc
    else simpleGitFunc;

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
      ${allGitFuncs}

      # Function to update PS1 based on dev environment
      update_ps1() {
        if [ -n "$DEV_ENV_NAME" ]; then
          case "$DEV_ENV_NAME" in
            kernel-dev)
              PS1='\[\033[${cs.greenBright}m\]${sym.folder} [kernel-dev]\[\033[0m\] \[\033[${cs.green}m\]\w\[\033[0m\] ${sym.arrowThin} '
              ;;
            fpga-dev)
              PS1='\[\033[1;36m\]${sym.folder} [fpga-dev]\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\] ${sym.arrowThin} '
              ;;
            embedded-linux)
              PS1='\[\033[${cs.amber}m\]${sym.folder} [embedded-linux]\[\033[0m\] \[\033[${cs.green}m\]\w\[\033[0m\] ${sym.arrowThin} '
              ;;
            gbdk-dev)
              PS1='\[\033[1;35m\]${sym.folder} [gbdk-dev]\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\] ${sym.arrowThin} '
              ;;
            *)
              PS1="${selectedPS1}"
              ;;
          esac
        else
          PS1="${selectedPS1}"
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
