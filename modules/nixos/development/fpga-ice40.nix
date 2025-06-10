# ~/nixos-config/modules/nixos/development/fpga-ice40.nix
{ config, pkgs, lib, ... }: # Ensure pkgs is available here
{
  config = lib.mkIf config.customConfig.profiles.development.fpga-ice40.enable {
    environment.systemPackages = with pkgs; [
      yosys
      nextpnrWithGui # Use the specific ICE40 target
      icestorm
      iverilog
    ];
  };
}