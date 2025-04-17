# ~/nixos-config/modules/nixos/desktop/cosmic.nix
{ config, pkgs, lib, inputs, ... }: # Needs inputs for the import

{
  imports = [
    # Import the actual COSMIC module definition from the flake input
    inputs.nixos-cosmic.nixosModules.default
  ];

  # Enable COSMIC Desktop Environment and Greeter
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  # Ensure conflicting services are disabled
  services.xserver.enable = false;

  # Add packages useful for COSMIC environment
  environment.systemPackages = with pkgs; [
    networkmanagerapplet # May still be needed depending on cosmic panel features
  ];
}
