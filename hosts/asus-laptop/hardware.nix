# ~/nixos-config/hosts/asus-laptop/hardware.nix
{ config, pkgs, lib, ... }:

{
  customConfig.hardware = {
    unstable = false; # Older hardware — use stable 6.12 LTS kernel + stable NVIDIA
    nvidia = {
      enable = true;
      laptop = {
        enable = true;
        amdgpuID = "PCI:4:0:0";
        nvidiaID = "PCI:1:0:0";
      };
    };
    display.backlight.enable = true;
    kbdBacklight.enable = true;
    battery.enable = true;
    wifi.waybar.enable = true;  # Roaming host — WiFi picker in the Hyprland bar
  };

  services.keyd = {
    enable = true;
    keyboards = {
      # This name comes from your keyd monitor output
      "Asus Keyboard" = {
        ids = [ "*" ]; # Match any ID for this named device

        # 'settings' is the correct option that builds the .conf file.
        # This block will generate a config file with a [main] section.
        settings = {
          main = {
            # This line creates the entry 'f4 = minus' inside the [main] section.
            f9 = "minus";
          };
        };
      };
    };
  };
}
