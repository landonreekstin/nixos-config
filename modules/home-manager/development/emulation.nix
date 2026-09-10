# ~/nixos-config/modules/home-manager/development/emulation.nix
{ lib, config, customConfig, ... }:

let
  cfg = customConfig.profiles.development.emulation;
  dir = "${config.home.homeDirectory}/emulation";

  envrcContent = ''
    # Managed by your NixOS config. Activates the emulation workspace dev shell.
    use flake ~/nixos-config#emulation
    export DEV_ENV_NAME="emulation"
  '';

  # Write a real file, not a home.file symlink into the store: direnv needs to
  # be able to update the timestamp, and rewriting an unchanged .envrc would
  # invalidate its `direnv allow` hash and force a re-allow.
  writeIfChanged = path: content: ''
    content=${lib.escapeShellArg content}
    if [ ! -f "${path}" ] || [ "$(cat "${path}")" != "$content" ]; then
      [ -L "${path}" ] && rm "${path}"
      printf '%s' "$content" > "${path}"
    fi
  '';
in
{
  config = lib.mkIf cfg.enable {
    # ~/emulation is an existing git repo with its own content; mkdir -p is
    # harmless and nothing here touches anything but .envrc.
    home.activation.createEmulationEnvrc = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${dir}"

      ${writeIfChanged "${dir}/.envrc" envrcContent}
    '';
  };
}
