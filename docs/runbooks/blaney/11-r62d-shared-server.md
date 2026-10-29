# Get R62D ready for the shared server

**What's wrong / what's wanted:** Lando is putting R62D on the homelab server (mini-server)
so that *all* the VPN friends can play together at **`http://192.168.1.76:6262`**, any time,
without Blaney's PC being on. On lando's side (nixos-config PR #251, plus the firewall) this
is done. Two things are left that only blaney-pc can do:

1. **The lobby has to show the right address.** The "Friends … join at …" line comes from
   `/api/addr` in `server/server.js`, which lists the server's own network cards. On
   mini-server that would be `192.168.100.103`, an address no player can reach. The server
   needs to accept the real address from outside. mini-server's service already sets
   **`R62D_PUBLIC_URL=http://192.168.1.76:6262`**. The game just has to use it.
2. **A release**, because mini-server runs the *pinned* R62D (`pkgs/r62d`), not his
   `~/projects/r62d` folder. The current pin, `cce1454`, is from before the lobby address
   line existed. Without a release, the shared server runs that old version.

**Where:**
- `~/projects/r62d` on blaney-pc: his project (`server/server.js`, `public/js/main.js`
  around the `joinAddr` line, and the project's `CLAUDE.md`)
- `pkgs/r62d/default.nix` in nixos-config: the pin, release PR only
- `docs/companion-repos.md` → "insideabush's apps: the pin is a release": read the rules
  before touching the pin

## Part 1: `R62D_PUBLIC_URL` in the game (his project, his `main`)

Follow `~/projects/CLAUDE.md` and the project's own `CLAUDE.md`. This is his repo, so
commit to its `main` directly (`docs/hosts/blaney-vibe-projects.md`).

1. In `server/server.js`, make `/api/addr` return **only** that address when
   `process.env.R62D_PUBLIC_URL` is set (e.g. `{ urls: [{ url: <it>, vpn: true }] }`), so the
   lobby reads "Friends on the homelab VPN join at http://192.168.1.76:6262". When it is
   unset, keep today's behaviour exactly: blaney-pc hosting games for friends still lists
   its own addresses. Also print it in the startup message.
2. Run his tests (`npm test` plus any in `tests/` that touch the server), then check both
   modes by hand:
   ```bash
   cd ~/projects/r62d
   PORT=16262 R62D_DATA=$(mktemp -d) R62D_PUBLIC_URL=http://192.168.1.76:6262 node server/server.js &
   sleep 1; curl -s localhost:16262/api/addr; kill %1    # only the 192.168.1.76 url
   PORT=16262 R62D_DATA=$(mktemp -d) node server/server.js &
   sleep 1; curl -s localhost:16262/api/addr; kill %1    # his own addresses, as before
   ```
   Use a temp `R62D_DATA` as shown so his real saved profiles are never touched.
3. Add a line about the shared server and `R62D_PUBLIC_URL` to the project's `CLAUDE.md`
   ("What this app is" / how it runs). Commit, then push his `main` as him (the command is
   in `docs/companion-repos.md` → glade; `gh` is signed in as `cblaney00`).

## Part 2: the release PR (nixos-config)

This runbook counts as Blaney asking for the release. Follow the rules exactly, because CI's
`release-pins` job enforces them:

- Branch `blaney/release-r62d`, cut fresh from `origin/main`. If it already exists, re-cut it
  and force-push; never rebase it.
- Change **only** `pkgs/r62d/default.nix`: `rev` = the sha you just pushed, `version` =
  `0-unstable-<its commit date>`, `hash` from the `lib.fakeHash` build. Nothing else in the PR.
- Verify by building the pinned package (blaney-pc itself builds from the folder, so a
  rebuild there proves nothing about the pin). Then run the pinned build's server and repeat
  the `R62D_PUBLIC_URL` curl from Part 1 against it.
- PR title `pkg(r62d): release <short sha>`. In the body, say it is for the shared server on
  mini-server (#251) and list what changed in the game since `cce1454`
  (`git log --oneline cce1454..HEAD` in `~/projects/r62d`, in plain words).

## Part 3: Blaney's menu entry (ask him; skip if nobody is there)

Today his **R62D** menu entry starts a game server on his own PC and opens it there. Now
that there is a shared one, **ask Blaney** what he wants. Don't decide this for him:

- keep hosting on his PC (no change),
- make the menu entry open the shared server (`http://192.168.1.76:6262`, which only works
  with homelab-vpn on), or
- both: two entries, e.g. "R62D" and "R62D Online".

If he wants a change, make it in `modules/nixos/programs/r62d.nix`. Keep the kiosk-window
behaviour, and keep it host-agnostic, e.g. a `customConfig.programs.r62d.serverUrl` option set in
`hosts/blaney-pc/apps.nix`. Put it in its **own** `blaney/` PR. It must not touch the pin
(the release PR above is separate). Rebuild and check the menu entry opens the right page;
with the VPN off, it should still open something sensible rather than a blank window.

If this runs with nobody there, do Parts 1–2 only and say in the release PR that Part 3 is
waiting for Blaney.

**Done when:**
- his `main` on GitHub has the `R62D_PUBLIC_URL` change, and the tests and both curl checks pass;
- a `blaney/release-r62d` PR is open that touches only `pkgs/r62d/default.nix`, with CI green;
- Part 3 is either done in its own PR or noted as waiting for Blaney.

**Notes:**
- Profiles on the shared server are separate from the ones saved on his PC (it has its own
  data in `/var/lib/r62d`). Players there just type their name again.
- Do not change the firewall or anything on mini-server; that's lando's side and already done.
- After this, delete this runbook in the same PR as Part 3 (or lando deletes it when merging the release).
