# ~/nixos-config/modules/home-manager/themes/xbox360/colors.nix
# Blade palette of the 2005 Xbox 360 "Blades" dashboard. Plain data, imported by
# the Hyprland settings here and (later) by the Quickshell shell, so the two
# cannot drift.
#
# Source: the researched palette in DESIGN.md §2 of
# David-Lazaro-Fernandez/Audio-Visualizer (the same pinned commit the assets come
# from — pkgs/xbox360-assets). Not yet cross-checked against console captures;
# if a blade reads wrong against a real screenshot, fix it here.
{ lib }:

rec {
  # Left-to-right blade order on the console, which is also workspace 1-5.
  order = [ "marketplace" "live" "games" "media" "system" ];

  blades = {
    # Each blade's identity is a radial gradient (centre 50%/44% of the panel)
    # with four stops at 0 / 30 / 62 / 100%. `base` is the 30% stop: the colour
    # a single-value consumer (a window border) should use.
    marketplace = {
      title = "Marketplace";
      stops = [ "f7c9a0" "eea673" "e0834a" "c9652b" ];
      base = "eea673";
      tab = [ "b8500f" "ff9d4e" "e06a1a" ];
      ink = "2e1a0c";
      rule = "c97a45";
    };
    live = {
      title = "Xbox LIVE";
      stops = [ "f8cd5e" "f3ae3c" "e4952b" "cf7b1d" ];
      base = "f3ae3c";
      tab = [ "c67a1a" "f8c85e" "e39a2b" ];
      ink = "2a1a04";
      rule = "f2c66a";
    };
    games = {
      title = "Games";
      stops = [ "6ecb2e" "52b81f" "3e9c16" "2f7e10" ];
      base = "52b81f";
      tab = [ "478f14" "95e04d" "57a91b" ];
      ink = "17300a";
      rule = "379226";
    };
    media = {
      title = "Media";
      stops = [ "6dbdf4" "46a2e8" "2f86d2" "2369b4" ];
      base = "46a2e8";
      tab = [ "2472b8" "86ccf6" "3f97da" ];
      ink = "0a2240";
      rule = "7cc4f2";
    };
    system = {
      title = "System";
      stops = [ "9c6fc6" "804ea9" "6d4094" "58327b" ];
      base = "804ea9";
      tab = [ "613889" "b58ad9" "8a58b6" ];
      ink = "1f0f33";
      rule = "a17dc6";
    };
    # Not a console blade: what the panel becomes on a workspace past the
    # five (6-10, named ones like the stream wall). Neutral, on the same
    # radial structure as the others.
    steel = {
      title = "Workspace";
      stops = [ "d3d8de" "b3bac3" "939ca7" "747e8b" ];
      base = "b3bac3";
      tab = [ "7d858f" "d3d8de" "959da7" ];
      ink = "1c2128";
      rule = "c9ced4";
    };
  };

  # Everything that is not the open blade is neutral silver.
  # Sampled from the captures: light bands, a mid-grey label box on each,
  # dark grey labels, and the same silver backdrop outside the outermost band.
  silver = {
    tab = [ "cfcfcf" "f1f1f1" "e3e3e3" "c6c6c6" ];
    box = [ "b4b4b4" "c9c9c9" "c4c4c4" "adadad" ];
    label = "5a5a5a";
    gutter = [ "c8c8c8" "eeeeee" "c6c6c6" ];
    rim = "f0f0f0";
  };

  # Controller buttons are always their physical colours.
  buttons = { a = "43b039"; b = "fa3a2f"; x = "1e5c86"; y = "cbd527"; };

  # One shared tempo for every blade move: 350 ms, cubic-bezier(.4,0,.2,1).
  motion = { ms = 350; bezier = "0.4, 0.0, 0.2, 1.0"; points = [ 0.4 0.0 0.2 1.0 ]; };

  # Blade geometry on the console's 1280x720 reference frame, measured off
  # real dashboard captures (Captures/xbox360-examples on the NAS; the
  # 738x414 frames scale by 1.734): collapsed bands ~28 px apart there, the
  # open blade's own tab ~33, the open panel ~513 wide, ~30 px of backdrop
  # outside the outermost band.
  layout = {
    leftStackX = 60;    # backdrop margin before the first band (both sides)
    tabPitch = 48;      # collapsed bands touch: width = pitch
    activeTabWidth = 56;
    panelWidth = 912;   # 1280 - 2*60 - 4*48 - 56: the stacks fill the screen
    headerBottom = 92;  # the darker header band holding the title
    footerHeight = 70;  # ...and the footer band with the legend, at the bottom
    frameMargin = 8;    # the full-width frame around apps and pages
    contentPad = 22;    # menu content inside the card
    gamerCardHeight = 118;
    rowHeight = 44;
    rowSize = 22;
    descSize = 21;
    cardInset = 6;      # content card inside the panel's curved edges
    cardRadius = 30;
    titleInset = 40;
    titleCentre = 50;   # title's vertical centre in the header band
    titleSize = 30;
    footerSize = 19;
    tabLabelSize = 19;
    tabBoxTop = 150;    # the grey label box on each collapsed band...
    tabBoxTopActive = 118;  # ...sits higher on the open blade's tab
    tabBoxStep = 500;   # where the box S-curves back into the band
    tabBoxEnd = 565;
    tabBoxRadius = 14;
    tabBoxInset = 0.35; # fraction of the band left as the light outer strip
  };

  # Every edge — each band and both sides of the open panel — is one smooth,
  # even arc down the whole screen, bowing toward the centre at mid-height by
  # 24 reference px (14 px in the captures): the inside of a cylinder. A
  # parabola sampled every 60 px; Geometry.js and blade.frag interpolate the
  # same knots. Negative = toward the centre for the left stack, which is
  # mirrored (see Geometry.js).
  curve = rec {
    depth = 24;
    y = map (i: i * 60) (lib.range 0 12);
    d = map (yy: let u = (yy - 360) / 360.0; in -depth * (1 - u * u)) y;
  };
}
