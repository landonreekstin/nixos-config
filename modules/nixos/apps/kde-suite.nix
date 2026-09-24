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
    ];

    # KDE Partition Manager, via its own module rather than the bare package: the
    # package alone is inert, because kpmcore's D-Bus service and polkit action come
    # from programs.partition-manager (services.dbus.packages + kpmcore in
    # systemPackages) and without them the helper cannot be launched.
    programs.partition-manager.enable = true;
  };
}
