# Browsers: declarative Firefox and LibreWolf

Option tree: `customConfig.homeManager.browser.{firefox,librewolf}`
Declared in: `modules/nixos/common/home-manager.nix` (`mkBrowserOptions`)
Implemented by: `modules/home-manager/programs/browser/`

## Why Firefox exists here

nixpkgs periodically marks LibreWolf **insecure**. When it does, Hydra stops
building it, the narinfo 404s, and every host that has not pinned it to unstable
source-builds a Firefox fork — which OOMs the NAS flake-updater and stalls the
weekly `update/*` PR. Commits `2003524` and `0e3c9d8` were both firefighting of
exactly this. `pkgs.firefox` is a first-class nixpkgs package, always cached, and
never marked insecure.

So this module makes plain Firefox behave like LibreWolf, but deliberately more
usable: saved logins, Widevine/DRM, and no cookie wipe on shutdown.

## Verification checklist

None of this is provable headlessly — a rebuild only shows the config evaluates
and the files land. Walk it on a real display before treating Firefox as a
LibreWolf replacement anywhere.

1. **Chrome theme** — toolbar, urlbar and tabs show the configured `chromeTheme`.
2. **DRM** — play Netflix or Prime Video. `about:addons` → Plugins lists
   "Widevine Content Decryption Module". This is the check most likely to fail
   on LibreWolf, where the GMP manager is blocked.
3. **`.lan`** — `http://jellyfin.lan` loads (proves `trr.mode = 5` and
   HTTPS-only off).
4. **Passwords** — log in somewhere, confirm the save prompt, then fully restart
   the browser and confirm the login survived (proves sanitize-on-shutdown off).
5. **Search** — the address bar searches `noai.duckduckgo.com`, and `@np`,
   `@no`, `@hm`, `@gh` resolve.
6. **Bookmarks** — the toolbar tree matches, and **Game Servers** and
   **article2pod** open with their tokens substituted. That last part is the
   only check that proves the sops path end to end.
7. **Launchers** — Super+B, the desktop's default-browser association and the
   XFCE panel pin each open the browser you expect. With two browsers installed,
   confirm both, not just one.
8. **Closure** — `nix path-info -r /run/current-system | grep -c <browser>`
   shows no unwrapped duplicate. A `command` string of the form
   `"${pkgs.x}/bin/x"` realises x even when it is absent from `home.packages`.

## Where LibreWolf's behaviour actually comes from

Worth knowing before changing anything, because it is not where people expect:

| Layer | What it holds |
|---|---|
| `mozilla.cfg` (782 lines, inside the package) | ~95% of it — telemetry kill-switches, strict tracking protection, sanitize-on-shutdown, Safe Browsing off, prefetch off, `resistFingerprinting`, GPC, `network.trr.mode = 5` |
| `distribution/policies.json` | telemetry/studies off, `FirefoxHome` + `FirefoxSuggest` sections off, `NoDefaultBookmarks`, `UserMessaging` off |
| the profile's `user.js` | almost nothing |

Plain Firefox ships none of the first two, so `privacy.nix` restates them.

## The two layers

They are independent: either can be enabled alone, and enabling both merges
their prefs into one profile.

**`privacy`** (`privacy.nix`) — the LibreWolf-equivalent hardening. Everything in
`alwaysSettings` is unconditional; the friction points are options, and all three
default to the *usable* setting:

| Option | Default | LibreWolf does |
|---|---|---|
| `sanitizeOnShutdown` | `false` | wipes cookies + storage on close |
| `disableSafeBrowsing` | `false` | strips it entirely |
| `promptDownloadDir` | `false` | asks every time |
| `resistFingerprinting` | `false` | on (forces light theme, fixed window size) |
| `httpsOnlyMode` | `false` | on (breaks the plain-HTTP `.lan` homelab) |
| `rememberPasswords` | `true` | off |
| `enableDRM` | `true` | blocks the GMP manager outright |
| `useSystemDNS` | `true` | same — `trr.mode = 5`, required for `.lan` |

Two of these need care because Firefox and LibreWolf differ in their *defaults*,
not just their prefs:

- **`sanitizeOnShutdown`** writes an explicit boolean rather than omitting the
  pref when false. Omitting is fine on Firefox, whose stock default is already
  off — but LibreWolf's `mozilla.cfg` turns it **on**, so an omitted pref would
  leave the option silently doing nothing there.
- **`enableDRM`** cannot just set `media.eme.enabled`. LibreWolf also blanks
  `media.gmp-manager.url` and disables `media.gmp-provider.enabled`, so the
  Widevine CDM can never download and playback fails with EME apparently "on".
  The preset restores all three to Firefox's stock values — a no-op on Firefox,
  an unblock on LibreWolf.

The general rule: a pref this module leaves unset is whatever the *package*
defaults it to, and those two packages disagree. When a toggle is meant to mean
something on both, write both branches.

Three things from `policies.json` are **deliberately not ported**:
`EncryptedMediaExtensions.Enabled = false` (kills Widevine), `HttpsOnlyMode`
(breaks `.lan`), and `DisableAppUpdate`/`AppUpdateURL` (meaningless for a
Nix-managed package).

Tracking protection sets **only** `browser.contentblocking.category = "strict"`.
Firefox derives the whole strict preset from it at startup and overwrites the
individual prefs, so restating them is either redundant or, where a value
differs, silently flips the category to "custom" while the strict value still
applies.

**`personal`** (`personal.nix`, `bookmarks.nix`, `chrome/`) — bookmarks, the
`chromeTheme` enum, search engines, containers and startup behaviour.

## `overrideConfig`

- `true` (default) — prefs go to the profile's `user.js` and are re-enforced at
  every browser start. A change made in the browser UI reverts on restart.
- `false` — prefs are compiled into the **package's autoconfig** (`mozilla.cfg`)
  as `defaultPref()` via `pkgs.firefox.override { extraPrefs = …; }`. They then
  act as defaults: a UI change lands in `prefs.js` and survives. This is the same
  mechanism LibreWolf uses for its own settings.

Extensions, `userChrome.css`, bookmarks, search and containers are managed
declaratively either way.

> The old `librewolf.nix` implemented `overrideConfig = false` with an activation
> script that wrote a second `user.js` into `~/.librewolf/<userName>` while the
> real profile was at `<profilePath>` — two different directories, so the seeded
> file was never read. Don't reintroduce that shape.

## Extensions: install, enable and pin

Extensions go through the **`ExtensionSettings` policy**, not
`profiles.<p>.extensions.packages`. That distinction is the whole reason they
work without manual clicks.

Dropping an XPI into the profile's `extensions/` directory leaves it
*side-loaded*: Firefox lists it in `about:addons` but keeps it **disabled** until
the user clicks through an approval prompt, and it lands in the puzzle-piece
menu rather than the toolbar. That is exactly what happened on the first
gaming-pc build — all five installed, none enabled, none pinned.

The policy does all three at once:

```nix
"uBlock0@raymondhill.net" = {
  installation_mode = "normal_installed";
  install_url = "file:///nix/store/…/uBlock0@raymondhill.net.xpi";
  default_area = "navbar";
  private_browsing = true;
};
```

- `installation_mode = "normal_installed"` — arrives **enabled**, but stays
  removable from `about:addons`. `force_installed` would make the button
  impossible to get rid of; that is too heavy-handed for a personal machine.
- `install_url` points at the XPI **inside the Nix store**, so nothing is
  fetched from AMO at runtime and the version is pinned by the flake lock.
- `default_area` is the pin: `"navbar"` for the toolbar, `"menupanel"` for the
  unified-extensions (puzzle-piece) menu.

So each preset lists `{ name, area }` rather than a bare name. `name` is the
attribute in `pkgs.nur.repos.rycee.firefox-addons`; the addon ID and XPI path
are derived from `pkg.addonId`.

`default_area` only applies on **first** install into a profile — it seeds the
placement rather than enforcing it, so a button moved by hand afterwards stays
where it was put. Changing `area` later will not shuffle an existing profile's
toolbar.

`privacy.extraExtensions` / `personal.extraExtensions` still take raw packages
and still go through the profile's `extensions/` directory, since they carry no
placement metadata — those will need the manual enable click.

## Bookmarks that carry credentials

Two bookmarks embed a token in their URL. Home Manager renders `bookmarks.html`
into the Nix store, which is world-readable, and this repo is public — so
`bookmarks.nix` keeps them as `@DASHBOARD_TOKEN@` / `@READER_HASH@` and the real
values live only in sops.

The substitution works because `mkUserJs` emits `profiles.<n>.extraConfig`
**after** the generated settings block, so a `user_pref("browser.bookmarks.file", …)`
there wins over the store path HM wrote:

1. HM renders `bookmarks.html` into the store with the placeholders intact.
2. `home.activation.firefoxBookmarkSecrets` copies it to
   `~/.local/share/nix-firefox/bookmarks.html` and runs `replace-secret` for each
   placeholder.
3. `extraConfig` repoints `browser.bookmarks.file` at that copy.

Enable with `personal.bookmarks.secrets.enable = true`, and declare the matching
`sops.secrets` on the host with **`owner = <user>`** — the substitution runs in
the user's Home Manager activation, not as root.

The activation snippet never calls `exit`: a bare `exit` in any activation script
aborts the whole `activate` run and can leave the system unbootable. A missing
secret degrades to a bookmark with a placeholder still in its URL.

## Package collisions

`modules/home-manager/system/apps.nix` drops the `browser` role's *package* when
this module owns it. `programs.firefox`/`programs.librewolf` build their own
wrapped package; installing `pkgs.firefox` alongside puts two derivations that
both ship `policies.json` into the profile, which collides. The role's `command`
still drives the keybinds.

## Host status

| Host | Preset-managed | Browser role (Super+B) | http:// links |
|---|---|---|---|
| gaming-pc | **firefox only** | librewolf (hand-configured, unmanaged) | firefox |
| optiplex | librewolf | librewolf | librewolf |
| vm-sandbox | librewolf | librewolf | librewolf |
| asus-m15, asus-laptop, justus-pc | none | librewolf (package only) | — |

gaming-pc runs both browsers side by side on purpose. Its LibreWolf is
hand-configured, works, and is **deliberately not managed by this module** —
nothing here touches `~/.librewolf`. Firefox is the candidate replacement and
has to prove itself first. That is why the host sets
`browser.firefox.ownsAppRole = false`: Firefox owns `text/html` and every
`xdg-open` from another app, while Super+B still opens LibreWolf.

Do not point the browser role at Firefox there until the checklist at the top of
this file has actually been walked through on a real display.

## ownsAppRole

`customConfig.apps.programs.browser.command` defaults to
`"${pkgs.<browser>}/bin/<exe>"` — the **unwrapped** store path. This module
builds its own wrapped package (policies.json, and the autoconfig prefs when
`overrideConfig = false`), so the keybind, the Waybar button and the XFCE pin
would otherwise start a browser with none of that applied. Verified on
gaming-pc: the two firefox derivations differ, and only the wrapped one carries
`DisableTelemetry`.

So when a preset-managed browser is also on the role, the config block in
`modules/nixos/apps/programs.nix` forces `command` to the bare binary name,
which resolves from the per-user profile. It also keeps the unwrapped duplicate
out of the closure entirely.

`ownsAppRole = false` opts out, for a host that configures one browser while a
different one drives the role. This cannot be detected automatically: deciding
it from `apps.programs.browser.package` would make defining `browser.command`
depend on reading a sibling of the same submodule, which is infinite recursion.
An assertion catches the mismatch instead.

## Adding a chrome theme

Drop a `chrome/<name>.nix` returning a CSS string, then add `<name>` to the
`chromeTheme` enum in `mkBrowserOptions`. Prefer importing an existing palette
(`century-series.nix` reads `themes/century-series/colors.nix`) over restating
hex values.
