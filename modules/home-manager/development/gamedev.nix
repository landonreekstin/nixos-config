# ~/nixos-config/modules/home-manager/development/gamedev.nix
{ lib, config, customConfig, ... }:

let
  cfg = customConfig.profiles.development.gamedev;
  dir = "${config.home.homeDirectory}/gamedev";

  envrcContent = ''
    # Managed by your NixOS config. Activates the gamedev dev shell.
    use flake ~/nixos-config#gamedev
    export DEV_ENV_NAME="gamedev"
  '';

  # Rules every project session inherits: Claude Code collects CLAUDE.md from the
  # working directory upwards, so this reaches ~/gamedev/<project> too.
  workspaceClaudeMd = ''
    # Game-dev workspace

    *Managed by nixos-config (modules/home-manager/development/gamedev.nix).
    Edits here are overwritten on rebuild — change the module instead.*

    Each subdirectory is one game, created with `gd new <name>` and opened with
    `gd <name>`. `gd` is what loads the skills: it starts Claude with the gamedev plugin
    and the engines on PATH. A plain `claude` started here has neither — if the
    `gamedev:router` skill is missing, say so and ask the user to relaunch through `gd`.

    ## Shared projects (lando's repos that Blaney works on too)

    ${lib.concatStringsSep ", " (lib.mapAttrsToList (n: p: "`${n}` (github.com/${p.repo})") cfg.sharedProjects)}.
    `gd` clones one on first open. The rules for working in one are in the
    "Working together: git and PRs" section of the project's own `CLAUDE.md`, and they are
    binding. In short:
    - lando may commit to `main`. Bigger or riskier work goes on a `feat/`, `fix/` or
      `tweak/` branch with a PR, as in the NixOS config.
    - Blaney works only on `blaney/` branches through PRs. His clone has hooks that refuse
      `main`. Merge his PRs only when lando asks, and only after the branch has been run
      and played: `gh pr checkout <n>`, `make test`, play it, then `gh pr merge <n> --merge`.
    - Start every session with `git fetch` and a look at the open PRs.
    - Verify before you commit: tests pass **and** the game has been run and looked at.
      Messages are `type(scope): description`, with no Co-Authored-By or AI attribution
      lines.
    - Push and use `gh` over HTTPS through gh's login. The clone's credential helper is
      `gh auth git-credential`.

  '' + import ./gamedev-rules.nix {
    runGameRule = ''
      - Run the game as yourself; it is our own code. For a real window on the desktop,
        tell the user the command rather than starting one behind their back.'';
    missingToolRule = ''
      Missing a tool? It belongs in
      `~/nixos-config/modules/nixos/development/gamedev.nix`.'';
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
    home.activation.createGamedevWorkspace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${dir}"

      ${writeIfChanged "${dir}/.envrc" envrcContent}
      ${writeIfChanged "${dir}/CLAUDE.md" workspaceClaudeMd}
    '';
  };
}
