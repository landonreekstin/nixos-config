# ~/nixos-config/modules/home-manager/themes/century-series/wallpapers.nix
# Pure Nix file — import with:
#   import ./wallpapers.nix { inherit lib customConfig; homeDir = config.home.homeDirectory; }
#
# The century-series wallpaper hierarchy, in two sets, plus the per-monitor
# assignment it generates. Two consumers:
#   hyprland.nix   — feeds the DAY set to hyprpaper (when that is still the
#                    engine) and links the image files into ~/.local/share.
#   night-mode.nix — needs BOTH sets so the ramp can hand the right one to
#                    `awww img` at a day/night switch.
#
# The night set mirrors the day set slot for slot, so every monitor keeps its
# character across the switch: the hero airframe stays on primary, the cockpit
# shot stays on secondary, portraits stay portrait.
{ lib, customConfig, homeDir, ... }:

let
  dir = homeDir + "/.local/share/wallpapers";

  day = {
    # Primary wallpapers (main displays)
    primary-horizontal = dir + "/f-15-satellite.jpg";
    primary-vertical = dir + "/carrier-top.jpg";

    # Secondary wallpapers (additional displays)
    secondary-horizontal = dir + "/f-4-cockpit.png";
    secondary-vertical = dir + "/carrier-top.jpg";

    # Tertiary wallpapers (for systems with 3+ displays)
    tertiary-horizontal = dir + "/f-4-cockpit.png";
    tertiary-vertical = dir + "/carrier-top.jpg";

    fallback = dir + "/f-15-satellite.jpg";
  };

  # Night mission: F-117 pair at sunset on the hero display, a red-lit night
  # cockpit on the secondary, a Eurofighter vertical climb on the portraits.
  night = {
    primary-horizontal = dir + "/f-117-sunset.jpg";
    primary-vertical = dir + "/eurofighter-night-vertical.jpg";

    secondary-horizontal = dir + "/cockpit-night.jpg";
    secondary-vertical = dir + "/eurofighter-night-vertical.jpg";

    tertiary-horizontal = dir + "/cockpit-night.jpg";
    tertiary-vertical = dir + "/eurofighter-night-vertical.jpg";

    fallback = dir + "/f-117-sunset.jpg";
  };

  # A monitor is vertical when it is rotated (transform 1 or 3).
  isVertical = m: m.transform == "1" || m.transform == "3";

  categorizeMonitors = monitors:
    let
      enabledMonitors = lib.filter (m: m.enabled) monitors;
    in {
      horizontal = lib.filter (m: !(isVertical m)) enabledMonitors;
      vertical = lib.filter isVertical enabledMonitors;
      total = enabledMonitors;
    };

  assignWallpaper = set: index: orientation:
    let
      key =
        if index == 0 then "primary-${orientation}"
        else if index == 1 then "secondary-${orientation}"
        else "tertiary-${orientation}";
    in set.${key} or set.fallback;

  # hyprpaper matches a monitor by connector name, or by `desc:<description>`
  # when the identifier looks like a description (contains a space or a dot).
  identifierOf = m:
    if lib.strings.hasPrefix "desc:" m.identifier then m.identifier
    else if (lib.strings.hasInfix " " m.identifier) || (lib.strings.hasInfix "." m.identifier)
    then "desc:${m.identifier}"
    else m.identifier;

  generateWallpaperAssignments = set: monitors:
    let
      categorized = categorizeMonitors monitors;
      mk = orientation: lib.imap0 (i: m: {
        monitor = identifierOf m;
        path = assignWallpaper set i orientation;
      });
    in (mk "horizontal" categorized.horizontal) ++ (mk "vertical" categorized.vertical);

  assignmentsFor = set:
    if (lib.length customConfig.desktop.monitors) > 0
    then generateWallpaperAssignments set customConfig.desktop.monitors
    else [ { monitor = ""; path = set.fallback; } ]; # Single monitor fallback

in {
  inherit day night;

  # Determine wallpaper assignments.
  #
  # hyprpaper 0.8.0 was a complete rewrite onto hyprtoolkit and, in upstream's
  # own words, "configs are broken and much simplified". The old
  # `preload = <path>` + `wallpaper = <monitor>,<path>` pair is gone; there is now
  # a `wallpaper { monitor = ...; path = ...; }` block per monitor and no preload
  # concept at all. 0.8.4 does not warn about the old keys — it parses the file,
  # finds no wallpaper blocks, logs "Monitor X has no target: no wp will be
  # created" and shows nothing, which is exactly how this presented after the
  # 26.05 upgrade. 0.8.4 also dropped the IPC socket entirely, which is why
  # night mode needs awww instead.
  dayAssignments = assignmentsFor day;
  nightAssignments = assignmentsFor night;
}
