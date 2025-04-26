# ~/nixos-config/modules/nixos/desktop/cosmic.nix
{ config, pkgs, lib, inputs, ... }:

{
  # ==> Option Definition <==
  options.profiles.desktop.cosmic.enable = lib.mkEnableOption "COSMIC Desktop Environment profile";

  # ==> Import necessary modules at the top level <==
  imports = [
    # Import the actual COSMIC module definition from the flake input
    inputs.nixos-cosmic.nixosModules.default
  ];

  # ==> Configuration (Applied only if profile is enabled) <==
  config = lib.mkIf config.profiles.desktop.cosmic.enable {

    # Enable COSMIC Desktop Environment itself
    services.desktopManager.cosmic.enable = true;

    # If COSMIC is enabled, force Xserver off, as COSMIC is Wayland-only.
    # mkForce ensures this wins if KDE profile (which might enable Xserver) is also enabled.
    services.xserver.enable = lib.mkForce false;

    # Add packages useful for COSMIC environment
    environment.systemPackages = with pkgs; [
      networkmanagerapplet # May still be needed depending on cosmic panel features
    ];

  };
}
