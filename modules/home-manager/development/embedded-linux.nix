# ~/nixos-config/modules/home-manager/development/embedded-linux.nix
{ lib, pkgs, customConfig, ... }: # Note: We now take `customConfig` as an argument

let
  # Correctly check if the NixOS profile is enabled using the passed-in `customConfig`.
  cfg = customConfig.profiles.development.embedded-linux;

  # Correctly define the user's home directory path at the Nix level.
  embeddedDir = "${customConfig.user.home}/embedded-linux";
in
{
  config = lib.mkIf cfg.enable {
    # This adds a string to the end of your .bashrc file.
    programs.bash.initExtra = ''
      # --- Managed by NixOS: embedded-linux dev environment setup ---
      if [ ! -f "${embeddedDir}/.envrc" ]; then
        echo "Creating initial .envrc for unified embedded development..."
        mkdir -p "${embeddedDir}"
        echo "# Managed by your NixOS config. Activates the unified embedded dev shell." > "${embeddedDir}/.envrc"
        echo "use flake ~/nixos-config#embedded-linux" >> "${embeddedDir}/.envrc"
      fi
    '';
  };
}