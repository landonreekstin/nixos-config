# ../../modules/home-manager/system/xdg.nix
{ config, lib, pkgs, osConfig, customConfig, ... }:

let
  isDesktop = customConfig.desktop.enable;
  apps = customConfig.apps.programs;
  d = customConfig.apps.defaults.${customConfig.apps.defaultSet};

  # Audio types we hand to the audio player, reused by the MIME map and by the
  # elisa-folder desktop entry (which has to advertise them to be a valid handler).
  audioMimes = [
    "audio/mpeg" "audio/ogg" "audio/flac" "audio/x-flac" "audio/x-wav"
    "audio/wav" "audio/aac" "audio/mp4" "audio/x-m4a" "audio/opus"
  ];

  # Elisa's own Exec is "elisa %U", which enqueues *only* the files it is handed.
  # Opening one track from a file manager therefore yields a one-entry playlist
  # and the next/previous buttons do nothing. This wrapper hands Elisa the whole
  # containing directory instead, rotated so the clicked track plays first and
  # "next" walks forward through the folder in name order.
  #
  # elisa is called off PATH on purpose: it comes from plasma6 system-wide on the
  # hosts that select it (defaultSet = "kde"), and a store reference here would
  # drag the whole package into the home-manager closure of hosts that don't.
  elisaFolder = pkgs.writeShellScriptBin "elisa-folder" ''
    set -eu

    target="''${1:-}"
    if [ -z "$target" ]; then exec elisa; fi

    dir="$(${pkgs.coreutils}/bin/dirname -- "$target")"
    base="$(${pkgs.coreutils}/bin/basename -- "$target")"
    cd "$dir" || exec elisa "$target"

    shopt -s nullglob nocaseglob
    siblings=( *.mp3 *.flac *.ogg *.oga *.opus *.m4a *.aac *.wav *.wma *.mpc )
    if [ ''${#siblings[@]} -eq 0 ]; then exec elisa "$target"; fi

    mapfile -t sorted < <(printf '%s\n' "''${siblings[@]}" | LC_ALL=C ${pkgs.coreutils}/bin/sort -V)

    idx=0
    for i in "''${!sorted[@]}"; do
      if [ "''${sorted[$i]}" = "$base" ]; then idx="$i"; break; fi
    done

    exec elisa "''${sorted[@]:$idx}" "''${sorted[@]:0:$idx}"
  '';
in
{
  # Configure XDG user directories (Desktop, Documents, etc.)
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  xdg.enable = true;

  # Fixes KDE screen share
  xdg.portal.extraPortals = osConfig.xdg.portal.extraPortals;

  # Configure XDG Portals.
  #
  # Portal config is resolved PER SESSION: xdg-desktop-portal reads only the
  # first matching file — "<desktop>-portals.conf" (XDG_CURRENT_DESKTOP,
  # lower-cased) and then "portals.conf" — and never merges them. A generic
  # portals.conf written here therefore applies to *every* session and shadows
  # the correct per-desktop configs that Hyprland and plasma-workspace already
  # ship in share/xdg-desktop-portal/.
  #
  # That is what broke screen sharing (Discord/Vesktop/OBS) in KDE sessions:
  # the session got "hyprland;gtk", and since xdg-desktop-portal-hyprland does
  # implement ScreenCast it won the lookup outright — leaving the KDE backend
  # unused and the stream dead, because that backend drives Hyprland's IPC and
  # cannot serve a KWin session. (xdg-desktop-portal only falls back to the
  # deprecated UseIn key when *no* configured backend implements the interface,
  # so the working KDE backend was never considered.)
  # A bare "*" is equally wrong here: it picks implementations in
  # lexicographical order, and "hyprland" sorts before "kde".
  #
  # Mirror the vendor per-desktop configs explicitly so the right backend wins
  # in each session regardless of which DEs are installed side by side.
  xdg.portal.config = {
    # Matches hyprland's own hyprland-portals.conf. The hyprland backend serves
    # ScreenCast/Screenshot/GlobalShortcuts; gtk serves the rest, because gtk's
    # OpenURI respects mimeapps.list and launches the registered default
    # directly, whereas the KDE portal always shows its app-chooser dialog.
    hyprland.default = [ "hyprland" "gtk" ];

    # Matches plasma-workspace's own kde-portals.conf.
    kde = {
      default = [ "kde" ];
      "org.freedesktop.impl.portal.Settings" = [ "kde" "gtk" ];
      "org.freedesktop.impl.portal.Secret" = [ "kwallet" ];
    };

    # Fallback for any session that is neither of the above.
    common.default = [ "*" ];
  };

  # -------------------------------------------------------------------------- #
  # Custom desktop entries for TUI wrapper applications
  # These allow TUI apps (yazi, neovim) to be MIME-associated like GUI apps.
  # -------------------------------------------------------------------------- #
  xdg.desktopEntries = lib.mkIf isDesktop {

    yazi-kitty = {
      name = "Files (Yazi)";
      genericName = "File Manager";
      comment = "Terminal file manager (yazi in kitty)";
      exec = "${apps.terminal.command} --class yazi-kitty -e ${apps.fileManagerTUI.command} %u";
      icon = "system-file-manager";
      terminal = false;
      categories = [ "FileManager" "System" ];
      mimeType = [ "inode/directory" "x-scheme-handler/file" ];
    };

    nvim-kitty = {
      name = "Text Editor (Neovim)";
      genericName = "Text Editor";
      comment = "Neovim text editor in kitty terminal";
      exec = "${apps.terminal.command} --class nvim-kitty -e ${apps.editorTUI.command} %F";
      icon = "text-editor";
      terminal = false;
      categories = [ "TextEditor" "Development" "Utility" ];
      mimeType = [ "text/plain" "text/x-script" "text/x-shellscript" "application/x-shellscript" ];
    };

    # Folder-aware Elisa (see elisaFolder above). NoDisplay keeps it out of the
    # app menus — it is a MIME shim, not a second copy of Elisa to launch by hand.
    elisa-folder = {
      name = "Elisa (folder playlist)";
      genericName = "Music Player";
      comment = "Play an audio file with the rest of its folder queued up";
      exec = "${elisaFolder}/bin/elisa-folder %f";
      icon = "elisa";
      terminal = false;
      noDisplay = true;
      categories = [ "Audio" "Player" "Music" ];
      mimeType = audioMimes;
    };

  };

  # -------------------------------------------------------------------------- #
  # XDG MIME default application associations
  # All values are driven by customConfig.apps.defaults.* options so hosts can
  # override individual categories without touching this module.
  # -------------------------------------------------------------------------- #
  xdg.mimeApps = lib.mkIf isDesktop {
    enable = true;

    defaultApplications = {
      # ── Web browser ─────────────────────────────────────────────────────────
      "text/html"                     = d.browser;
      "x-scheme-handler/http"         = d.browser;
      "x-scheme-handler/https"        = d.browser;
      "x-scheme-handler/ftp"          = d.browser;
      "x-scheme-handler/about"        = d.browser;
      "x-scheme-handler/unknown"      = d.browser;
      "application/xhtml+xml"         = d.browser;
      "application/x-extension-html"  = d.browser;
      "application/x-extension-htm"   = d.browser;

      # ── File manager ────────────────────────────────────────────────────────
      "inode/directory"               = d.fileManager;
      "x-scheme-handler/file"         = d.fileManager;

      # ── Text editor ─────────────────────────────────────────────────────────
      "text/plain"                    = d.textEditor;
      "text/x-script"                 = d.textEditor;
      "text/x-shellscript"            = d.textEditor;
      "application/x-shellscript"     = d.textEditor;

      # ── Code editor ─────────────────────────────────────────────────────────
      "text/x-python"                 = d.codeEditor;
      "text/x-csrc"                   = d.codeEditor;
      "text/x-c++src"                 = d.codeEditor;
      "text/x-java"                   = d.codeEditor;
      "text/x-rust"                   = d.codeEditor;
      "text/javascript"               = d.codeEditor;
      "application/json"              = d.codeEditor;
      "application/x-yaml"            = d.codeEditor;
      "application/toml"              = d.codeEditor;

      # ── Image viewer ────────────────────────────────────────────────────────
      "image/jpeg"                    = d.imageViewer;
      "image/png"                     = d.imageViewer;
      "image/gif"                     = d.imageViewer;
      "image/webp"                    = d.imageViewer;
      "image/bmp"                     = d.imageViewer;
      "image/tiff"                    = d.imageViewer;
      "image/svg+xml"                 = d.imageViewer;
      "image/avif"                    = d.imageViewer;
      "image/x-xcf"                   = d.imageViewer;
      # iPhone photos. shared-mime-info maps *.heic, *.heif and *.hif all onto
      # image/heif, so this single entry covers the lot. Without it the type fell
      # through to the desktop database, which picked Okular's kimgio catch-all —
      # every phone photo opened in the PDF reader.
      "image/heif"                    = d.imageViewer;

      # ── Video player ────────────────────────────────────────────────────────
      "video/mp4"                     = d.videoPlayer;
      "video/x-matroska"              = d.videoPlayer;
      "video/webm"                    = d.videoPlayer;
      "video/x-msvideo"               = d.videoPlayer;
      "video/mpeg"                    = d.videoPlayer;
      "video/quicktime"               = d.videoPlayer;
      "video/x-flv"                   = d.videoPlayer;
      "video/3gpp"                    = d.videoPlayer;
      "video/ogg"                     = d.videoPlayer;

      # ── Audio player ────────────────────────────────────────────────────────
      # (merged in below from audioMimes, which the elisa-folder entry shares)

      # ── PDF reader ──────────────────────────────────────────────────────────
      "application/pdf"               = d.pdfReader;
      "application/x-pdf"             = d.pdfReader;

      # ── Archive manager ─────────────────────────────────────────────────────
      "application/zip"               = d.archiveManager;
      "application/x-tar"             = d.archiveManager;
      "application/gzip"              = d.archiveManager;
      "application/x-bzip2"           = d.archiveManager;
      "application/x-xz"              = d.archiveManager;
      "application/x-7z-compressed"   = d.archiveManager;
      "application/x-rar"             = d.archiveManager;
      "application/x-rar-compressed"  = d.archiveManager;
      "application/vnd.rar"           = d.archiveManager;

      # ── Torrent client ──────────────────────────────────────────────────────
      "application/x-bittorrent"      = d.torrentClient;
      "x-scheme-handler/magnet"       = d.torrentClient;

    } // lib.genAttrs audioMimes (_: d.audioPlayer)
      // lib.optionalAttrs (d.emailClient != null) {
      # ── Email client (optional — skipped when emailClient is null) ──────────
      "x-scheme-handler/mailto"       = d.emailClient;
      "message/rfc822"                = d.emailClient;
    };

    # Mirror every default into [Added Associations]. A handler does not always
    # claim every type we point at it — Elisa's own MimeType advertises
    # audio/x-flac but not audio/flac — and an entry in [Default Applications]
    # that the .desktop itself does not declare is ignored by some
    # implementations. Declaring the association keeps the two in step.
    # (read back post-coercion, so the values are already listOf str)
    associations.added = config.xdg.mimeApps.defaultApplications;
  };
}
