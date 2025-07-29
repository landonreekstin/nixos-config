# ~/nixos-config/modules/nixos/desktop/cosmic.nix
{ config, pkgs, lib, inputs, ... }:

# Must also import inputs.nixos-cosmic.nixosModules.default in flake host entry.
{
  # ==> Configuration (Applied only if profile is enabled) <==
  config = lib.mkIf config.customConfig.programs.cosmic.enable {

    # Enable COSMIC Desktop Environment itself
    services.desktopManager.cosmic.enable = true;

    # If COSMIC is enabled, force Xserver off, as COSMIC is Wayland-only.
    # mkForce ensures this wins if KDE profile (which might enable Xserver) is also enabled.
    #services.xserver.enable = lib.mkForce false;

    # Add packages useful for COSMIC environment
    environment.systemPackages = with pkgs; [
      networkmanagerapplet # May still be needed depending on cosmic panel features
    ];

  };
}
