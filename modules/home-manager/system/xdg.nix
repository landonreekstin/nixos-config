# ../../modules/home-manager/system/xdg.nix
{ config, lib, pkgs, osConfig, customConfig, ... }:

let
  isDesktop = customConfig.desktop.enable;
  d = customConfig.apps.defaults.${customConfig.apps.defaultSet};
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

  # Configure XDG Portals
  xdg.portal.config.common.default = "*";

  # -------------------------------------------------------------------------- #
  # Custom desktop entries for TUI wrapper applications
  # These allow TUI apps (yazi, neovim) to be MIME-associated like GUI apps.
  # -------------------------------------------------------------------------- #
  xdg.desktopEntries = lib.mkIf isDesktop {

    yazi-kitty = {
      name = "Files (Yazi)";
      genericName = "File Manager";
      comment = "Terminal file manager (yazi in kitty)";
      exec = "${pkgs.kitty}/bin/kitty --class yazi-kitty -e ${pkgs.yazi}/bin/yazi %u";
      icon = "system-file-manager";
      terminal = false;
      categories = [ "FileManager" "System" ];
      mimeType = [ "inode/directory" "x-scheme-handler/file" ];
    };

    nvim-kitty = {
      name = "Text Editor (Neovim)";
      genericName = "Text Editor";
      comment = "Neovim text editor in kitty terminal";
      exec = "${pkgs.kitty}/bin/kitty --class nvim-kitty -e ${pkgs.neovim}/bin/nvim %F";
      icon = "text-editor";
      terminal = false;
      categories = [ "TextEditor" "Development" "Utility" ];
      mimeType = [ "text/plain" "text/x-script" "text/x-shellscript" "application/x-shellscript" ];
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
      "audio/mpeg"                    = d.audioPlayer;
      "audio/ogg"                     = d.audioPlayer;
      "audio/flac"                    = d.audioPlayer;
      "audio/x-wav"                   = d.audioPlayer;
      "audio/wav"                     = d.audioPlayer;
      "audio/aac"                     = d.audioPlayer;
      "audio/mp4"                     = d.audioPlayer;
      "audio/x-m4a"                   = d.audioPlayer;
      "audio/opus"                    = d.audioPlayer;

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

    } // lib.optionalAttrs (d.emailClient != null) {
      # ── Email client (optional — skipped when emailClient is null) ──────────
      "x-scheme-handler/mailto"       = d.emailClient;
      "message/rfc822"                = d.emailClient;
    };
  };
}
