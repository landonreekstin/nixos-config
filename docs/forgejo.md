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
| `insideabush` | Blaney | collaborator (write) on shared repos |

Create them on mini-server:

```bash
sudo forgejo-admin user create --admin --username lando \
  --email landonreekstin@gmail.com --random-password --must-change-password=false
sudo forgejo-admin user create --username insideabush \
  --email cblaney00@gmail.com --random-password --must-change-password=false
```

Each command prints the generated password. For git, make a token:

```bash
sudo forgejo-admin user generate-access-token --username <u> --token-name <host> \
  --scopes write:repository --raw
```

## Clients: the `homelab` credential helper

git reads each machine's token from a sops secret. `gamedev.forgejo.tokenFile`
(`modules/nixos/development/gamedev.nix`) installs `git-credential-homelab`. It answers
git's `get` with `gamedev.forgejo.user` (default: the host's user) and the token, and a
clone uses it through `credential.helper = homelab`. No token goes in a URL or in
`~/.git-credentials`.

| Host | Forgejo user | Secret |
|---|---|---|
| gaming-pc | `lando` | `forgejo-token` in `secrets/gaming-pc.yaml` |
| blaney-pc | `insideabush` | `forgejo-token` in `secrets/blaney-pc-forgejo.yaml` |

blaney-pc's token is in its own file because adding a key to `blaney-pc.yaml` needs
the admin age key (asus-laptop), while creating a new file only needs the recipients'
public keys (`.sops.yaml` matches `blaney-pc(-admin|-forgejo)?.yaml`).

A shared game is moved by setting `forge = "forgejo"` on its
`gamedev.sharedProjects.<name>` entry (in each host's `profiles.nix`).
`blaneyCommitsToMain = true` drops the main-guard hooks from Blaney's clone and gives his
sessions commit-to-main rules instead of the PR flow. `tea` (the Forgejo `gh`) works but
isn't needed for that flow.

## Repo settings for a shared repo

- *Settings → Collaborators:* `insideabush`, **Write**.
- Merge commits only, branch deleted after merge (set through the API at migration).
- No branch protection on prin-rpg: both people commit to `main`. Protecting `main`
  (push/merge allowlist = `lando`) is the server-side way back to a PR flow.

## Moving a repo off GitHub, without losing anyone's work

1. **Import:** `POST /api/v1/repos/migrate` (or *New Migration → GitHub*) as `lando`
   with `service: github`, `auth_token: $(gh auth token)`, `private`, and issues, PRs,
   labels, milestones, releases, wiki and LFS on. Every branch and PR comes across. Check
   that `git ls-remote` `main` matches GitHub's.
2. **Hosts:** `forge = "forgejo"` on its `sharedProjects` entry. Re-point lando's clone by
   hand: `git remote set-url origin <forgejo url>`, then
   `git config --replace-all credential.helper ""` and
   `git config --add credential.helper homelab`. Blaney's clone is moved by `vibe` the
   next time he opens the game. Before it touches anything, it writes a full
   `git bundle` of the clone to `~/projects/.backups/<name>-before-move-<time>.bundle`.
   Then it pushes every local branch to the new server (once, retried until the server is
   reachable). His working tree is never touched, so uncommitted work stays put.
3. **Freeze GitHub only after blaney-pc has updated.** Until then his sessions still push
   there. Archive it then (*Settings → Archive*), which makes it read-only.
4. **Final sync:** copy anything that reached GitHub after the import. This is a no-force
   push, so a branch that diverged is *rejected* and listed rather than overwritten.
   ```bash
   git clone -q --mirror https://github.com/landonreekstin/<repo>.git /tmp/gh-final
   git -C /tmp/gh-final -c credential.helper=homelab push \
     http://192.168.1.76:3000/lando/<repo>.git 'refs/heads/*:refs/heads/*'
   ```
   Resolve any rejected branch by hand, then keep `/tmp/gh-final` (or a bundle of it)
   until step 5.
5. **Delete GitHub** once Blaney has pushed from his moved clone (his commit shows on
   the server) and step 4 reported nothing left.
