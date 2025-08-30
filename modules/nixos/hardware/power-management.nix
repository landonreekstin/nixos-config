# ~/nixos-config/modules/nixos/hardware/power-management.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.hardware.powerManagement;

in
{
  config = lib.mkIf cfg.enable {
    
    # Lid close function
    services.logind = {
      lidSwitch = "hybrid-sleep";
      lidSwitchExternalPower = "lock";
      lidSwitchDocked = "ignore";
    };

    # CPU overheating limiter
    services.thermald.enable = true;

    # Linux battery optimizer
    services.tlp = {
      enable = cfg.tlp.enable;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 100;
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 20;
        # Optional helps save long term battery health
        START_CHARGE_THRESH_BAT0 = 40;
        # 40 and bellow it starts to charge
        STOP_CHARGE_THRESH_BAT0 = 90;
        # 80 and above it stops charging
        };
      };
  };
}