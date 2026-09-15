# ~/nixos-config/modules/home-manager/programs/browser/chrome/century-series.nix
{ lib, ... }:

# Amber-on-instrument-black to match the century-series Hyprland rice. Colors
# are imported from the theme's own palette rather than restated, so a change
# to colors.nix carries into the browser.
let
  c = (import ../../../themes/century-series/colors.nix { inherit lib; }).centuryColors;
in
''
  /* Managed by NixOS Home Manager — century-series MFD chrome */
  :root {
    --toolbar-bgcolor: ${c.bg-primary} !important;
    --toolbar-color:   ${c.accent-amber} !important;
    --lwt-accent-color: ${c.bg-primary} !important;
  }
  #nav-bar,
  #toolbar-menubar,
  #TabsToolbar,
  #PersonalToolbar {
    background-color: ${c.bg-primary} !important;
    color:            ${c.text-primary} !important;
    border-color:     ${c.border-primary} !important;
  }
  #urlbar,
  .urlbar-input-container {
    background-color: ${c.bg-tertiary} !important;
    color:            ${c.accent-amber} !important;
    border:           1px solid ${c.border-secondary} !important;
  }
  #urlbar[focused="true"] > .urlbar-input-container {
    border-color: ${c.accent-amber} !important;
  }
  .tab-background[selected="true"] {
    background-color: ${c.bg-secondary} !important;
    border-top: 2px solid ${c.accent-amber} !important;
  }
  .tab-label {
    color: ${c.text-secondary} !important;
  }
  .tab-background[selected="true"] + .tab-stack .tab-label,
  .tabbrowser-tab[selected="true"] .tab-label {
    color: ${c.accent-amber-glow} !important;
  }
''
