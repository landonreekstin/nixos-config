# ~/nixos-config/modules/home-manager/development/vibe-projects.nix
{ lib, pkgs, config, customConfig, ... }:

let
  cfg = customConfig.programs.vibeProjects;

  userName = customConfig.user.name;
  configDir = "${config.home.homeDirectory}/nixos-config";
  projectsDir = cfg.dir;
  userDirenv = "/etc/profiles/per-user/${userName}/bin/direnv";
  shellList = lib.concatStringsSep ", " cfg.shells;

  # THE rules for any Claude session in a vibe project, and the reason they live one
  # directory ABOVE the projects: Claude Code collects CLAUDE.md from the working
  # directory upwards, so a file here is loaded for every project, on every session —
  # including the ones started with `claude -c` and `claude -r`, which carry no prompt at
  # all. Putting them in each project's own CLAUDE.md instead would mean a resumed session
  # got whatever copy was frozen into it the day it was created.
  #
  # It is a store symlink, so it is re-asserted on every rebuild and a session cannot
  # rewrite it. That immutability is the point: an Edit against it failing is correct.
  rulesText = ''
    # Working on an app in ${projectsDir}

    These rules apply to every Claude session whose working directory is a project under
    `${projectsDir}`. They are managed by the NixOS config and cannot be edited from here.
    Each project also has its own `CLAUDE.md` describing that specific app.

    ## Who you are working with

    ${userName} is not a technical user. He does not know Nix, Linux, or how to program.

    - **You make every technical decision.** Never ask him to pick a programming language,
      a library, a file layout, or anything else technical. Decide, then say in one short
      sentence what you did.
    - **He decides what the app does and what it looks like.** Ask him about that, in plain
      English, and keep asking as the app grows. If a choice is about appearance or
      behaviour, it is his.
    - **Never ask him to run a command you can run yourself.**
    - Never use a technical word without explaining it in one short sentence.
    - Give next steps as one plain instruction, e.g. "Click the green button and tell me
      what happens".
    - For bugs: diagnose and fix, then give him something specific to check.

    ## The project repo is his — commit to main freely

    Each project folder is a git repository that belongs to him, and it has **no remote**.

    - Commit to `main` as often as makes sense. No branches, no PRs, no reviews.
    - **Never add a remote and never push.** His code stays on this machine.
    - Commit messages: short, plain English. No Co-Authored-By or AI attribution lines.
    - Commit before you start something risky, so there is always a working version to go
      back to. Nothing here is backed up anywhere, so an uncommitted mistake is just gone.

    ## The NixOS config is NOT his — it still needs a PR

    The machine itself is configured in `${configDir}`, which is lando's repo and is shared
    with other machines. Those rules are unchanged and are not negotiable:

    - Work on a branch whose name starts with `blaney/`. **Never commit or push to `main`**,
      and never merge a `blaney/` branch anywhere.
    - Open a PR with `gh pr create` and **stop**. Lando merges it; you never do.
    - Full rules: `${configDir}/docs/hosts/blaney-pc.md`. Background on this kind of
      project: `${configDir}/docs/hosts/blaney-vibe-projects.md`.

    Better still, **do not go into the config from a project session at all.** If the app
    needs something from the system, finish what you can here and tell him in one sentence
    to close this and run `ccn` instead — that opens Claude in the config folder, where the
    config rules are the ones loaded.

    ## Running commands

    The tools for each app come from a shared dev shell in the config repo. Run anything
    that needs them through it explicitly:

    ```
    nix develop ${configDir}#vibe-python --command python main.py
    ```

    Use the shell named on the `shell=` line of the project's `.vibe-project`. The
    available ones are: ${shellList}.

    **Never put `sudo` in front of that.** This session is already root, and a second,
    nested `sudo` resets `SUDO_UID` to 0, which makes nix refuse to read the config repo:

    ```
    repository path ... is not owned by current user (libgit2 error code = 7)
    ```

    Plain `git` in the project works for the same underlying reason — git accepts a repo
    owned by `SUDO_UID` when running as root — so it also must never be wrapped in `sudo`.

    If that `nix develop` instead fails with

    ```
    error: flake ... does not provide attribute 'devShells.x86_64-linux.vibe-python', ...
    ```

    then his config checkout is sitting on an older branch that predates this feature (he
    switches branches with `branch-switch`). **Do not try to fix the config.** Tell him, in
    one sentence, to close this and run `update`, then start the app again.

    ## File ownership

    This session runs as root, so files you create start out owned by root and ${userName}
    cannot edit or run them. A hook chowns `${projectsDir}` when the session ends and after
    file edits, but not after a command that builds something. Before you hand anything
    over for him to try:

    ```
    chown -R ${userName}:users ${projectsDir}
    ```

    ## direnv

    After writing or changing a project's `.envrc`, allow it **as him** — the allow-hash is
    per-user, and his direnv lives in his own profile:

    ```
    sudo -u ${userName} -H ${userDirenv} allow .
    ```

    That is only so that *his* terminal loads the tools when he cd's in. You do not need it.

    ## When the app is finished

    Making it run like any other app on his system is a change to the config repo, so it
    does not happen here. Tell him, in one sentence: close this, open a terminal, run `ccn`,
    and say "package my <name> app from ${projectsDir}/<folder> as a real app". That reuses
    the normal `blaney/`-branch-and-PR path with the right rules loaded.

    ## Other things to know

    - This machine reaches **GitHub and the internet only**. There is no access to the
      homelab, the NAS, or anything on lando's LAN. Do not write steps that need them.
    - If a project needs a library the dev shell does not have, do **not** install it
      system-wide and do not fight it with pip or npm. Prefer something the shell already
      covers; if that is impossible, say so and point him at `ccn`.
    - Keep anything long in the project's `docs/` folder, and keep its `CLAUDE.md` current.
      A future session starts by reading them.
  '';

  readmeText = ''
    # Your apps

    This is where the apps you build live. Each folder in here is one app.

    To start a new one, or to carry on with one you already started, open a terminal and
    type:

        vibe

    It gives you a numbered list — pick a number and Claude opens on that app.

    Don't rename or move the folders in here by hand: `vibe` finds your apps by looking for
    a small `.vibe-project` file inside each one, and Claude's saved chats are remembered
    per folder name.

    `CLAUDE.md` in this folder is the set of rules Claude follows while working on your
    apps. It is managed by your system config, so it comes back on every rebuild.
  '';
in
{
  config = lib.mkIf cfg.enable {
    # home.file creates ~/projects itself, so there is no activation script here. Note
    # these are store symlinks, NOT the writeIfChanged pattern from ./emulation.nix —
    # that helper exists only because rewriting an unchanged .envrc invalidates direnv's
    # allow hash, and neither of these files has one.
    #
    # The per-project .envrc is deliberately NOT managed here. It is chosen by the session
    # that picks the app's language and is committed to his own repo, so home-manager must
    # not own or re-assert it.
    home.file = {
      "${baseNameOf projectsDir}/CLAUDE.md".source =
        pkgs.writeText "vibe-projects-CLAUDE.md" rulesText;
      "${baseNameOf projectsDir}/README.md".source =
        pkgs.writeText "vibe-projects-README.md" readmeText;
    };
  };
}
