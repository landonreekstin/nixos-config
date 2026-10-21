# ~/nixos-config/modules/home-manager/themes/xbox360/menus.nix
# What each blade's menu holds — plain data, rendered by shell/BladeMenu.qml.
# Apps come from customConfig.apps.programs, so a host without a role simply
# has no row for it (rows whose command is empty are dropped).
#
# A row is { label; icon; desc; action; } where action is one of
#   { type = "launch"; cmd; title; }  — run on a fresh app workspace
#   { type = "page"; page; title; }   — open a full-screen page (Config.pages)
{ lib, apps, pkgs, downloadsUrl, jellyfinUrl, jellyfinApp }:

let
  cmd = role: apps.${role}.command or "";
  has = role: cmd role != "";
  terminal = cmd "terminal";

  # "firefox" -> "Firefox", "/nix/store/...-chromium/bin/chromium" -> "Chromium"
  prettyName = c:
    let
      exe = baseNameOf (lib.head (lib.splitString " " c));
      bare = lib.removePrefix "." exe;
    in
    lib.toUpper (lib.substring 0 1 bare) + lib.substring 1 (-1) bare;

  launch = title: c: { type = "launch"; cmd = c; inherit title; };
  inTerminal = title: c: launch title "${terminal} -e ${c}";
  page = page: title: { type = "page"; inherit page title; };

  row = label: icon: desc: action: { inherit label icon desc action; };
  roleRow = role: label: icon: desc:
    lib.optional (has role) (row label icon desc (launch label (cmd role)));
in
[
  # ---- Marketplace: keeping this console up to date -------------------------
  ([
    (row "System Update" "system-software-update"
      "Is this console up to date? See where its configuration stands and the weekly update, then update, rebuild, or update and turn off."
      (page "updates" "System Update"))
  ] ++ lib.optional (downloadsUrl != null)
    (row "Downloads" "folder-download"
      "See what the media server is downloading, and how far along it is."
      (page "downloads" "Downloads")))

  # ---- Xbox LIVE: the web --------------------------------------------------
  (lib.optional (has "browser")
    (row (prettyName (cmd "browser")) "internet-web-browser"
      "Browse the web."
      (launch (prettyName (cmd "browser")) (cmd "browser")))
  ++ lib.optional (has "browserAlt")
    (row (prettyName (cmd "browserAlt")) "web-browser"
      "Browse the web in your other browser."
      (launch (prettyName (cmd "browserAlt")) (cmd "browserAlt")))
  ++ lib.optional (has "browser")
    (row "YouTube" "youtube"
      "Watch YouTube."
      (launch "YouTube" "${cmd "browser"} --new-window https://www.youtube.com")))

  # ---- Games ---------------------------------------------------------------
  (lib.optionals (has "gaming" || has "gamingAlt") [
    (row "Games Library" "applications-games"
      "Every game on this console, from Steam and Heroic, with the ones you played last at the top."
      (page "games" "My Games"))
    (row "Last Played Game" "media-playback-start"
      "Jump straight back into the game you played last."
      { type = "lastPlayed"; })
  ]
  ++ lib.optional (has "gaming")
    (row "Steam Big Picture" "steam"
      "Steam's own controller interface: your whole library, the store and friends."
      (launch "Steam" "${cmd "gaming"} steam://open/bigpicture"))
  ++ lib.optional (has "gaming")
    (row "Steam" "steam"
      "The Steam client."
      (launch "Steam" (cmd "gaming")))
  ++ roleRow "gamingAlt" (prettyName (cmd "gamingAlt")) "applications-games"
      "Your other game launcher.")

  # ---- Media ---------------------------------------------------------------
  (roleRow "music" "Music" "spotify-client"
      "Play music with Spotify."
  ++ lib.optional jellyfinApp
    (row "Jellyfin" "org.jellyfin.JellyfinDesktop"
      "The full Jellyfin app in its TV mode: music libraries, live TV and everything else on the server."
      (launch "Jellyfin" "jellyfin-desktop --tv --fullscreen"))
  ++ lib.optional (has "fileManager")
    (row "Pictures" "folder-pictures"
      "Show your pictures."
      (launch "Pictures" "${cmd "fileManager"} $HOME/Pictures"))
  ++ (if jellyfinUrl != null then [
    (row "Videos" "folder-videos"
      "Movies and shows from your media server. Pick up where you left off."
      (page "videos" "Videos"))
  ] else lib.optional (has "fileManager")
    (row "Videos" "folder-videos"
      "Your own video files."
      (launch "Videos" "${cmd "fileManager"} $HOME/Videos")))
  ++ lib.optional (has "audioVisualizer")
    (row "Visualizer" "audio-x-generic"
      "Watch the music."
      (inTerminal "Visualizer" (cmd "audioVisualizer"))))

  # ---- System --------------------------------------------------------------
  (roleRow "fileManager" "File Manager" "system-file-manager"
      "Browse the files on this console and on the network."
  ++ lib.optional (has "terminal")
    (row "Terminal" "utilities-terminal"
      "A command line."
      (launch "Terminal" terminal))
  ++ lib.optional (has "taskManager")
    (row "Task Manager" "utilities-system-monitor"
      "See what is running and how hard the console is working."
      (inTerminal "Task Manager" (cmd "taskManager")))
  ++ [
    (row "Audio" "audio-volume-high"
      "Speakers, headphones and microphones: choose outputs and set levels."
      (launch "Audio" "${pkgs.pavucontrol}/bin/pavucontrol"))
    (row "Bluetooth" "bluetooth"
      "Pair headsets and controllers."
      (launch "Bluetooth" "${pkgs.blueman}/bin/blueman-manager"))
    (row "Network" "network-wired"
      "Wired, wireless and VPN connections."
      (launch "Network" "${pkgs.networkmanagerapplet}/bin/nm-connection-editor"))
  ])
]
