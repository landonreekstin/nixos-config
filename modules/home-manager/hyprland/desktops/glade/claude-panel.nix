# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/claude-panel.nix
#
# The Glade's Claude panel (claude_panel.py in pkgs/glade): a small panel on insideabush's
# lower screen for the Claude chat he has open. Not a module: the launchers that start
# Claude import it, the NixOS ones (ccn in common/commands.nix, vibe in
# programs/vibe-projects.nix) as well as home-manager's vibe CLAUDE.md, so they all pass
# the same hooks and tell Claude the same rules.
#
#   hooks      — Claude Code settings with the hooks that keep the panel up to date
#                (passed with `--settings`)
#   status     — `glade-status`, which Claude runs to title its task, show progress and
#                call him to the terminal
#   ccnRules   — the section about the panel in the ccn rules
#   vibeRules  — the same, shorter, for vibe projects' CLAUDE.md
{ pkgs }:

let
  glade = pkgs.callPackage ../../../../../pkgs/glade { };
  gladeStatus = "${glade}/bin/glade-status";
in
{
  hooks = "${glade}/share/glade/claude-hooks.json";
  status = gladeStatus;

  ccnRules = ''
    ## The Claude panel on his lower screen

    His Glade desktop shows a small panel for this chat: a title, your latest message, a
    progress bar, and a box he can type replies in (they arrive here as ordinary messages,
    often while you work). Hooks keep the message up to date; keep the rest useful with
    `${gladeStatus}`:
    - At the start of each piece of work, name it in a few plain words:
      `${gladeStatus} title "Filling the Forest Dex"`.
    - For work with countable steps: `${gladeStatus} progress 6 "<first step>"`, then
      `${gladeStatus} step "<step just done>" "<next step>"` after EVERY step, never in jumps
      (he reads a bar that sits still as frozen). When the work is finished, run
      `${gladeStatus} done` so the bar ends even if it took fewer steps than planned (he once
      saw it stuck at 10/14 and wondered what he was still waiting for).
    - When the work is finished, `${gladeStatus} done`, so the bar ends even if it took fewer steps
      than planned (he once saw it stuck at 10/14 and wondered what he was still waiting for).
    - When he should come to the terminal (options to pick do this by themselves), say why with
      `${gladeStatus} attention "<why>"`, and `${gladeStatus} calm` once he has answered.
    The panel then says "Open terminal" in orange; clicking the panel always brings up your
    terminal. Never skip a question because he might be on the other screen.

  '';

  vibeRules = ''
    - His Glade desktop shows a small panel for this chat (your latest message, a reply box).
      Name each piece of work with `${gladeStatus} title "<a few plain words>"`; for countable
      steps use `${gladeStatus} progress N "<first>"` then `${gladeStatus} step "<done>" "<next>"`
      after EVERY step; and `${gladeStatus} attention "<why>"` (then `calm`) when he should come
      to the terminal. Never skip a question because he might be on the other screen.
  '';
}
