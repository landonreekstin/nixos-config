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
| `opensubtitlescom` | best coverage, needs an account — not yet configured |

Check provider health any time with:

```bash
KEY=$(sudo grep -A3 '^auth:' /var/lib/bazarr/config/config.yaml | grep apikey | awk '{print $2}')
curl -s -H "X-API-KEY: $KEY" localhost:6767/api/providers | jq -c '.data[]'
```

If OpenSubtitles also throttles from the VPN exit, the fix is to split-tunnel Bazarr in
`modules/nixos/homelab/mullvad.nix` so its traffic uses the WAN directly — at the cost of
exposing the home IP to subtitle providers. Do not do this pre-emptively.

## Adding OpenSubtitles (pending)

`opensubtitlescom` is by far the best source, especially for TV. It needs an account on
<https://www.opensubtitles.com>. Free tier is ~20 downloads/day; VIP (~€5/yr) is 1000/day
and is worth it for the one-time catch-up on the existing library.

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
   sops.secrets."opensubtitles-credentials".sopsFile = ../../secrets/optiplex-nas.yaml;
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
