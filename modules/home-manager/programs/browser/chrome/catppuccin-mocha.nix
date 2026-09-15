# ~/nixos-config/modules/home-manager/programs/browser/chrome/catppuccin-mocha.nix
{ ... }:

# Carried over verbatim from the old modules/home-manager/programs/librewolf.nix,
# so hosts already on that module see no visual change after the migration.
''
  /* Managed by NixOS Home Manager — dark browser chrome (Catppuccin Mocha) */
  :root {
    --toolbar-bgcolor: #1e1e2e !important;
    --toolbar-color:   #cdd6f4 !important;
  }
  #nav-bar,
  #toolbar-menubar,
  #TabsToolbar,
  #PersonalToolbar {
    background-color: #1e1e2e !important;
    color:            #cdd6f4 !important;
    border-color:     #45475a !important;
  }
  #urlbar,
  .urlbar-input-container {
    background-color: #181825 !important;
    color:            #cdd6f4 !important;
  }
  .tab-background[selected="true"] {
    background-color: #313244 !important;
  }
  .tab-label {
    color: #cdd6f4 !important;
  }
''
