# ~/nixos-config/modules/nixos/apps/kde-suite.nix
{ config, pkgs, lib, ... }:

# The KDE applications that apps/xdg-defaults.nix's "kde" preset names as MIME
# defaults — gwenview, okular, ark, elisa, konsole — plus the standalone Qt
# utilities that used to come with the desktop.
#
# Until now nothing installed any of these. They arrived as a side effect of
# services.desktopManager.plasma6.enable, which puts them in systemPackages via
# nixpkgs' own "optionalPackages" list. That made apps.defaultSet = "kde" a
# hidden dependency on the whole Plasma session: drop "kde" from
# desktop.environments and every image, PDF, archive and audio file silently
# resolves to a .desktop that is no longer installed, in *every* session on the
# host (the generic ~/.config/mimeapps.list is not desktop-scoped).
#
# This module is what installs them, independent of whether Plasma is enabled,
# so a host can keep the KDE app set and its file associations while running
# Hyprland and XFCE only. That is what gaming-pc and blaney-pc do.
#
# It also carries the Qt/KF6 runtime plugins those apps need when Plasma is not
# there to load them — see the "Runtime plumbing" block below, which is what makes
# the difference between the apps being installed and the apps actually working.
#
# Deliberately NOT here: systemsettings, plasma-systemmonitor, kinfocenter,
# kmenuedit, spectacle. Those are Plasma-session control surfaces with nothing
# to configure outside one — XFCE pins xfce4-settings-manager / xfce4-taskmanager
# and Hyprland screenshots with grim+slurp.

let
  cfg = config.customConfig.apps.kdeSuite;
in
{
  options.customConfig.apps.kdeSuite = with lib; {
    enable = mkOption {
      type = types.bool;
      default = config.customConfig.apps.defaultSet == "kde"
             || lib.elem "kde" config.customConfig.desktop.environments;
      defaultText = literalExpression ''
        config.customConfig.apps.defaultSet == "kde"
        || lib.elem "kde" config.customConfig.desktop.environments
      '';
      description = ''
        Install the KDE application set (konsole, gwenview, okular, ark, elisa,
        kcalc, partitionmanager and the Dolphin companions), independent of
        whether Plasma itself is enabled.

        Defaults to on wherever apps.defaultSet = "kde" (that preset points the
        XDG MIME defaults at exactly these applications) and on any host that
        still runs Plasma, where plasma6 would have installed most of them
        anyway — so turning KDE off never silently removes an application.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs.kdePackages; [
      # Named by apps.defaults.kde.* in apps/xdg-defaults.nix.
      konsole        # defaults.kde.terminal
      gwenview       # defaults.kde.imageViewer
      okular         # defaults.kde.pdfReader
      ark            # defaults.kde.archiveManager
      elisa          # defaults.kde.audioPlayer, via the elisa-folder wrapper in
                     # modules/home-manager/system/xdg.nix, which calls `elisa`
                     # off PATH on purpose.

      # Standalone Qt utility that came with the desktop and is useful without it.
      kcalc

      # Dolphin is the fileManager app role (modules/nixos/apps/programs.nix), so
      # it is installed either way — but its thumbnailers, service menus and the
      # Baloo metadata panel are separate packages that plasma6 pulled in.
      dolphin-plugins
      baloo-widgets
      ffmpegthumbs
      kio-extras

      # ── Runtime plumbing ────────────────────────────────────────────────────
      #
      # The applications above are useless on their own. plasma6 also put this list in
      # systemPackages (nixpkgs' own `requiredPackages`), so dropping "kde" took it away
      # and broke three visible things at once — every one of them a missing Qt/KF6
      # plugin rather than a missing program:
      #
      #   * `lib/qt-6/plugins/platformthemes` went empty, so KDE apps stopped reading
      #     ~/.config/kdeglobals and fell back to the default LIGHT Fusion palette. The
      #     file itself was never touched and still held the dark scheme.
      #   * `lib/qt-6/plugins/imageformats` went empty, so Gwenview refused .heic and
      #     said outright that kimageformats was missing.
      #   * `libexec/kf6/kioworker` disappeared, so every out-of-process KIO protocol
      #     died — smb://, sftp://, mtp://, fish:// — and Dolphin could not open the NAS
      #     share even though kio-extras' smb.so was installed and the share answered
      #     smbclient fine.
      plasma-integration   # KDEPlasmaPlatformTheme6.so — what reads kdeglobals
      breeze               # breeze6.so widget style + the Breeze colour schemes
      breeze-icons
      kimageformats        # kimg_heif.so, kimg_avif.so, kimg_jxl.so, kimg_psd.so, …
      kio                  # libexec/kf6/kioworker — the KIO protocol launcher
      kservice             # kbuildsycoca6, which the ksycoca MIME lookups depend on
      kded                 # hosts the KDE background services (smbwatcher etc)
      solid                # backs Dolphin's Places/Devices panel
      kiconthemes
      frameworkintegration
      qqc2-desktop-style
    ] ++ (with pkgs.qt6; [
      qtimageformats  # webp/tiff/icns — not part of kdePackages

      # qtbase carries two more platformthemes that plasma6 was pulling in and that
      # nothing else here provides: libqxdgdesktopportal.so (Qt file dialogs going
      # through the XDG portal) and libqgtk3.so (Qt apps following the GTK theme,
      # which is what the windows7 XFCE session wants them to do).
      qtbase
      qtwayland
      qtsvg
    ]);

    # THE load-bearing line. nixpkgs' own description: "Enabling this option is necessary
    # for Qt plugins to work in the installed profiles (e.g. environment.systemPackages)".
    # It is what exports QT_PLUGIN_PATH/QML2_IMPORT_PATH pointing at the profiles, and
    # plasma6 was the only thing setting it. Without it every package listed above is
    # installed but INVISIBLE to Qt, which is why dropping KDE produced a light Dolphin
    # (no platformthemes plugin -> kdeglobals never read) and a Gwenview that could not
    # open .heic (no imageformats plugin) even though both files were on disk.
    #
    # platformTheme/style are deliberately left null, exactly as plasma6 had them: the
    # session picks the theme (century-series sets QT_QPA_PLATFORMTHEME in Hyprland), and
    # forcing one here would also reach into the XFCE session's Qt apps.
    qt.enable = true;

    # kioworker lives in libexec/kf6/, and NixOS does not link /libexec into the system
    # profile by default. plasma6 added it here (with a FIXME saying modules should not
    # have to), so removing Plasma emptied /run/current-system/sw/libexec entirely and
    # took the KIO worker launcher with it.
    environment.pathsToLink = [ "/libexec" ];

    # KDE Partition Manager, via its own module rather than the bare package: the
    # package alone is inert, because kpmcore's D-Bus service and polkit action come
    # from programs.partition-manager (services.dbus.packages + kpmcore in
    # systemPackages) and without them the helper cannot be launched.
    programs.partition-manager.enable = true;
  };
}
