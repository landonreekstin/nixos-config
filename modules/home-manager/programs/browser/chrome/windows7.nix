# ~/nixos-config/modules/home-manager/programs/browser/chrome/windows7.nix
{ ... }:

# Aero-glass blue, to sit alongside the windows7-xfce desktop theme. The
# gradients approximate the Win7 titlebar rather than trying to be a pixel match
# — Firefox's chrome has no equivalent of the real Aero blur.
''
  /* Managed by NixOS Home Manager — Windows 7 Aero chrome */
  :root {
    --toolbar-bgcolor: #c8ddf2 !important;
    --toolbar-color:   #16334d !important;
  }
  #navigator-toolbox {
    background: linear-gradient(to bottom, #dcebfa 0%, #b6d2ec 45%, #9ec1e3 100%) !important;
    border-bottom: 1px solid #6f96bb !important;
  }
  #nav-bar,
  #toolbar-menubar,
  #TabsToolbar,
  #PersonalToolbar {
    background: transparent !important;
    color:      #16334d !important;
  }
  #urlbar,
  .urlbar-input-container {
    background-color: #ffffff !important;
    color:            #16334d !important;
    border:           1px solid #7f9db9 !important;
    border-radius:    2px !important;
  }
  .tab-background[selected="true"] {
    background: linear-gradient(to bottom, #ffffff 0%, #e4effb 100%) !important;
    border: 1px solid #6f96bb !important;
    border-bottom: none !important;
  }
  .tab-label {
    color: #16334d !important;
  }
''
