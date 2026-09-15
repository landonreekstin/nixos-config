# English Subtitles

Goal: every movie and episode in Jellyfin has an English subtitle track available.

**Bazarr is the mechanism.** It watches Radarr/Sonarr, downloads `.srt` files, and writes
them next to the video file in `/mnt/storage/media/{movies,tv}`. `media-linker` then
hardlinks them into every per-user library within 5 minutes, so one download lights up
all of `blaney`, `chris`, `em`, `russell`, `cmoore` at once. Jellyfin picks up sidecar
`.srt` files automatically — no Jellyfin-side configuration is required for this path.

The Jellyfin OpenSubtitles plugin is a *fallback* for playback-time fetches only. It is
mutable state that cannot be declared in Nix, and its downloads do not propagate to the
per-user libraries. See [Jellyfin plugin](#jellyfin-plugin-fallback-manual).

## How it is declared

`modules/nixos/homelab/bazarr-provision.nix` converges Bazarr's settings on every boot
and every `rebuild`, via `customConfig.homelab.arr.bazarr.provision`:

```nix
arr.bazarr.provision = {
  enable = true;
  credentialsFile = null;  # set to the OpenSubtitles sops secret, see below
};
```

Bazarr rewrites both `config.yaml` and its SQLite DB at runtime, so its state cannot be a
Nix-generated file. Instead a oneshot drives `POST /api/system/settings`, which writes
every `config.yaml` key *and* the language profile in a single call. The profile upsert is
keyed on `profileId`, so re-running is a no-op — the same pattern as `media-linker.nix`.

The unit applies:

- `radarr.ssl` / `sonarr.ssl` = false, ip/port pinned to localhost
- the enabled provider list
- the **English** language profile (id 1)
- `movie_default_profile` / `serie_default_profile` = 1, so new downloads are enrolled
  automatically
- `use_embedded_subs` and `upgrade_subs`

Then it triggers a Radarr/Sonarr sync, backfills the profile onto anything still missing
it, and — only when the settings actually changed — kicks off a search for missing
subtitles. The change check uses a hash stamped at `/var/lib/bazarr/.nix-provisioned`, so
an unchanged rebuild does not re-fire a full library search.

Re-run it by hand with `sudo systemctl restart bazarr-provision`; watch it with
`journalctl -u bazarr-provision -f`.

### The language profile

Two items, both English:

| id | language | hi | role |
|---|---|---|---|
| 1 | en | False | the cutoff — a normal English sub satisfies the profile |
| 2 | en | True | hearing-impaired, accepted as a fallback |

Because the cutoff names item 1, an HI sub counts as "has subtitles" immediately while
Bazarr keeps looking for a normal one to upgrade to. On disk this shows up as
`<video>.en.srt` and `<video>.en.hi.srt`.

Adding a language means adding an item with a new `id` in `languageProfiles` in the
module and rebuilding — the upsert rewrites profile 1 in place.

## Two bugs this replaced

Worth knowing, because both were silent for a long time:

1. **`ssl: true` on a plain-HTTP *arr.** Bazarr's `config.yaml` had `ssl: true` under both
   `radarr:` and `sonarr:` while both serve plain HTTP. Bazarr could never reach either,
   so its library stayed empty and it downloaded nothing, ever. The symptom was
   `Error trying to get rootfolder from Radarr. Connection Error.` hourly in
   `/var/lib/bazarr/log/bazarr.log`, and `radarr_version: "unknown"` in
   `/api/system/status`.
2. **Radarr/Sonarr's 0022 umask.** They created each title directory as `drwxr-sr-x`, so
   Bazarr — despite being in the `media` group — got `PermissionError` writing `.srt`
   files. `arr.nix` now sets `UMask = "0002"` on radarr, sonarr and bazarr.

The umask fix only affects *newly created* directories. The 87 pre-existing title dirs
were fixed once with:

```bash
sudo find /mnt/storage/media/movies /mnt/storage/media/tv -type d ! -perm -g+w -print0 \
  | sudo xargs -0 --no-run-if-empty chmod g+w
```

A second, related trap: 20 TV directories were owned `sonarr:sonarr` rather than
`sonarr:media`, predating the SGID bit on `/mnt/storage/media/tv`. `chmod g+w` made
them writable *by the wrong group*, so Bazarr still failed. They were fixed with:

```bash
sudo find /mnt/storage/media/movies /mnt/storage/media/tv ! -group media -print0 \
  | sudo xargs -0 --no-run-if-empty chgrp media
sudo find /mnt/storage/media/movies /mnt/storage/media/tv -type d -print0 \
  | sudo xargs -0 --no-run-if-empty chmod g+ws
```

The SGID bit on the library roots means new title directories inherit `media`, so
neither fix should be needed again.

**This one is worth catching early**: every failed save still counts against the
OpenSubtitles daily download quota. The first TV search after enabling the account
burned the entire free-tier allowance of ~20 on writes that could not land.

This should not be needed again — a fresh install creates directories with the right
umask from the start.

## Providers and the Mullvad problem

The NAS runs Mullvad as a full tunnel, so Bazarr's provider requests egress from a VPN
exit IP (currently Sweden). That matters:

| Provider | State |
|---|---|
| `yifysubtitles` | works |
| `tvsubtitles` | homepage loads, but `search.php` returns **403** from the VPN exit |
| `podnapisi` | **dead domain** — `podnapisi.net` does not resolve, even via 1.1.1.1. Removed from the defaults. |
| `opensubtitlescom` | works; the free-tier 20/day quota is the limiting factor |

Check provider health any time with:

```bash
KEY=$(sudo grep -A3 '^auth:' /var/lib/bazarr/config/config.yaml | grep apikey | awk '{print $2}')
curl -s -H "X-API-KEY: $KEY" localhost:6767/api/providers | jq -c '.data[]'
```

If OpenSubtitles also throttles from the VPN exit, the fix is to split-tunnel Bazarr in
`modules/nixos/homelab/mullvad.nix` so its traffic uses the WAN directly — at the cost of
exposing the home IP to subtitle providers. Do not do this pre-emptively.

## OpenSubtitles

`opensubtitlescom` is configured and healthy. It is by far the best source,
especially for TV. The account is at
<https://www.opensubtitles.com>; credentials live in `secrets/optiplex-nas.yaml`
as `opensubtitles-credentials`, wired up in `hosts/optiplex-nas/homelab.nix`.

**The free tier is ~20 downloads/day and that is the current bottleneck.** The
movie library cleared completely, but 532 episodes are still wanting subtitles and
will trickle in at ~20/day — roughly a month. VIP (~€5/yr) raises it to 1000/day
and would clear the backlog in a single pass. When the quota is spent, Bazarr
reports `DownloadLimitExceeded` and backs off for 6 hours; this is expected, not a
fault.

The steps below are what was done, kept for a re-install:

1. Create the account.
2. Add the secret:
   ```bash
   sops secrets/optiplex-nas.yaml
   ```
   with an env-file-shaped value:
   ```yaml
   opensubtitles-credentials: |
     OPENSUBTITLES_USERNAME=<user>
     OPENSUBTITLES_PASSWORD=<pass>
   ```
3. In `hosts/optiplex-nas/homelab.nix`, declare the secret and point the module at it:
   ```nix
   # defaultSopsFile already resolves to secrets/optiplex-nas.yaml on this host.
   sops.secrets."opensubtitles-credentials" = { };
   # ...
   arr.bazarr.provision.credentialsFile =
     config.sops.secrets."opensubtitles-credentials".path;
   ```
4. `rebuild`. The unit adds `opensubtitlescom` to the provider list, and because the
   settings hash changed it re-fires the missing-subtitle search automatically.

Without credentials the module logs
`No OpenSubtitles credentials supplied; enabling no-auth providers only.` and carries on.

## Jellyfin plugin (fallback, manual)

Undeclared mutable state in `/var/lib/jellyfin/plugins/`. Survives rebuilds, lost on a
reinstall — redo these after any NAS re-install:

- Dashboard → Plugins → Catalog → **Open Subtitles** → install → restart Jellyfin, then
  enter opensubtitles.com credentials and API key.
- For each library: **Save subtitles into media folders** on, and
  **Download subtitles → English**, so plugin-fetched subs land as sidecars rather than in
  Jellyfin's metadata directory.

## Editing the secrets file on the NAS

Your personal admin age key lives on asus-laptop, not here, so a bare `sops
secrets/optiplex-nas.yaml` fails with `identity did not match any of the
recipients`. The NAS's own SSH host key is the other valid recipient; it was
converted to an age identity at `~/.config/sops/age/keys.txt` so sops finds it
automatically:

```bash
sudo sh -c 'umask 077; ssh-to-age -private-key \
  -i /etc/ssh/ssh_host_ed25519_key -o /home/lando/.config/sops/age/keys.txt'
sudo chown lando:users /home/lando/.config/sops/age/keys.txt
```

That file is a decryption identity for every NAS secret. It is not a privilege
escalation (lando can `sudo cat` the host key anyway), but delete it if this host
stops being a place you edit secrets from.

## Verifying

```bash
KEY=$(sudo grep -A3 '^auth:' /var/lib/bazarr/config/config.yaml | grep apikey | awk '{print $2}')

# *arrs reachable? Real version strings, not "unknown".
curl -s -H "X-API-KEY: $KEY" localhost:6767/api/system/status \
  | jq '.data | {radarr_version, sonarr_version}'

# Everything carries the English profile?
curl -s -H "X-API-KEY: $KEY" "localhost:6767/api/movies?length=-1" \
  | jq '{total, unprofiled: ([.data[]|select(.profileId==null)]|length)}'

# How much is still wanted?
curl -s -H "X-API-KEY: $KEY" localhost:6767/api/badges | jq '{movies, episodes}'

# Subtitles on disk, and propagated as hardlinks (link count > 1)
sudo find /mnt/storage/media/movies -name '*.srt' | wc -l
sudo find /mnt/storage/media/users -name '*.srt' -printf '%n %p\n' | head
```
