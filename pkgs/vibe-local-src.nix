# ~/nixos-config/pkgs/vibe-local-src.nix
#
# Extra callPackage arguments for one of insideabush's packaged vibe apps (pkgs/glade,
# pkgs/r62d): `{ localSrc = <his project folder>; }` on a host that runs that app from
# its project folder (customConfig.programs.vibeProjects.localApps), `{ }` everywhere
# else, so the package falls back to its fetchFromGitHub pin.
#
# This is what lets the pin be a *release* (the version lando gets) instead of something
# bumped on every change: his own machine always builds whatever is in ~/projects/<folder>
# at the moment of the rebuild, committed or not. See docs/companion-repos.md
# ("insideabush's apps: releases").
#
#   glade = pkgs.callPackage ../pkgs/glade (import ../pkgs/vibe-local-src.nix customConfig "glade");
#
# Reading /home/... at eval time needs --impure, which every rebuild here already uses.
# A host without the folder (CI, any other machine) quietly gets the pin; blaney-pc
# itself warns if the folder has gone missing, rather than silently going back to it.
customConfig: name:
let
  vibe = customConfig.programs.vibeProjects;
  folder = vibe.localApps.${name} or null;
  dir = "${vibe.dir}/${folder}";
  junk = [ ".git" ".direnv" "node_modules" "__pycache__" "result" ];
in
if !vibe.enable || folder == null then { }
else if builtins.pathExists dir then {
  localSrc = builtins.path {
    path = dir;
    # the same name fetchFromGitHub gives, so a package's `sourceRoot = "source/..."` holds
    name = "source";
    filter = path: _type: !(builtins.elem (baseNameOf path) junk);
  };
}
else if builtins.pathExists vibe.dir then
  builtins.trace "warning: vibeProjects.localApps.${name}: ${dir} is missing, building ${name} from its pin instead" { }
else { }
