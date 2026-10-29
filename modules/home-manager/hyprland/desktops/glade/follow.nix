# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/follow.nix
#
# The glade follows github:cblaney00/glade's `main` by itself (his ask, 2026-10-28: after
# Claude pushes a glade change he should only have to press Thunderstorm, not wait for a
# config bump too).
#
# Every two minutes a user timer looks at `main`; when it has moved, it builds that commit
# with the same recipe as the pin (pkgs/glade, src swapped for the commit) into
# ~/.local/state/glade/latest. glade-desktop (desktop.nix) runs that build when there is one
# and puts it first on the glade's PATH, so resume.py sees it as "installed" and the
# Thunderstorm notice shows; pressing it loads the new glade. The pinned glade stays the
# fallback: no build yet, or a build that keeps crashing at start.
#
# Only the glade itself follows main. glade-status (the Claude panel), games.py and dock.py
# still come from the pin, so a change to those still needs a bump.
{ pkgs, lib, customConfig, ... }:

let
  desktop = (import ../lib.nix { inherit lib; }).state customConfig "glade";

  recipe = ../../../../../pkgs/glade;

  gladeFollow = pkgs.writeShellApplication {
    name = "glade-follow";
    runtimeInputs = [ pkgs.git pkgs.nix pkgs.coreutils ];
    text = ''
      state="$HOME/.local/state/glade"
      mkdir -p "$state"
      rev=$(git ls-remote https://github.com/cblaney00/glade refs/heads/main | cut -f1)
      [ -n "$rev" ] || exit 0
      # Build again when main moved, or after a rebuild changed the recipe or nixpkgs.
      stamp="$rev ${recipe} ${pkgs.path}"
      [ "$(cat "$state/latest.stamp" 2>/dev/null)" = "$stamp" ] && exit 0
      nix build --impure --out-link "$state/latest" --argstr rev "$rev" --expr '
        { rev }:
        let pkgs = import ${pkgs.path} { system = "${pkgs.stdenv.hostPlatform.system}"; };
        in (pkgs.callPackage ${recipe} { }).overrideAttrs (old: {
          version = "main-" + builtins.substring 0 7 rev;
          src = builtins.fetchGit { url = "https://github.com/cblaney00/glade"; inherit rev; };
        })'
      echo "$stamp" > "$state/latest.stamp"
    '';
  };
in
{
  config = lib.mkIf desktop.enabled {
    home.packages = [ gladeFollow ];

    systemd.user.services.glade-follow = {
      Unit.Description = "Build the newest glade from github:cblaney00/glade main";
      Service = {
        Type = "oneshot";
        ExecStart = "${gladeFollow}/bin/glade-follow";
      };
    };
    systemd.user.timers.glade-follow = {
      Unit.Description = "Look for a newer glade every two minutes";
      Timer = {
        OnStartupSec = "20s";
        OnUnitActiveSec = "2min";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
