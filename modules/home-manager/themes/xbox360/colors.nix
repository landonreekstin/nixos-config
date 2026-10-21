# ~/nixos-config/modules/home-manager/themes/xbox360/colors.nix
# Blade palette of the 2005 Xbox 360 "Blades" dashboard. Plain data, imported by
# the Hyprland settings here and (later) by the Quickshell shell, so the two
# cannot drift.
#
# Source: the researched palette in DESIGN.md §2 of
# David-Lazaro-Fernandez/Audio-Visualizer (the same pinned commit the assets come
# from — pkgs/xbox360-assets). Not yet cross-checked against console captures;
# if a blade reads wrong against a real screenshot, fix it here.
{ }:

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
      title = "Xbox Live";
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
  silver = {
    tab = [ "a9a9a9" "fbfbfb" "dcdcdc" "b6b6b6" ];
    label = "7d7d7d";
    gutter = [ "c9c9c9" "ececec" "c4c4c4" ];
    rim = "f0f0f0";
  };

  # Controller buttons are always their physical colours.
  buttons = { a = "43b039"; b = "fa3a2f"; x = "1e5c86"; y = "cbd527"; };

  # One shared tempo for every blade move: 350 ms, cubic-bezier(.4,0,.2,1).
  motion = { ms = 350; bezier = "0.4, 0.0, 0.2, 1.0"; points = [ 0.4 0.0 0.2 1.0 ]; };

  # Blade geometry on the console's 1280x720 reference frame (DESIGN.md §1).
  layout = {
    leftStackX = 152;   # left edge of the first tab
    tabWidth = 44;
    tabPitch = 48;      # tab width + the 4 px gap
    panelWidth = 708;   # the open blade, on every blade
    contentTop = 26;    # top of the title band
    headerBottom = 84;  # windows tile below this
    footerHeight = 30;  # ...and above this
    titleInset = 30;
    titleSize = 34;
    statusSize = 20;
    tabLabelSize = 20;
  };

  # The "lazy S" every edge follows: x offset per y stop, at 90% of the
  # reference bow/flare. Geometry.js and blade.frag both interpolate these.
  curve = {
    y = [ 0 130 250 380 510 625 720 ];
    d = map (v: v * 0.9) [ 0 (-13) (-19) (-13) (-7) 30 85 ];
  };
}
