# Lando task runbooks

Markdown files in this folder are the task queue for `landon-todo`, the same setup as
[`blaney-todo`](../blaney/README.md) but for lando's machines. It exists so insideabush's
sessions on blaney-pc can leave lando work that only he can do (his firewall, his router,
his hosts, merges).

`landon-todo` fetches `origin/main`, gives a numbered list of everything in here, and opens
Claude in `~/nixos-config` with the chosen runbook as its opening prompt. This file
(`README.md`) is filtered out of the menu. The command is in
`modules/nixos/common/lando-commands.nix`, gated on the `lando` user.

This is separate from `TASKS.md`, which stays lando's own list.

## Adding a task

1. Write `docs/runbooks/lando/<short-name>.md`. From blaney-pc, that goes through a
   `blaney/` branch and a PR like any other change, so a task appears once lando merges it.
2. Lando runs `landon-todo` and picks it.
3. Deleting the runbook file is what removes the task from the menu. Nothing else tracks
   completion, so the session doing the task deletes it when finished.

## Rules

- **The first `# ` heading is the menu entry.** A leading `Runbook: ` is stripped. With no
  heading, the filename is used.
- **Order = filename order.** Prefix with numbers (`01-`, `02-`) to control priority.
- **Write for Claude.** Be specific about files, hosts and what "done" looks like.
- **Say which host it runs on** if it isn't any of lando's machines.
- **Only what lando has to do.** Anything blaney-pc can do itself belongs in
  `docs/runbooks/blaney/` instead.
