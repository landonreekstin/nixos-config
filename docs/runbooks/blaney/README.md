# Blaney task runbooks

Markdown files in this folder are the task queue for `blaney-todo` on **blaney-pc**.

Blaney runs `blaney-todo`, gets a numbered list of everything in here, picks one, and
Claude launches on blaney-pc with that runbook plus the blaney-pc rules from `CLAUDE.md`
as its opening prompt. This file (`README.md`) is filtered out of that menu.

This is separate from `TASKS.md` in the repo root — that stays lando's own list.

## Adding a task

1. Write `docs/runbooks/blaney/<short-name>.md` following the rules below.
2. Push it to `main`. `blaney-todo` fetches `origin/main` on every run, so it shows up
   immediately even if Blaney is sitting on an old `blaney/` branch.
3. Blaney runs `blaney-todo` and picks it; Claude opens a `blaney/…` PR.
4. **Merge the PR and delete the runbook file** — deleting it is what removes the task
   from Blaney's menu. Nothing else tracks completion.

## Rules

- **The first `# ` heading is the menu entry.** Keep it short and in plain English —
  Blaney reads it, not the filename. A leading `Runbook: ` is stripped automatically.
  If a file has no `# ` heading the filename is used instead.
- **Order = filename order.** Prefix with numbers (`01-`, `02-`) to control priority.
- **Write for Claude, not for Blaney.** Claude reads the whole file; Blaney only ever
  sees the title. Be specific about files, options, and acceptance criteria.
- **Leave visual/UX choices open on purpose** if you want Blaney to decide them — the
  preface prompt tells Claude to ask him about look and feel, but never about anything
  technical.
- Don't include steps that need LAN/VPN access to the homelab; blaney-pc is remote and
  only reaches GitHub.

## Template

```markdown
# Fix the taskbar clock format

**What's wrong / what's wanted:** one or two sentences of context.

**Where:** modules/home-manager/themes/windows7-alt/… (point at the actual files)

**Do this:**
1. …
2. …

**Done when:** Blaney can see <observable thing> after a rebuild.

**Notes:** anything Claude would otherwise get wrong.
```
