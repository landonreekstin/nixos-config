<!-- ~/nixos-config/docs/hosts/blaney-pc.md -->
> **Read this when**: the session is running on `blaney-pc` (user `insideabush`), or
> when writing/reviewing a runbook in `docs/runbooks/blaney/`. These rules are binding
> for blaney-pc sessions and override the general workflow in `CLAUDE.md` where they
> conflict.

# blaney-pc

When running on the `blaney-pc` host, apply these additional guidelines:

**User Context**: insideabush has no Linux or Nix technical knowledge. He is not able to make technical or architectural decisions.
- If he asks to learn something, explain it simply and concisely — go deeper only if he probes
- Otherwise: fix the issue or implement the feature — keep communication brief, clear, and directive
- He CAN and SHOULD make UX/visual decisions: colors, layout, what something looks like, what a feature does from a user perspective

**Decision Authority**:
- **Claude decides autonomously**: module structure, NixOS options, which files to edit, how to architect changes, naming conventions — anything technical. Use repo precedent and best judgement; do not ask insideabush about these.
- **insideabush decides**: visual appearance, user-facing behavior, feature scope and direction
- **Bug fixes** → act immediately with minimal explanation; only ask insideabush if the problem is genuinely ambiguous
- **Feature requests** → ask what he wants it to look/feel like to establish UX direction, then execute independently

**Autonomy — Do Everything Possible**:
- Run `rebuild`, copy files, run commands — anything within Claude's capability that doesn't require physical user action
- **Never ask insideabush to run a command Claude can run itself**
- Do not ask for confirmation on technical choices; make them and briefly note what was done
- Always `chown` and `rebuild` as part of your workflow; don't hand these off to insideabush

**Communication**:
- For features: ask about UX direction, then execute silently
- For bugs: diagnose and fix; give insideabush clear "does this look right?" checkpoints
- Give next steps as plain, one-sentence instructions (e.g. "Tell me if the wallpaper changed after it rebuilds")
- Never use technical jargon without immediately explaining it in plain terms

**Branch Naming Convention (STRICT)**:
- All branches for insideabush's work MUST use the prefix `blaney/`
  - Examples: `blaney/feat-party-mode`, `blaney/fix-wifi-issue`
- This prefix distinguishes insideabush's branches from lando's branches — do not deviate from it
- When continuing prior work, reuse the existing `blaney/` branch if still relevant; check `git branch -a` first

**Git Workflow (STRICT)**:
- **NEVER push or commit directly to `main`** — always use a `blaney/` branch
- **NEVER merge into any branch that does not start with `blaney/`** — this includes `main` and all branches created by lando or his Claude sessions
- insideabush's Claude sessions CAN: create new `blaney/` branches, push to those branches, merge other existing branches INTO a `blaney/` branch
- insideabush's Claude sessions CANNOT: push to `main`, push to any non-`blaney/` branch, merge a `blaney/` branch into a non-`blaney/` branch
- When insideabush confirms a feature is working and acceptable: open a PR from the `blaney/` branch to `main` via `gh pr create`
- **Never merge the PR** — lando (`landonreekstin`) merges all PRs from blaney-pc

**Safety**:
- Always use `nixos-rebuild test` before `rebuild` for significant changes, so insideabush can verify before permanently switching
- Keep changes focused and minimal

## Runbooks as blaney-pc tasks

`docs/runbooks/blaney/*.md` is the task queue lando leaves for blaney-pc. Each markdown
file is one task; its first `# ` heading is the menu entry insideabush sees.

The loop:
1. lando adds `docs/runbooks/blaney/<name>.md` on `main` and pushes
2. insideabush runs `blaney-todo`, which fetches `origin/main`, lists the runbooks by
   number, and launches `claude` on the chosen one with the blaney-pc preface prompt
   (defined in `modules/nixos/common/commands.nix` — keep it in sync with the rules above)
3. Claude does the work on a `blaney/` branch and opens a PR
4. **lando merges the PR and deletes the runbook file** — deleting it is the only thing
   that removes the task from the menu

Notes:
- Only `docs/runbooks/blaney/` feeds the menu; other runbooks under `docs/runbooks/` are
  ordinary docs and never appear. `README.md` in that folder is the authoring guide and is
  filtered out.
- This is separate from `TASKS.md`, which remains lando's own list.
- When working *on* a blaney runbook: never edit, move, or delete the runbook file itself.

