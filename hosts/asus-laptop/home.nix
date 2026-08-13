# ~/nixos-config/hosts/asus-laptop/home.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

{
  customConfig.homeManager = {
    enable = true;
    themes = {
      kde = "none";
      hyprland = "century-series";
    };
  };

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {
      # Override optiplex-fw SSH hostname for VPN (full-tunnel WireGuard routes all
      # traffic through the tunnel, so we must use the WireGuard VPN IP, not the LAN IP)
      programs.ssh.matchBlocks."optiplex-fw".hostname = lib.mkForce "10.10.0.1";
      programs.ssh.matchBlocks."gaming-pc".hostname = lib.mkForce "gaming-pc";
    };
  };
}
