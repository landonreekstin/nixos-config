# Runbook: R62D as a shared server on mini-server

**Run on:** mini-server, as lando (or a Claude session there). `rebuild` needs the sudo password.
**PR:** #251 (`feat/r62d-homelab`). It is **stacked on #233** (browser-puck): the branch
already merges `feat/browser-puck`, so checking it out gives mini-server both games, and
there are no conflicts to resolve.

**Goal:** one always-on R62D server that every VPN client (restricted peers included) and
every Main-LAN machine joins at **`http://192.168.1.76:6262`**, all in the same lobby.

## Already done (2026-10-29, from gaming-pc)

- **optiplex-fw pf**: the two rdr rules are live and committed to openbsd-dotfiles (`52f2fa3`):
  `wg0` from `10.10.0.0/24` and `re0` from `$lan_net`, both to `$nas_legacy_ip port $r62d_port`
  → `$mini_server`. Before this rebuild, `192.168.1.76:6262` answers with an immediate
  *connection refused* from mini-server; that refusal shows the redirect already works.
  Backup: `/etc/pf.conf.bak-r62d-mini`. Details: `docs/networking.md` → "R62D (port 6262)".
- **The service** (`modules/nixos/homelab/r62d.nix`) was smoke-tested on gaming-pc with the
  exact store path and the same systemd sandbox: page 200, `/ws` 101.

## Do this

1. **Check who owns the live system.** mini-server currently runs `feat/browser-puck`.
   ```bash
   cd /home/lando/nixos-config && wt
   ```
   If any worktree has uncommitted work that isn't yours, leave it alone (see
   `docs/parallel-sessions.md`).

2. **Make a worktree for the PR branch and take the machine.**
   ```bash
   git -C /home/lando/nixos-config fetch origin
   wt new feat/r62d-homelab --from origin/feat/r62d-homelab
   cd /home/lando/nixos-config-worktrees/r62d-homelab     # the path wt printed
   git log --oneline -3      # a58b1cd-or-newer "r62d game server" on top of the puck merge
   sudo chown -R lando:users "$PWD"
   rebuild --take
   ```

3. **Check the service on mini-server.**
   ```bash
   systemctl status r62d browser-puck --no-pager      # both active (running)
   curl -s -o /dev/null -w '%{http_code}\n' localhost:6262/   # 200
   curl -s localhost:6262/api/players                  # [] on a fresh install
   journalctl -u r62d -n 20 --no-pager                 # "R62D is running."
   ```
   You can't test `192.168.1.76:6262` *from* mini-server: the rdr rules only match traffic
   arriving on `wg0` or `re0`, not on the server LAN.

4. **Check the player paths** from somewhere else:
   - **Main LAN** (gaming-pc on its LAN address):
     `curl -s -o /dev/null -w '%{http_code}\n' http://192.168.1.76:6262/` → `200`
   - **VPN**: a phone or laptop on homelab-vpn (ideally a *restricted* peer's config) opens
     `http://192.168.1.76:6262`.
   - **Same lobby**: open it in two browsers (or two machines) with two different names. Both
     appear in the lobby together, and a match starts with both.
   - **Persistence**: after a profile has been made, `sudo ls /var/lib/private/r62d` holds
     the saved profiles. `sudo systemctl restart r62d`, reload the page, and the profile is still there.

5. **Record the result and merge.** Comment on #251 with what you checked. Then merge
   **#233 first, then #251** (`gh pr merge <n> --merge --admin` once CI is green; see the
   memory note on the main ruleset). After that, move mini-server back onto `main`:
   ```bash
   cd /home/lando/nixos-config && git checkout main && git pull --ff-only
   sudo chown -R lando:users /home/lando/nixos-config
   rebuild --take                                       # should be a no-op
   wt rm r62d-homelab; wt rm browser-puck
   ```
   mini-server has `autoUpdate` on, so from then on it follows `main` by itself.

6. **Optional: drop the temporary blaney-pc exception** on optiplex-fw. It lets lando's two
   gaming-pc peers (10.10.0.2, 10.10.0.11) reach a game Blaney hosts on his own PC
   (`10.10.0.5:6262`). Keep it if lando still wants to join games Blaney hosts locally.
   Otherwise, in `~/openbsd-dotfiles/etc/pf.conf` on the firewall, change
   `to 10.10.0.5 port { 22, $r62d_port }` back to `to 10.10.0.5 port 22`, run
   `doas pfctl -nf etc/pf.conf`, install it to `/etc/pf.conf`, `doas pfctl -f /etc/pf.conf`, commit
   and push.

## How players join (Windows, Mac, Linux, phones with a keyboard)

There is **no client to install**. R62D is a web page: the server sends the game, and its
WebSocket goes back to the same address the page came from.

1. Turn on their homelab WireGuard tunnel (WireGuard for Windows, with the config they already
   have; restricted configs already route `192.168.1.76/32`). On the home Main LAN, no VPN is needed.
2. Open **`http://192.168.1.76:6262`** in Chrome, Edge or Firefox. Use plain `http`: there is
   no https and no `.lan` name, because restricted peers use public DNS.
3. Type a name. Profiles are stored on the server by name (no password), so the same name on
   another computer is the same profile.

Nice to have, for a desktop/Start-menu icon that opens the game in its own window: in Chrome,
**⋮ → Cast, save, and share → Create shortcut…** with "Open as window" ticked; in Edge,
**⋯ → Apps → Install this site as an app**. F11
makes it full screen. The mouse is captured in matches, so Esc frees it. An Xbox controller works
in Chrome and Edge through the browser's gamepad support. When the server is updated,
everyone gets the new version on their next page load.

## Updates

mini-server serves the **pinned release** in `pkgs/r62d` (`localSrc` is null there). It
gets a new version only when a `blaney/release-r62d` PR merges, never from Blaney's local
work (`docs/companion-repos.md` → "the pin is a release"). After a release merges,
mini-server's auto-update picks it up, or run `update` there to get it now.

The pin as of 2026-10-29 (`cce1454`) predates the lobby's "friends join at…" line, so the
shared lobby shows no join address yet. Blaney's runbook
`docs/runbooks/blaney/11-r62d-shared-server.md` adds `R62D_PUBLIC_URL` support, which the
service already sets to `http://192.168.1.76:6262`, and releases it.
