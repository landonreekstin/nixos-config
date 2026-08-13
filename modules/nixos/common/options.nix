# ~/nixos-config/modules/nixos/common/options.nix
{ lib, pkgs, config, ... }:

# Cross-cutting options with no single owning module. bootloader, networking and
# homeManager are declared by the modules implementing them; user, system and
# packages are each read by several common modules at once (users-groups,
# sudo-password, commands, auto-update, internationalisation, base-environment,
# programs/flatpak), so no one of them owns the namespace.

let

  colorMap = {
    "black" = "0;30"; "red" = "0;31"; "green" = "0;32"; "yellow" = "0;33";
    "blue" = "0;34"; "magenta" = "0;35"; "cyan" = "0;36"; "white" = "0;37";
    "bright-black" = "1;30"; "bright-red" = "1;31"; "bright-green" = "1;32";
    "bright-yellow" = "1;33"; "bright-blue" = "1;34"; "bright-magenta" = "1;35";
    "bright-cyan" = "1;36"; "bright-white" = "1;37";
  };

in
{
  options.customConfig = with lib; {
    user = {
      name = mkOption {
        type = types.str;
        description = "The primary username for this host.";
        example = "landon";
      };
      email = mkOption {
        type = types.str;
        description = "The email for using git.";
        example = "example@gmail.com";
      };
      home = mkOption {
        type = types.str;
        # Default home directory path based on the username.
        default = "/home/${config.customConfig.user.name}"; # Accesses another option within customConfig
        defaultText = literalExpression ''"/home/''${config.customConfig.user.name}"'';
        description = "The absolute path to the primary user's home directory.";
      };
      shell = {
        bash = {
          enable = mkOption {
            type = types.bool;
            default = true; # Default to true if bash is the chosen shell
            description = "Whether to configure bash as the user's shell.";
          };
          color = mkOption {
            type = types.enum (attrNames colorMap);
            default = "green";
            description = "The color name for the bash prompt.";
            example = "blue";
          };
          pkg = mkOption {
            type = types.package;
            default = pkgs.bash; # Default to bash from pkgs
            description = "The shell package to use for the user.";
          };
        };
      };
      updateCmdPermission = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to allow the user to run the custom update/upgrade commands.";
      };
      sudoPassword = mkOption {
        type = types.bool;
        default = false;
        description = "Enable a separate, stronger password for sudo authentication, managed via a secondary password file.";
      };
      sopsPassword = mkOption {
        type = types.bool;
        default = false;
        description = "Manage user (and optionally root) password hashes via SOPS secrets instead of imperative chpasswd. Requires secrets/<hostname>.yaml to contain user-password-hash (and root-password-hash if sudoPassword is also enabled).";
      };
    };
    system = {
      hostName = mkOption {
        type = types.str;
        description = "The hostname for this system (e.g., 'optiplex', 'gaming-pc').";
        example = "my-nixos-pc";
      };
      stateVersion = mkOption {
        type = types.str;
        default = "24.11"; # Set your preferred default NixOS state version.
        description = "NixOS system state version from first install. DO NOT CHANGE EVEN AFTER SYSTEM UPGRADE.";
      };
      timeZone = mkOption {
        type = types.nullOr types.str;
        default = "America/Chicago"; # Example, choose your timezone
        description = "The system's timezone, e.g., 'Europe/Berlin', 'America/Los_Angeles'.";
        example = "UTC";
      };
      locale = mkOption {
        type = types.nullOr types.str;
        default = "en_US.UTF-8";
        description = "The system's primary locale.";
      };
      betaTesterHost = mkOption {
        type = types.bool;
        default = false;
        description = "When true, the sync command follows the latest open update/* branch instead of main.";
      };
    };
    packages = {
      nixos = mkOption { # System-wide packages
        type = with types; listOf package;
        default = [];
        description = "List of additional system-wide packages to install via NixOS configuration.";
        example = "with pkgs; [ htop vim ]"; # For documentation
      };
      unstable-override = mkOption {
        type = with types; listOf str;
        default = [];
        description = "List of package attribute names to pull from the unstable channel.";
        example = ''[ "discord-canary" "obs-studio" "vscode" ]'';
      };
      homeManager = mkOption { # User-specific packages
        type = with types; listOf package;
        default = [];
        description = "List of additional user-specific packages to install via Home Manager.";
        example = "with pkgs; [ cowsay neofetch ]";
      };
      flatpak = {
        enable = mkOption {
          type = types.bool;
          default = false; # Default to false, enable explicitly for Flatpak support
          description = "Enable Flatpak packages for Spotify and Discord.";
        };
        packages = mkOption {
          type = with lib.types; listOf str;
          default = [];
          description = "List of Flatpak packages to install if flatpak is enabled.";
          example = "[ { appId = \"com.brave.Browser\"; origin = \"flathub\"; }
            \"com.obsproject.Studio\"
            \"im.riot.Riot\"
            \"com.spotify.Client\"
            \"com.discordapp.Discord\" 
          ]";
        };
      };
    };
  };
}
