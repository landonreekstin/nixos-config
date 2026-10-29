# ~/nixos-config/modules/home-manager/development/vibe-projects.nix
{ lib, pkgs, config, customConfig, ... }:

let
  gladePanel = import ../hyprland/desktops/glade/claude-panel.nix { inherit pkgs; };
  cfg = customConfig.programs.vibeProjects;

  userName = customConfig.user.name;
  configDir = "${config.home.homeDirectory}/nixos-config";
  projectsDir = cfg.dir;
  userDirenv = "/etc/profiles/per-user/${userName}/bin/direnv";
  shellList = lib.concatStringsSep ", " cfg.shells;
  reEnabled = customConfig.profiles.development.reverse-engineering.enable;
  gdEnabled = customConfig.profiles.development.gamedev.enable;

  # Rules for the game projects `vibe` offers where the gamedev profile is on. Same file
  # and same reasoning as reRulesText below; the body is shared with lando's ~/gamedev
  # workspace. It is emitted BEFORE the reverse-engineering section, because that one
  # claims everything to the end of the file.
  gameRulesText = ''

    ## Game projects (`kind=game` in `.vibe-project`)

    This section applies **only** to projects whose `.vibe-project` has `kind=game`. In
    those, ${userName} is making a game of his own. Everything above still applies; this
    adds to it.

    - **`vibe` opened this session with the game tools loaded**: the `gamedev` skills
      plugin and every engine below on PATH. Ignore "Running commands" above for these —
      no `nix develop`, just run `godot`, `love`, `python3`, `npm` directly. If the
      `gamedev:router` skill is missing, tell him in one sentence to close this and open
      the game again through `vibe`.
    - **He decides what the game is**: what you do in it, how it looks and sounds, how hard
      it is, what counts as winning. Ask him about those in plain English, a couple of
      short questions at a time. You decide the engine and everything technical — pick
      Godot unless there is a real reason not to, and don't ask him.
    - Build the smallest thing he can play first, then grow it one change at a time, each
      one played by him before the next.
    - **Playtesting is his job, and the best feedback you will get.** After each change,
      put the game on his screen (below) and tell him exactly what to try: "Press the
      arrow keys to move, Space to jump — does the jump feel too floaty?" Ask how it
      *feels*, not whether the code is right.
    - Art and sound: draw simple shapes or pixel art in code, or make it with the tools
      below. Don't download assets from the internet unless he asks, and then only ones
      whose licence lets him use them, recorded in `docs/credits.md`.

    ### Games shared with lando (`shared=` in `.vibe-project`)

    A game whose `.vibe-project` has a `shared=owner/repo` line (prin-rpg) is **lando's
    repo**, which he works on too. `vibe` cloned it and added it to the menu. There, the
    project's own `CLAUDE.md` section "Working together: git and PRs" is binding, and it
    **replaces** two rules above: "The project repo is his — commit to main freely" and
    "Where his app's code is allowed to live".
    - Every change goes on a `blaney/` branch and into a PR (`gh pr create --base main`),
      and then you **stop**. Lando merges it. **Never commit to `main`, push to `main`, or
      merge anything.** The clone's git hooks refuse it; never use `--no-verify`.
    - Start every session, a resumed one included, with that section's "Every session,
      before anything else" steps. Lando's PR comments come first.
    - Push and use `gh` **as him**, after the `chown` from "File ownership": his GitHub
      login is `cblaney00`, and this session's root may not have one.
      `sudo -u ${userName} -H git push -u origin <branch>` and
      `sudo -u ${userName} -H gh pr create ...`.
    - **His look-and-feel calls are what he brings to it, so none may get lost.** Whenever
      he says how something should look, sound or feel, playtest remarks included ("the
      trees are too dark"), log it in the project's `docs/style.md` direction log, in his
      words, and update its "current style" in the same commit. Read `docs/style.md`
      before changing anything he will see, and tell him when a request goes against it
      so he can decide. The project's `CLAUDE.md` ("Look and feel") has the details.
    - Its code stays in that repo. It never moves to his account or into the NixOS config.
    - Everything else in this game section still applies: play it on his screen, verify
      before you commit.

    The rest of this section, down to the end-of-section line, is the same text lando's
    own game workspace uses.

  '' + import ./gamedev-rules.nix {
    runGameRule = ''
      - **To let him play, put it on his screen as him**, from the project folder, after the
        `chown` from "File ownership" above: `play-on-desktop ${userName} godot --path .`
        (or `love .`, `python3 main.py`, ...). It borrows his desktop session and starts
        the game detached, so this chat keeps going. Never start the game as root on his
        screen any other way.'';
    missingToolRule = ''
      If a tool is missing, do not install anything; tell him in one sentence to close
      this, run `vibe` and choose "Change or fix something on your
      computer" to ask for it.'';
  } + ''

    *(End of the game-projects section.)*
  '';

  # Rules for the reverse-engineering projects `vibe` offers where the REA profile is on.
  # They live in this same file rather than one of their own because this is the file
  # parent discovery is already proven to load, on every session including `-c`/`-r`.
  # The body after the vibe-specific part is shared with lando's ~/reverse-engineering
  # workspace, so the two never drift apart.
  reRulesText = ''

    ## Reverse-engineering projects (`kind=re` in `.vibe-project`)

    This section applies **only** to projects whose `.vibe-project` has `kind=re`. In
    those, ${userName} is taking an existing program or game apart to see how it works,
    change it, or rebuild it. Everything above still applies; this adds to it.

    - **`vibe` opened this session with REA loaded**: its MCP tools and the
      `reverse-engineer-anything` skill, plus every tool listed below on PATH. Do not use
      `nix develop` for them, and do not run `rea setup`. If REA's tools are missing, tell
      him in one sentence to close this and open the project again through `vibe`.
    - **He decides what to look at and what the result should do or look like.** You
      decide how. Explain what you find in plain English — what a piece of the program
      does, not its addresses and registers — and keep the technical detail in `notes/`.
    - The original program goes in `target/`, which is gitignored. **Never commit it**:
      it is someone else's code. Copy it there yourself when he tells you where it is.
    - Everything in this project is still committed to `main` freely, like an app.

    Everything from here to the end of this file is about reverse-engineering projects
    only.

  '' + import ./reverse-engineering-rules.nix {
    runTargetRule = ''
      - **Never run a target as root.** This session is root, and the program being
        taken apart may be hostile. Run every target — and `wine`, `mame`, or a test of
        the reconstruction — as him: `runuser -u ${userName} -- <command>`. Prefer
        reading the code to running it, and never run something outside a test you set up
        on purpose.'';
    missingToolRule = ''
      If a tool is missing, do not install anything; tell him in one sentence to close
      this, run `vibe` and choose "Change or fix something on your
      computer" to ask for it.'';
  };

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
    ${gladePanel.vibeRules}
    ## The project repo is his — commit to main freely

    Each project folder is a git repository that belongs to him.

    - Commit to `main` as often as makes sense. No branches, no PRs, no reviews.
    - Commit messages: short, plain English. No Co-Authored-By or AI attribution lines.
    - Commit before you start something risky, so there is always a working version to go
      back to. A project with no GitHub repo is not backed up anywhere, so an uncommitted
      mistake is just gone.

    ## Where his app's code is allowed to live

    His app's source code — anything that is not Nix — lives in exactly one of two places:

    1. **Only on this machine**, in its project folder. This is the default: a new project
       has no remote.
    2. **In its own GitHub repo on his account**, `github.com/cblaney00/<folder>`, with
       this project's `main` pushed to it. Only when he wants it (for example a backup, or
       to make it a real app on his computer), and only a repo on *his* account — never
       lando's, never anyone else's.

    Once a project has a GitHub repo, push `main` to it after every commit — that push is
    the backup.

    **It never goes into the NixOS config.** Not copied, not pasted into a Nix file, not as
    a folder under `pkgs/`. The config only ever *packages* an app, by fetching it from its
    GitHub repo by URL (`fetchFromGitHub`, pinned to a commit). So an app must be on GitHub
    before it can be packaged; an app that is only on this machine runs from its project
    folder, as below.

    ## The NixOS config is NOT his — it still needs a PR

    The machine itself is configured in `${configDir}`, which is lando's repo and is shared
    with other machines. Those rules are unchanged and are not negotiable:

    - Work on a branch whose name starts with `blaney/`. **Never commit or push to `main`**,
      and never merge a `blaney/` branch anywhere.
    - Open a PR with `gh pr create` and **stop**. Lando merges it; you never do.
    - Full rules: `${configDir}/docs/hosts/blaney-pc.md`. Background on this kind of
      project: `${configDir}/docs/hosts/blaney-vibe-projects.md`.

    Better still, **do not go into the config from a project session at all** — the one
    exception is the catch-up step below. If the app needs something from the system,
    finish what you can here and tell him in one sentence to close this, run `vibe` and
    choose "Change or fix something on your computer" instead — that opens Claude in the config folder, where the config rules are the ones
    loaded.

    ## Keep his computer caught up with `main` — every time work continues

    His config checkout is often left on a `blaney/` branch, which falls behind lando's
    `main` the longer it sits there, and then his computer runs old config. So **at the
    start of every session — a resumed chat included — and again whenever he comes back to
    the app after a break**, bring the config up to date before doing anything else. Tell
    him first, in one sentence, that you are updating his computer and it can take a few
    minutes. Then, all as plain commands with no `sudo` in front:

    1. `git -C ${configDir} fetch origin`. If that fails (no internet), skip the rest
       silently and carry on with the app.
    2. If `git -C ${configDir} status --porcelain` prints anything, the config has
       unfinished changes from another session. **Do not touch it.** Carry on with the app.
    3. Depending on `git -C ${configDir} branch --show-current`:
       - `main`: `git -C ${configDir} merge --ff-only origin/main`.
       - a `blaney/` branch: `git -C ${configDir} rebase origin/main`. If the rebase stops
         on a conflict, run `git -C ${configDir} rebase --abort`, leave the config alone,
         and tell him in one sentence to run `vibe` later, choose "Change or fix something
         on your computer", and say "my config branch can't catch up with main". If it succeeded and the branch is on GitHub
         (`git -C ${configDir} rev-parse --abbrev-ref @{upstream}` works), push it with
         `git -C ${configDir} push --force-with-lease`. Pushing a `blaney/` branch is
         allowed; this is never a push to `main`.
       - anything else: leave it alone.
    4. If that moved the config at all, run `chown -R ${userName}:users ${configDir}` and
       then `cd ${configDir} && rebuild` (no `sudo` — `rebuild` handles that itself), then
       `cd` back to the project. If the rebuild fails, his computer simply stays as it was:
       tell him in one sentence to run `vibe` later, choose "Change or fix something on
       your computer", and say "rebuild failed after catching up with main", and carry on
       with the app.

    Never resolve conflicts, edit config files, or commit to the config as part of this.
    It is a catch-up only.

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
    does not happen here. If the project has no GitHub repo yet, make one first (see "Where
    his app's code is allowed to live" — ask him, since it puts his code on the internet)
    and push `main` to it. Then tell him, in one sentence: close this, open a terminal, run
    `vibe`, choose "Change or fix something on your computer", and say "package my <name>
    app from github.com/cblaney00/<folder> as a real app". That reuses the normal `blaney/`-branch-and-PR path with the right rules loaded.

    ## Other things to know

    - This machine reaches **GitHub and the internet only**. There is no access to the
      homelab, the NAS, or anything on lando's LAN. Do not write steps that need them.
    - If a project needs a library the dev shell does not have, do **not** install it
      system-wide and do not fight it with pip or npm. Prefer something the shell already
      covers; if that is impossible, say so and point him at
      `vibe` → "Change or fix something on your computer".
    - Keep anything long in the project's `docs/` folder, and keep its `CLAUDE.md` current.
      A future session starts by reading them.
  '' + lib.optionalString gdEnabled gameRulesText
     + lib.optionalString reEnabled reRulesText;

  readmeText = ''
    # Your apps

    This is where the apps you build live. Each folder in here is one app.

    To start a new one, or to carry on with one you already started, open a terminal and
    type:

        vibe

    It gives you a numbered list — pick a number and Claude opens on that app.
  '' + lib.optionalString gdEnabled ''

    It can also start a game of your own — pick "Make a game" — and Claude builds it with
    you. Your games live in here too.
  '' + lib.optionalString reEnabled ''

    The same list also lets you take apart a program or game someone else made, to see
    how it works or to change it. Those projects live in here too.
  '' + ''

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
