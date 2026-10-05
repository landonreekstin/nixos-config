# Stop asking for the WiFi password every time I log in

**What's wrong / what's wanted:** Every session, Blaney gets prompted for his WiFi password.
It should connect silently, forever, without him typing anything.

**Where:**
- `modules/nixos/desktop/display-manager.nix` (~line 185) — the gnome-keyring + PAM wiring
- `modules/nixos/desktop/xrdp.nix` (~line 75) — a comment describing *this exact symptom*
  and its cause in the xrdp case; read it, it is the best existing writeup in the repo
- `modules/home-manager/themes/windows7-xfce/panel.nix` (~line 368) — nm-applet in the tray

## What is already ruled out — do not "fix" these

The declarative plumbing is correct and verified by evaluating this host:

| Setting | Value on blaney-pc |
|---|---|
| `services.gnome.gnome-keyring.enable` | `true` |
| `security.pam.services.ly.enableGnomeKeyring` | `true` |
| `services.displayManager.ly.enable` | `true` |
| `networking.networkmanager.enable` | `true` |

So gnome-keyring is installed and the Ly PAM stack is set up to unlock the login keyring with
the password Blaney types at login. **This is runtime state, not a missing module.** Do not
add keyring modules, swap to kwallet, or touch `display-manager.nix` until you have proven
the diagnosis below.

## Step 1 — find out which of the two causes it is

Run these as Blaney (not root — the keyring and the agent are per-user):

```bash
nmcli -f NAME,UUID,TYPE,DEVICE,AUTOCONNECT connection show
nmcli -f 802-11-wireless-security.psk-flags,connection.permissions,connection.autoconnect \
      connection show "<his wifi name>"
```

`psk-flags` is the whole answer:

| `psk-flags` | Meaning | What it implies |
|---|---|---|
| `0` (none) | PSK stored in the system connection file | No keyring needed; should never prompt |
| `1` (agent-owned) | PSK stored in the user's keyring | Prompts whenever the keyring is locked |
| `2` (not-saved) | **NM is told to ask every time** | Prompts by design — this is cause A |
| `4` (not-required) | No PSK at all | Wrong for a WPA network |

- **`psk-flags = 2`** → cause A. Somebody (or the connect dialog) said "ask for this password
  every time" / left "Store password for this user only" unchecked. Nothing is broken; the
  connection is configured to prompt. Go to step 2A.
- **`psk-flags = 1`** → cause B, a keyring problem. Confirm it:
  ```bash
  ls -la ~/.local/share/keyrings/
  busctl --user list | grep -i secret          # is the secret service running?
  secret-tool search --all xdg:schema org.freedesktop.NetworkManager.Mobile 2>&1 | head
  journalctl --user -b -u gnome-keyring-daemon --no-pager | tail -30
  journalctl -b | grep -iE "gnome.keyring|pam_gnome" | tail -30
  ```
  The classic failure is a `login.keyring` whose own password is **not** Blaney's account
  password — created before the PAM unlock existed, or left behind after a password change.
  PAM then cannot unlock it, it stays locked all session, and nm-applet prompts. The giveaway
  is a prompt whose text mentions the login keyring. Go to step 2B.

## Step 2A — `psk-flags = 2`: tell NetworkManager to keep the password

Store it system-wide so it does not depend on a keyring or on who is logged in:

```bash
sudo nmcli connection modify "<his wifi name>" \
  802-11-wireless-security.psk-flags 0 \
  802-11-wireless-security.psk "<the password>" \
  connection.autoconnect yes \
  connection.autoconnect-priority 10
sudo nmcli connection up "<his wifi name>"
```

Get the password from Blaney — ask him for it plainly, he has it. The PSK lands in
`/etc/NetworkManager/system-connections/<name>.nmconnection` (root-only, mode 600).

## Step 2B — `psk-flags = 1`: either repair the keyring or stop depending on it

Prefer **not depending on it** — it is one less thing that can break for a user who cannot
debug it. Move the secret to system-wide exactly as in step 2A; a system-owned PSK is read by
NetworkManager itself before any user session exists, so the keyring is out of the loop
entirely and WiFi comes up at boot rather than at login.

Only if Blaney specifically wants the password kept in his user keyring, repair it instead:

```bash
# Back it up first; this discards every secret in the login keyring.
cp -a ~/.local/share/keyrings ~/.local/share/keyrings.bak-$(date +%F)
rm -f ~/.local/share/keyrings/login.keyring ~/.local/share/keyrings/user.keystore
```

Then log out and back in — PAM recreates `login.keyring` keyed to his login password — and
re-enter the WiFi password **once**. Note that this also wipes any other saved secret
(Chromium passwords stored in the keyring, VPN secrets); check with the backup first and tell
Blaney what he will have to re-enter.

## Step 3 — make it stick across a reinstall (decide, then say which you did)

Everything above is imperative machine state and would be lost on a fresh install. There is a
declarative option with precedent in this repo: `modules/nixos/services/wireguard-nm-client.nix`
builds a NetworkManager profile from `networking.networkmanager.ensureProfiles` with the secret
substituted from sops at activation. The same pattern would pin his WiFi profile and PSK into
`hosts/blaney-pc/networking.nix` + `secrets/blaney-pc.yaml`.

**Do not do that silently.** It puts his home WiFi password (encrypted) into a shared repo, so
it is lando's call. Get the prompting fixed first with step 2, then note in the PR description
that the declarative follow-up is available and let lando decide. If there is nothing to commit
because the fix was purely `nmcli` state, say so plainly rather than inventing a code change.

## Do this

1. Diagnose per step 1 and state which cause it was.
2. Fix per step 2A or 2B.
3. **Reboot** — not just log out. The point is that WiFi comes up with no prompt from cold.
4. Verify: Blaney logs in and the network applet shows connected with no password dialog, in
   **both** his Xfce and his KDE session (the keyring/agent differ between them).
5. Check `nmcli -f 802-11-wireless-security.psk-flags connection show "<name>"` now reads `0`
   (or that the keyring unlocks, if you went the 2B-repair route).
6. If there is a config change: **branch** `blaney/fix-wifi-password-prompt`, chown, `rebuild`,
   verify again, commit, open a PR, and stop. If there is not, report what you changed on the
   machine and that no PR is needed.

**Done when:** Blaney reboots, logs in, and is online without typing a WiFi password — twice in
a row, in both desktop sessions.

## Traps

- **Run the `nmcli` *reads* as Blaney, the *writes* with `sudo`.** `nmcli connection show` as
  root will not show agent-owned secrets or his per-user permissions, which is exactly the
  information you need.
- **`nmcli -s`** is required to print secrets; without it you get blanks and may conclude the
  PSK is missing when it is not.
- **Check `connection.permissions`.** If it is `user:insideabush`, the profile is per-user and
  the secret is agent-owned no matter what you set `psk-flags` to. Clear it (`""`) when moving
  the PSK system-wide.
- **Don't confuse this with the homelab VPN.** `homelab-vpn` is a declarative profile that
  deliberately does not autoconnect (`hosts/blaney-pc/networking.nix`); Blaney toggling that on
  is normal and unrelated.
- A prompt that says *"the login keyring did not get unlocked"* is cause B. A prompt that just
  asks for the network's password with no keyring wording is cause A. Read the dialog.
