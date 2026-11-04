# ~/nixos-config/modules/home-manager/development/reverse-engineering.nix
{ lib, config, customConfig, ... }:

let
  cfg = customConfig.profiles.development.reverse-engineering;
  dir = "${config.home.homeDirectory}/reverse-engineering";

  envrcContent = ''
    # Managed by your NixOS config. Activates the reverse-engineering dev shell.
    use flake ~/nixos-config#reverse-engineering
    export DEV_ENV_NAME="reverse-engineering"
  '';

  # Rules every project session inherits: Claude Code collects CLAUDE.md from the
  # working directory upwards, so this reaches ~/reverse-engineering/<project> too.
  workspaceClaudeMd = ''
    # Reverse-engineering workspace

    *Managed by nixos-config (modules/home-manager/development/reverse-engineering.nix).
    Edits here are overwritten on rebuild — change the module instead.*

    Each subdirectory is one project, created with `re new <name>`. The `.envrc` here
    (direnv) loads the reverse-engineering dev shell, whose `claude` wrapper starts Claude
    with the REA plugin (MCP server + `reverse-engineer-anything` skill), with the
    recompilation toolchains on PATH. If REA's tools are missing, the session was started
    outside that shell: say so and ask the user to `cd` into the project (`direnv allow`
    if prompted) and start `claude` again, rather than running `rea setup`.

  '' + import ./reverse-engineering-rules.nix {
    runTargetRule = ''
      - Analysed binaries may be hostile. Don't run a target outside a test you set up
        on purpose, and never with sudo.'';
    missingToolRule = ''
      Missing a tool? It
      belongs in `~/nixos-config/modules/nixos/development/reverse-engineering.nix`.'';
  };

  # Real files, not home.file symlinks into the store: direnv needs to update the
  # .envrc timestamp, and rewriting an unchanged .envrc would force a re-allow.
  writeIfChanged = path: content: ''
    content=${lib.escapeShellArg content}
    if [ ! -f "${path}" ] || [ "$(cat "${path}")" != "$content" ]; then
      [ -L "${path}" ] && rm "${path}"
      printf '%s' "$content" > "${path}"
    fi
  '';
in
{
  config = lib.mkIf (cfg.enable && cfg.workspace.enable) {
    home.activation.createReverseEngineeringWorkspace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${dir}"

      ${writeIfChanged "${dir}/.envrc" envrcContent}
      ${writeIfChanged "${dir}/CLAUDE.md" workspaceClaudeMd}
    '';
  };
}
