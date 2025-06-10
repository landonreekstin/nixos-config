# ~/nixos-config/modules/home-manager/common-options.nix
{ lib, pkgs, ... }:
{
  # These are Home Manager options, so they are defined under 'options.hmCustomConfig' (or any name you choose)
  # to distinguish them from NixOS options if needed, or directly if you prefer.
  # Let's use a distinct name for clarity for now: hmCustomConfig
    options.hmCustomConfig = with lib; {
        user = {
            # These names can be the same as your NixOS customConfig options,
            # but they are separate entities.
            name = mkOption { 
                type = types.str; 
                description = "HM: Username for display, git, etc."; 
            };
            email = mkOption { 
                type = types.str; 
                description = "HM: User email for git."; 
            };
            loginName = mkOption { 
                type = types.str; 
                description = "HM: System login name."; 
            };
            homeDirectory = mkOption { 
                type = types.str; 
                description = "HM: Path to home directory."; 
            };
            shell = mkOption { 
                type = types.nullOr types.package; 
                default = pkgs.bash; 
                description = "HM: User's shell."; 
            };
        };
        desktop = mkOption { 
            type = types.str; 
            default = "hyprland"; 
            description = "HM: Desktop environment or window manager."; 
        };
        theme = mkOption { 
            type = types.str; 
            default = "future-aviation"; 
            description = "HM: Theme name."; 
        };
        systemStateVersion = mkOption { 
            type = types.str; 
            default = "24.11"; 
            description = "HM: State version for HM."; 
        };
        packages = mkOption { 
            type = types.listOf types.package; 
            default = []; 
            description = "HM: List of packages."; 
        };
        # Add other HM specific options as needed
        # For example, if your Hyprland HM module needs an enable flag:
        # hyprland.enable = mkOption { type = types.bool; default = false; };
    };
}