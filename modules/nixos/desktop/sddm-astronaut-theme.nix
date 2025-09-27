# ~/nixos-config/modules/nixos/desktop/sddm-astronaut-theme.nix
{ config, pkgs, lib, ... }:

let
  # --- Option References ---
  # Reference to the main display manager settings
  dmCfg = config.customConfig.desktop.displayManager;
  # Reference to the new, nested SDDM-specific settings
  sddmCfg = dmCfg.sddm;

  # --- Conditions ---
  # Condition to enable the sddm-astronaut *theme*.
  # This now reads from the new option path.
  sddmAstronautThemeEnabled = (dmCfg.enable)
                            && (dmCfg.type == "sddm")
                            && (sddmCfg.theme == "sddm-astronaut");

  # Condition to enable the *screensaver* feature.
  # This reads from the new `screensaver.enable` boolean.
  sddmScreensaverEnabled = sddmAstronautThemeEnabled && sddmCfg.screensaver.enable;

  # --- Package Definition ---
  # Your custom package definition, using the new `embeddedTheme` option path.
  sddm-astronaut-custom = pkgs.sddm-astronaut.override {
    embeddedTheme = sddmCfg.embeddedTheme;
  };
in
{
  config = lib.mkIf sddmAstronautThemeEnabled {
    # === Part 1: SDDM Theming Configuration ===
    # This part is always active if the theme is set to "sddm-astronaut".
    services.displayManager.sddm = {
      #package = pkgs.kdePackages.sddm;
      theme = "sddm-astronaut-theme";
      #settings = {
      #  Theme = {
      #    Current = "sddm-astronaut-theme";
      #  };
      #};
      extraPackages = with pkgs; [
        sddm-astronaut-custom
        kdePackages.qtmultimedia # For video backgrounds
        kdePackages.qtsvg        # For SVG icons and elements
        # qtvirtualkeyboard is often needed for the on-screen keyboard in the theme
        kdePackages.qtvirtualkeyboard
      ];
    };
    environment.systemPackages = with pkgs; [
      sddm-astronaut-custom
    ];

    # === Part 2: SDDM Screensaver Logic ===
    # This block is now controlled by the new `screensaver.enable` option.
    services.xserver.xautolock = lib.mkIf sddmScreensaverEnabled {
      enable = true;
      # Use the new `timeout` option.
      time = sddmCfg.screensaver.timeout;
      # The locker command remains the same, pointing to our custom theme.
      locker = ''
        ${pkgs.kdePackages.sddm}/bin/sddm-greeter-qt6 \
          --test-mode \
          --theme ${sddm-astronaut-custom}/share/sddm/themes/sddm-astronaut-theme
      '';
    };
  };
}