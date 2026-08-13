# ~/nixos-config/modules/nixos/apps/xdg-defaults.nix
{ lib, ... }:

# Desktop-file names for XDG MIME associations, consumed by
# modules/home-manager/system/xdg.nix. A separate concern from apps/programs.nix:
# that one holds launch commands for keybinds, this one holds which application
# a file type opens with.
{
  options.customConfig.apps = with lib; {
    # Selects which DE's default app preset feeds into xdg.mimeApps.
    # "hyprland" = TUI-first defaults (yazi, neovim, imv, zathura, mpv).
    # "kde"      = GUI-native defaults (dolphin, kate, gwenview, okular, ark).
    # Individual apps within each set can be overridden per-host via
    # apps.defaults.<set>.<app> = "something.desktop".
    defaultSet = mkOption {
      type = types.enum [ "hyprland" "kde" ];
      default = "hyprland";
      description = ''
        Which desktop environment's default app preset to use for XDG MIME
        associations. Set to "kde" for KDE-primary hosts.
      '';
    };

    # Desktop file names for XDG MIME default application associations.
    # These are used in xdg.mimeApps.defaultApplications (e.g. "librewolf.desktop").
    # Separate from customConfig.desktop.hyprland.applications.* which hold launch commands for keybinds.
    defaults = {

      hyprland = {
        browser = mkOption {
          type = types.str;
          default = "librewolf.desktop";
          description = "Default browser for Hyprland hosts.";
          example = "firefox.desktop";
        };
        terminal = mkOption {
          type = types.str;
          default = "kitty.desktop";
          description = "Default terminal for Hyprland hosts.";
        };
        fileManager = mkOption {
          type = types.str;
          default = "yazi-kitty.desktop";
          description = "Default file manager for Hyprland hosts (TUI wrapper).";
          example = "org.kde.dolphin.desktop";
        };
        textEditor = mkOption {
          type = types.str;
          default = "nvim-kitty.desktop";
          description = "Default text editor for Hyprland hosts (TUI wrapper).";
          example = "org.kde.kate.desktop";
        };
        codeEditor = mkOption {
          type = types.str;
          default = "code.desktop";
          description = "Default code editor for Hyprland hosts.";
        };
        imageViewer = mkOption {
          type = types.str;
          default = "imv.desktop";
          description = "Default image viewer for Hyprland hosts.";
        };
        videoPlayer = mkOption {
          type = types.str;
          default = "mpv.desktop";
          description = "Default video player for Hyprland hosts.";
        };
        audioPlayer = mkOption {
          type = types.str;
          default = "mpv.desktop";
          description = "Default audio player for Hyprland hosts.";
        };
        pdfReader = mkOption {
          type = types.str;
          default = "org.pwmt.zathura.desktop";
          description = "Default PDF reader for Hyprland hosts.";
          example = "okular.desktop";
        };
        archiveManager = mkOption {
          type = types.str;
          default = "org.gnome.FileRoller.desktop";
          description = "Default archive manager for Hyprland hosts.";
          example = "ark.desktop";
        };
        emailClient = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Default email client for Hyprland hosts. null disables mailto association.";
          example = "thunderbird.desktop";
        };
        torrentClient = mkOption {
          type = types.str;
          default = "org.qbittorrent.qBittorrent.desktop";
          description = "Default torrent client for Hyprland hosts.";
        };
      };

      kde = {
        browser = mkOption {
          type = types.str;
          default = "librewolf.desktop";
          description = "Default browser for KDE hosts.";
          example = "firefox.desktop";
        };
        terminal = mkOption {
          type = types.str;
          default = "org.kde.konsole.desktop";
          description = "Default terminal for KDE hosts.";
        };
        fileManager = mkOption {
          type = types.str;
          default = "org.kde.dolphin.desktop";
          description = "Default file manager for KDE hosts.";
        };
        textEditor = mkOption {
          type = types.str;
          default = "org.kde.kate.desktop";
          description = "Default text editor for KDE hosts.";
        };
        codeEditor = mkOption {
          type = types.str;
          default = "code.desktop";
          description = "Default code editor for KDE hosts.";
        };
        imageViewer = mkOption {
          type = types.str;
          default = "org.kde.gwenview.desktop";
          description = "Default image viewer for KDE hosts.";
        };
        videoPlayer = mkOption {
          type = types.str;
          default = "mpv.desktop";
          description = "Default video player for KDE hosts.";
          example = "vlc.desktop";
        };
        audioPlayer = mkOption {
          type = types.str;
          default = "mpv.desktop";
          description = "Default audio player for KDE hosts.";
          example = "vlc.desktop";
        };
        pdfReader = mkOption {
          type = types.str;
          default = "okularApplication_pdf.desktop";
          description = "Default PDF reader for KDE hosts.";
        };
        archiveManager = mkOption {
          type = types.str;
          default = "ark.desktop";
          description = "Default archive manager for KDE hosts.";
        };
        emailClient = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Default email client for KDE hosts. null disables mailto association.";
          example = "thunderbird.desktop";
        };
        torrentClient = mkOption {
          type = types.str;
          default = "org.qbittorrent.qBittorrent.desktop";
          description = "Default torrent client for KDE hosts.";
        };
      };

    };
  };
}
