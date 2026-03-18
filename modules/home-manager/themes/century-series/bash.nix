# ~/nixos-config/modules/home-manager/themes/century-series/bash.nix
{ config, pkgs, lib, customConfig, ... }:

let
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";
in

lib.mkIf centurySeriesThemeCondition {

  home.packages = [ pkgs.starship ];

  # Century Series starship config — Cold War aviation cockpit aesthetic
  # Two filled powerline segments (host/user, directory) + plain-text git/nix info
  home.file.".config/starship.toml".text = ''
    "$schema" = 'https://starship.rs/config-schema.json'

    # Two-line prompt:
    #   [▶ hostname ▸ user ▶][▶ directory ▶] branch status  nix  duration
    #   ❯
    format = """
    \n[](fg:#2a3441)\
    $hostname\
    $username\
    [](fg:#2a3441 bg:#141920)\
    $directory\
    [](fg:#141920)\
    $git_branch\
    $git_status\
    $nix_shell\
    $cmd_duration\
    $line_break\
    $character"""

    # ── Segment 1: host + user on gunmetal background ───────────────────────── #

    [hostname]
    format = '[ $hostname ▸](bg:#2a3441 fg:#cc7e2f)'
    ssh_only = false

    [username]
    format = '[ $user ](bg:#2a3441 fg:#ff9e3b)'
    show_always = true

    # ── Segment 2: directory on dark panel background ────────────────────────── #

    [directory]
    format = '[ $path$read_only](bg:#141920 fg:#7fda89) '
    truncation_length = 3
    truncate_to_repo = true
    read_only = ' '
    read_only_style = 'fg:#ff3838 bg:#141920'

    # ── Git info: plain amber text after the segment ─────────────────────────── #

    [git_branch]
    format = '[ $symbol$branch ](fg:#ff9e3b)'
    symbol = ' '

    [git_status]
    format = '[$all_status$ahead_behind ](fg:#cc7e2f)'
    staged    = '●'
    modified  = '✦'
    untracked = '+'
    deleted   = '✗'
    conflicted = '!'
    ahead     = '⇡''${count}'
    behind    = '⇣''${count}'
    diverged  = '⇕⇡''${ahead_count}⇣''${behind_count}'

    # ── Nix shell indicator ──────────────────────────────────────────────────── #

    [nix_shell]
    format = '[❄ $name ](fg:#5ccfe6)'
    heuristic = true

    # ── Command duration (shows for slow commands) ───────────────────────────── #

    [cmd_duration]
    format = '[⏱ $duration ](fg:#a6a69c)'
    min_time = 2000

    # ── Prompt character ─────────────────────────────────────────────────────── #

    [character]
    success_symbol = '[❯](bold fg:#ff9e3b)'
    error_symbol   = '[❯](bold fg:#ff3838)'
  '';

  # Activate starship only inside kitty — TTY, SSH, and other terminals
  # continue using the standard bash prompt from bash.nix
  programs.bash.bashrcExtra = lib.mkAfter ''
    if [ -n "$KITTY_WINDOW_ID" ]; then
      eval "$(starship init bash)"
    fi
  '';
}
