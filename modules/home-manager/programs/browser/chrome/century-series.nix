# ~/nixos-config/modules/home-manager/programs/browser/chrome/century-series.nix
{ lib, homeDir, ... }:

# Amber-on-instrument-black to match the century-series Hyprland rice. Colours
# are CSS custom properties defined in an @import'ed file that night mode
# swaps, so the browser follows the same day/night boundary as the rest of the
# theme instead of restating the palette.
''
  /* Managed by NixOS Home Manager — century-series MFD chrome.

     Gecko requires @import before any rule, and the URL must be ABSOLUTE:
     userChrome.css is a /nix/store symlink, so a relative import would resolve
     against the store path rather than the profile. Firefox reads both files
     only at startup, so a day/night switch lands on the next browser launch. */
  @import url("file://${homeDir}/.config/century/browser-chrome-colors.css");

  :root {
    --toolbar-bgcolor: var(--cs-bg-primary) !important;
    --toolbar-color:   var(--cs-accent-amber) !important;
    --lwt-accent-color: var(--cs-bg-primary) !important;
  }
  #nav-bar,
  #toolbar-menubar,
  #TabsToolbar,
  #PersonalToolbar {
    background-color: var(--cs-bg-primary) !important;
    color:            var(--cs-text-primary) !important;
    border-color:     var(--cs-border-primary) !important;
  }
  #urlbar,
  .urlbar-input-container {
    background-color: var(--cs-bg-tertiary) !important;
    color:            var(--cs-accent-amber) !important;
    border:           1px solid var(--cs-border-secondary) !important;
  }
  #urlbar[focused="true"] > .urlbar-input-container {
    border-color: var(--cs-accent-amber) !important;
  }
  .tab-background[selected="true"] {
    background-color: var(--cs-bg-secondary) !important;
    border-top: 2px solid var(--cs-accent-amber) !important;
  }
  .tab-label {
    color: var(--cs-text-secondary) !important;
  }
  .tab-background[selected="true"] + .tab-stack .tab-label,
  .tabbrowser-tab[selected="true"] .tab-label {
    color: var(--cs-accent-amber-glow) !important;
  }
''
