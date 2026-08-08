# ~/nixos-config/modules/home-manager/themes/windows7-xfce/mimeapps.nix
{ config, pkgs, lib, customConfig, ... }:

# XFCE-session default applications: opening a file in an XFCE session launches the themed
# Win7 apps (Thunar/Mousepad/Ristretto/Parole/Xreader/xarchiver) instead of the host's KDE
# or Hyprland defaults.
#
# Scoping: XDG reads ~/.config/<desktop>-mimeapps.list *before* the generic mimeapps.list,
# but ONLY when XDG_CURRENT_DESKTOP matches. The XFCE session sets XDG_CURRENT_DESKTOP=XFCE,
# so xfce-mimeapps.list applies to XFCE sessions alone — KDE/Hyprland sessions never read it,
# so their associations (set by modules/home-manager/system/xdg.nix → mimeapps.list) are
# untouched. Types NOT listed here fall through to that generic file, so we deliberately only
# override the categories that should differ in XFCE (files/text/image/media/pdf/archive) and
# let browser, code editor, email, torrent, etc. inherit the host's existing defaults.
# Thunar/exo-open resolve defaults via GLib GIO, which implements this desktop-specific spec.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  # mimetype → desktop-file id. Same category key lists as xdg.nix, restricted to the
  # categories XFCE should own.
  assoc = lib.listToAttrs (lib.concatMap (grp: map (t: lib.nameValuePair t grp.app) grp.types) [
    { app = "thunar.desktop";            types = [ "inode/directory" "x-scheme-handler/file" ]; }
    { app = "org.xfce.mousepad.desktop"; types = [ "text/plain" "text/x-script" "text/x-shellscript" "application/x-shellscript" ]; }
    { app = "org.xfce.ristretto.desktop"; types = [ "image/jpeg" "image/png" "image/gif" "image/webp" "image/bmp" "image/tiff" "image/svg+xml" "image/avif" ]; }
    { app = "org.xfce.Parole.desktop";   types = [ "video/mp4" "video/x-matroska" "video/webm" "video/x-msvideo" "video/mpeg" "video/quicktime" "video/x-flv" "video/3gpp" "video/ogg"
                                                    "audio/mpeg" "audio/ogg" "audio/flac" "audio/x-wav" "audio/wav" "audio/aac" "audio/mp4" "audio/x-m4a" "audio/opus" ]; }
    { app = "xreader.desktop";           types = [ "application/pdf" "application/x-pdf" ]; }
    { app = "xarchiver.desktop";         types = [ "application/zip" "application/x-tar" "application/gzip" "application/x-bzip2" "application/x-xz" "application/x-7z-compressed" "application/x-rar" "application/x-rar-compressed" "application/vnd.rar" ]; }
  ]);

  defaultApps = lib.concatStrings
    (lib.mapAttrsToList (mime: desktop: "${mime}=${desktop}\n") assoc);

  xfceMimeapps = ''
    [Default Applications]
    ${defaultApps}'';
in {
  config = lib.mkIf win7XfceCondition {
    xdg.configFile."xfce-mimeapps.list".text = xfceMimeapps;
  };
}
