# In ~/nixos-config/modules/nixos/desktop/kde.nix
{ config, pkgs, lib, inputs, ... }:

{
  options.customConfig.desktop.kde = with lib; {
    kwallet = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable KWallet for credential storage. Required for plasma-nm to persist WiFi passwords across sessions. Pairs with SDDM PAM auto-unlock so no wallet password prompt appears at login.";
      };
    };
    terminalApp = mkOption {
      type = types.str;
      default = "org.kde.konsole";
      description = ''
        Desktop file ID of the terminal emulator to bind to Meta+Return in KDE.
        Use the application ID without the .desktop extension
        (e.g. "org.kde.konsole", "com.raggesilver.BlackBox").
      '';
      example = "com.raggesilver.BlackBox";
    };
  };

  config = lib.mkIf (lib.elem "kde" config.customConfig.desktop.environments) {

    security.pam.services.sddm.kwallet.enable =
      config.customConfig.desktop.kde.kwallet.enable;

    services.desktopManager.plasma6.enable = true;

    xdg.portal = {
      enable = true;

      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        kdePackages.xdg-desktop-portal-kde
        xdg-desktop-portal-hyprland
      ];
      xdgOpenUsePortal = true;
    };

    # The KDE *applications* (konsole, gwenview, okular, ark, elisa, kcalc,
    # partitionmanager, the Dolphin companions) are NOT here: they live in
    # modules/nixos/apps/kde-suite.nix so a host can keep them without running
    # Plasma. Only the session's own portal backend belongs to this module.
    environment.systemPackages = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
    ];

    services.pipewire = {
      enable = true;
      wireplumber.enable = true;
      pulse.enable = true;
    };

    programs.xwayland.enable = true;
  };
}
