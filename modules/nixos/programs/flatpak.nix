# ~/nixos-config/modules/nixos/profiles/flatpak.nix
{ config, pkgs, lib, inputs, ... }:

let
  unoCalculatorId = "uno.platform.uno-calculator";

  # True when the calculator app role is pointed at the Uno Calculator flatpak.
  # Matched on the command rather than a separate option so the role stays the
  # single place the calculator is chosen.
  unoCalculatorEnabled =
    config.customConfig.apps.programs.enable
    && lib.hasInfix unoCalculatorId config.customConfig.apps.programs.calculator.command;
in
{

  imports = [
    inputs.nix-flatpak.nixosModules.nix-flatpak
  ];

  config = lib.mkIf config.customConfig.packages.flatpak.enable {
    # Required to install flatpak
    xdg.portal = {
        enable = true;
        config = {
        common = {
            default = [
            "gtk"
            ];
        };
        };
        extraPortals = with pkgs; [
            xdg-desktop-portal-wlr
            kdePackages.xdg-desktop-portal-kde
            xdg-desktop-portal-gtk
        ];
    };
    
    # install flatpak binary
    services.flatpak.enable = true;
    
    # Add a new remote. Keep the default one (flathub)
    services.flatpak.remotes = lib.mkOptionDefault [{
        name = "flathub-beta";
        location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
    }];

    services.flatpak.update.auto.enable = true;
    services.flatpak.uninstallUnmanaged = false;

    # Add here the flatpaks you want to install
    #
    # The calculator role (customConfig.apps.programs.calculator) launches a
    # Flathub app rather than a nixpkgs package, so it cannot install itself the
    # way the other roles do — system/apps.nix only installs roles that carry a
    # package. Derive it from the role's own command instead of hardcoding it in
    # every host's flatpak list, so pointing the role somewhere else (or setting
    # its command to "") also stops installing this.
    services.flatpak.packages =
      config.customConfig.packages.flatpak.packages
      ++ lib.optional unoCalculatorEnabled "uno.platform.uno-calculator";

    # The Flathub mcpelauncher build exits immediately (255, printing only
    # "SAFE_MODE before exec: (null)") when QT_STYLE_OVERRIDE is set. nixpkgs'
    # own mcpelauncher-ui-qt derivation wraps the binary to unset that variable
    # for exactly this reason; the Flathub build carries no such wrapper.
    #
    # The century-series Hyprland theme exports QT_STYLE_OVERRIDE=adwaita-dark
    # (themes/century-series/hyprland.nix), so every launch from rofi or the app
    # menu inherited it and died, while launching from a sanitised environment
    # worked — which is what made this look like an intermittent failure.
    # Strip it for this one app rather than dropping the session-wide Qt theming.
    services.flatpak.overrides = lib.optionalAttrs
      (builtins.elem "io.mrarm.mcpelauncher" config.customConfig.packages.flatpak.packages)
      {
        "io.mrarm.mcpelauncher" = {
          Environment.QT_STYLE_OVERRIDE = "";
          Context.unset-environment = [ "QT_STYLE_OVERRIDE" ];
        };
      }
    // lib.optionalAttrs unoCalculatorEnabled {
      # Uno Calculator's dark mode comes from a settings.ini that Home Manager
      # writes into the app's own config dir
      # (modules/home-manager/system/uno-calculator.nix). home.file installs it as
      # a *symlink into /nix/store*, and while /nix exists inside the sandbox the
      # store path itself is not exposed — so the app saw a dangling link and fell
      # back to light. Verified by reading the file from inside the sandbox: the
      # symlink lists fine, `cat` fails with ENOENT until the store is readable.
      #
      # Read-only, and the store is world-readable on disk anyway, so this grants
      # no access the app could not already infer.
      "${unoCalculatorId}".Context.filesystems = [ "/nix/store:ro" ];
    };

  };
}
