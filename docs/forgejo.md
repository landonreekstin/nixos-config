# Forgejo (our own git server)

Forgejo runs on **mini-server** (`modules/nixos/homelab/forgejo.nix`) and hosts the game
repos lando and Blaney share, prin-rpg first. It replaces GitHub for those repos.

- **Address:** `http://192.168.1.76:3000` for everyone, on the LAN and over the VPN.
  optiplex-fw redirects that port of the legacy NAS alias to mini-server
  (see [networking.md › Forgejo](networking.md#forgejo-port-3000)). Over the VPN only the
  `<git_peers>` table can reach it (lando's peers .2/.3/.11, Blaney's .5/.17).
- **HTTP only, no SSH.** git authenticates with a Forgejo access token. On the VPN,
  WireGuard encrypts the traffic. On the LAN it's plain HTTP, the same as every other
  homelab service.
- **No sign-ups and no anonymous browsing.** Accounts are made by hand (below).
- **Backups:** `forgejo-dump` writes a consistent archive (database + repos + LFS) to
  `/var/lib/forgejo/dump` at 03:30, and keeps 3 days of them. The 04:00 restic job
  (`game-backup.nix`) carries that directory to the NAS. No GitHub copy is kept, so this
  is the only offsite copy.
- **CLI:** `sudo forgejo-admin …` on mini-server runs `forgejo admin …` as the service user
  against the live `app.ini`.

## Accounts

| Forgejo user | Who | Role |
|---|---|---|
| `lando` | lando | site admin, owns the repos |
| `insideabush` | Blaney | collaborator (write) on shared repos; branch protection keeps him off `main` |

Create them on mini-server:

```bash
sudo forgejo-admin user create --admin --username lando \
  --email landonreekstin@gmail.com --random-password --must-change-password=false
sudo forgejo-admin user create --username insideabush \
  --email cblaney00@gmail.com --random-password --must-change-password=false
```

Each command prints the generated password. Make access tokens under
*Settings → Applications*, with scopes `repository` and `user` (read/write) so `tea` works.
Or have the CLI make them: `sudo forgejo-admin user generate-access-token --username <u>
--token-name tea --scopes write:repository,write:user,read:organization`.

## Clients: git + `tea`

`tea` is the Forgejo/Gitea CLI (the `gh` equivalent). One login sets up both the CLI and
git's credential helper:

```bash
tea login add --name homelab --url http://192.168.1.76:3000 --token <token>
git config --global credential.http://192.168.1.76:3000.helper '!tea login helper'
```

The `gh` commands it replaces: `tea pr ls`, `tea pr create --base main --head <branch>`,
`tea pr checkout <n>`, `tea pr merge --style merge <n>`, `tea comment <n> "…"`.

## Repo settings for a shared repo (prin-rpg)

- *Settings → Collaborators:* `insideabush`, **Write**.
- *Settings → Branches → protect `main`:* push allowlist = `lando` only, merge allowlist =
  `lando` only. This is real server-side enforcement. On GitHub's free plan the only guard
  was the client-side `gamedev.mainGuardHooks`, which stays as the friendly early error.
- *Settings → Repository:* merge style "Create merge commit" only, delete branch after
  merge.

## Moving a repo off GitHub

1. *New Migration → GitHub* in the web UI, as `lando`. Give it a GitHub token
   (`gh auth token`) so it can read a private repo, and tick issues, pull requests,
   labels, milestones and releases. Open PRs and their comments come across.
2. Apply the repo settings above.
3. On every clone, point `origin` at Forgejo:
   `git remote set-url origin http://192.168.1.76:3000/lando/<repo>.git`. Blaney's clone
   is re-pointed by `vibe`.
4. Update the repo's own `CLAUDE.md` ("Working together") from `gh` to `tea`.
5. Delete the GitHub repo only once both people have pushed to the new remote.
