# ~/nixos-config/modules/nixos/blaney-hm-options.nix
# Options for insideabush's own home-manager modules (modules/blaney-home.nix). Declared on
# the NixOS side like every other customConfig.homeManager option: home-manager modules here
# receive customConfig as a plain attrset and cannot declare options themselves.
{ lib, ... }:

{
  options.customConfig.homeManager.services = with lib; {
    rebuildShutdownNotify = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Show a critical desktop notification at next login if the last `rebuild-shutdown` failed. Enable on hosts where rebuild-shutdown is used unattended.";
      };
    };
    releaseNotes = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Pop up a short, plain-English "what's new" window at login whenever the build
          brings notes (or blaney-todo runbooks) the user hasn't seen yet, and install a
          `whats-new` command that shows them all again.
        '';
      };
      title = mkOption {
        type = types.str;
        default = "Lando's nix release notes for you";
        description = "Window title and heading of the release-notes popup.";
      };
      entries = mkOption {
        type = types.listOf (types.submodule {
          options = {
            date = mkOption { type = types.str; description = "YYYY-MM-DD the note was written."; };
            changes = mkOption { type = types.listOf types.str; description = "One plain-English line per change."; };
          };
        });
        default = [ ];
        description = ''
          Release notes, newest first, written inline. Shown after the notes in entriesDir.
          blaney-pc: hosts/blaney-pc/release-notes.nix, the frozen archive.
        '';
      };
      entriesDir = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Folder with one release note per file, named YYYY-MM-DD-<slug>.nix, each holding a
          list of plain-English lines (the date comes from the name). Shown newest first,
          ahead of `entries`. One file per note means two branches adding notes never
          conflict (blaney-pc: hosts/blaney-pc/release-notes/).
        '';
      };
      showNewTasks = mkOption {
        type = types.bool;
        default = false;
        description = "Also list blaney-todo runbooks (docs/runbooks/blaney) added since the last popup.";
      };
    };
    shutdownGuard = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Before a desktop shutdown, offer to install updates first whenever origin/main has
          commits the config checkout doesn't ("Update now, then shut down" runs
          `update-shutdown`). Silent (exits "go ahead") when there is nothing new.
        '';
      };
      offerTasks = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Also show the dialog whenever blaney-todo runbooks are waiting, with a "Have Claude
          do a task, then shut down" button that runs `blaney-todo --unattended`. Only for
          hosts that have the blaney-todo command (blaney-pc).
        '';
      };
    };
  };
}
