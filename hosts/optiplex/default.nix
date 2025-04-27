# ~/nixos-config/hosts/optiplex/default.nix
{ config, pkgs, inputs, lib, ... }:

{
  imports =
    [
      # Hardware configuration specific to this host
      ./hardware-configuration.nix

      # Core system configuration (users, nix settings, locale, etc.)
      ../../modules/nixos/core.nix

      # Desktop Environment
      ../../modules/nixos/desktop/cosmic.nix
      ../../modules/nixos/desktop/hyprland.nix
      ../../modules/nixos/desktop/display-manager.nix

      # Hardware Modules (GPU, etc.)
      ../../modules/nixos/hardware/nvidia.nix
      # Add other hardware modules if needed (e.g., intel-graphics.nix)

      # Service Modules
      ../../modules/nixos/services/networking.nix
      ../../modules/nixos/services/pipewire.nix
      ../../modules/nixos/services/ssh.nix

      # vscode server for remote ssh
      inputs.nixos-vscode-server.nixosModules.default

      # Profile Modules (placeholder concept for later)
      # ../../modules/nixos/profiles/development.nix
      ../../modules/nixos/profiles/gaming.nix
    ];

  # ==> Enable Desktop Profiles for this Host <==
  profiles.desktop.cosmic.enable = true;
  profiles.desktop.hyprland.enable = true;

  # ==> Select Display Manager for this Host <==
  # profiles.desktop.displayManager = "cosmic";
  profiles.desktop.displayManager = "none"; # Alternative if cosmic-greeter fails

  # ==> Enable greetd <==
  services.greetd = {
    enable = true;
    # Settings will be configured below
  };

  # If using the default 'breeze' theme for SDDM, add plasma-workspace
  environment.systemPackages = [ 
    pkgs.greetd.greetd # The greetd daemon itself
    pkgs.greetd.regreet # The graphical greeter application
    pkgs.sddm-sugar-dark
  ];
  
  environment.etc."greetd/hyprland-greeter.conf" = {
    # Target path: /etc/greetd/hyprland-greeter.conf
    # Source from text block:
    text = ''
      # Minimal Hyprland config for greetd + regreet

      # Monitors (Copy from your main config, ensure rotation)
      monitor=HDMI-A-3,1920x1080,0x0,1,transform,1
      monitor=HDMI-A-1,preferred,1080x0,1
      monitor=HDMI-A-4,1920x1080,0x0,1,transform,1
      monitor=HDMI-A-2,preferred,1080x0,1

      # Environment variables needed by regreet/wayland
      env = XCURSOR_SIZE,24
      env = QT_QPA_PLATFORMTHEME,qt6ct # Or qt5ct if regreet uses Qt5

      # Minimal input settings (no custom binds needed here)
      input {
          kb_layout = us
          follow_mouse = 1
      }

      # Basic appearance (no gaps, simple border)
      general {
          border_size = 1
          col.active_border = rgba(ffffff66) # Simple white border
          col.inactive_border = rgba(595959aa)
          layout = dwindle
      }
      decoration {
          rounding = 0
          drop_shadow = no
          blur { enabled = false }
      }
      animations { enabled = false } # No animations needed for greeter

      # Execute ReGreet ONCE
      # Need full path to regreet package
      exec-once = ${pkgs.greetd.regreet}/bin/regreet

      # Minimal misc settings
      misc {
        disable_hyprland_logo = true
        force_default_wallpaper = -1
      }

      # NO user keybindings needed here
    ''; # End text block
  }; # End environment.etc

  # ==> Configure greetd settings <==
  services.greetd.settings = {
    # Define the default session (the command greetd runs)
    default_session = {
       # Command launches Hyprland using the specific greeter config
       command = ''
         ${pkgs.hyprland}/bin/Hyprland -c /etc/greetd/hyprland-greeter.conf
       '';
       user = "greeter"; # Run Hyprland (and thus regreet) as 'greeter' user
    };
  };

  # ==> Host Specific Settings <==
  networking.hostName = "optiplex"; # Set the hostname for this specific machine

  # Set the state version for this host based on its initial install
  system.stateVersion = "24.11";

  # Enable vscode server for remote ssh
  services.vscode-server.enable = true; # Enable the service from the module
  programs.nix-ld.enable = true;      # Enable the nix-ld wrapper environment
  programs.nix-ld.libraries = with pkgs; [ # Add common libraries often needed by downloaded binaries
      stdenv.cc.cc.lib
      zlib
      # Add others here if vscode server specifically complains later
  ];

  # You could override module settings here if needed for this specific host
  # For example:
  # services.openssh.settings.PermitRootLogin = "yes"; # (Don't actually do this!)

  # ==> Home Manager Configuration for this Host <==
  home-manager = {
    useGlobalPkgs = true; # Use system's nixpkgs for Home Manager packages
    useUserPackages = true; # Allow Home Manager to manage packages in user profile
    backupFileExtension = "hm-backup"; # Backup existing dotfiles
    
    # Define users managed by Home Manager on this host
    users = {
      # Manage the 'lando' user
      lando = { pkgs, config, lib, inputs, ... }: {
        imports = [
          ./home.nix
        ];
      };
    };
    
    extraSpecialArgs = { inherit inputs; };

  };

  # Nixpkgs configuration specific to this host (if any)
  nixpkgs.config = {
    allowUnfree = true; # Moved from the main config, applied via nvidia module now
  };

}
