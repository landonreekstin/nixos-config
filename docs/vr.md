# VR on gaming-pc (Quest 2 over USB)

`customConfig.profiles.vr.enable` (`modules/nixos/profiles/vr.nix`) — enabled on gaming-pc.

```
game ──OpenXR──▶ WiVRn server (Monado + NVENC h265 10-bit) ──adb reverse, USB-C──▶ WiVRn app on the Quest
```

| Piece | What it does |
|---|---|
| `services.wivrn` (user unit `wivrn.service`, autostarts) | OpenXR runtime + video encoder. CUDA build for NVENC. |
| xrizer | OpenVR→OpenXR for OpenVR games. Found via the wivrn package's search path; WiVRn writes `~/.config/openvr/openvrpaths.vrpath` itself. |
| `steam.importOXRRuntimes` | `PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1` system-wide — pressure-vessel passes the runtime manifest *and* socket into every Steam game, so no per-game env is needed. |
| wayvr | Desktop/overlay in the headset; WiVRn starts it when the headset connects. |
| udev → `vr-connect.service` | Plugging in the headset (USB vendor `2833`) waits for adb, installs/upgrades the matching headset app, `adb reverse tcp:9757`, opens the app on `wivrn+tcp://localhost`. |
| `amd_x3d_vcache` mode | `vr-connect` sets `cache` (scheduler prefers the V-Cache CCD `0-5,12-17`) for the whole headset session and `frequency` on unplug. Not via `gamemoderun`: it is a /nix/store bash script that dies inside Steam's runtime (`undefined symbol: __pointer_chk_guard`), so a Proton game exits within a second. gamemode's start/end hooks do the same flip for games that can use `gamemoderun`. |
| `xr-srgb-fix` (OpenXR layer, opt-in via `XR_SRGB_FIX=1`) | Undoes Proton's double sRGB encode for D3D11 games (War Thunder's washed-out colours). See [War Thunder](#war-thunder-steam-appid-236390). |
| `/etc/nvidia/nvidia-application-profiles-rc.d/50-wivrn.json` | Stops CUDA (NVENC) holding the GPU in P2 instead of P0 (upstream `docs/nvenc.md`). |

## Daily use

1. Quest Wi-Fi can stay on. Upstream warns that a USB session misbehaves if the headset also
   reaches the server over Wi-Fi, but that path is closed here: `publish-service = null` (no
   avahi announcement) and port 9757 isn't opened in the firewall. Fallback if a session
   stutters: airplane mode for that session, to rule out background downloads.
2. Plug the USB-C cable in. A notification says "Headset detected" → "VR connected".
3. **DCS: click "DCS World (VR)"** in the app launcher (or run `dcs-vr`), then put the headset on
   when the notification asks. It starts WiVRn if needed and waits for a headset session,
   re-sending the connect intent every 10 s (the Quest ignores it while off-head). Then it runs
   `steam://launch/223750/VR`, which skips Steam's OpenXR/Oculus picker. Verified with the
   headset plugged in first. **War Thunder: "War Thunder (VR)"** (`wt-vr`), the same flow; see
   [War Thunder](#war-thunder-steam-appid-236390). **Phasmophobia: "Phasmophobia (VR)"**
   (`phasmo-vr`); see [Phasmophobia](#phasmophobia-steam-appid-739630). Other games: launch from Steam with the headset
   already streaming.

Manual fallbacks: `vr-connect` (same thing the udev rule runs), `vr-client-install`,
`journalctl --user -u wivrn -u vr-connect`.

## One-time setup

1. Meta Horizon phone app → the headset → Developer Mode on (needs a Meta developer org).
2. Plug in, put the headset on, accept **Allow USB debugging** with *Always allow* ticked.
3. On the first connection the server may show a pairing PIN (`journalctl --user -u wivrn`); enter it in the headset.

### Client/server version pinning
The headset app must match the server version exactly. `vr.nix` pins the GitHub
`WiVRn-release.apk` hash per `pkgs.wivrn.version`; when a flake update moves wivrn,
evaluation fails with the `nix-prefetch-url` command to run. Add the new hash to
`apkHashes`, rebuild, plug in — `vr-connect` upgrades the headset app by itself.

## DCS World (Steam appid 223750)

1. Install DCS in Steam. Steam's default library is on `/`; `/mnt/games/SteamLibrary` has more room.
2. Quit Steam fully, run `dcs-vr-setup`. It sets the compat tool to GE-Proton (keeping any GE-Proton build already chosen in Steam — GE-Proton10-34 on gaming-pc) and these launch options:
   `PROTON_ENABLE_NVAPI=1 WINEDLLOVERRIDES=wbemprox=n %command% --no-launcher --force_enable_VR --force_OpenXR`
   (`dcs-vr-setup flat` writes the same without the VR flags.)
3. Start DCS once to create the Proton prefix, quit, then run `dcs-vr-setup` again. That installs
   consolas/corefonts/d3dcompiler_47/xact (best effort — xact fails under GE-Proton10-34 and is skipped; Proton has FAudio built in) and imports the `HKCU\Software\Wine\VR` keys that
   wineopenxr needs (from the [LVRA DCS page](https://vronlinux.org/docs/games/dcs-world/)).

### Quality tuning (Quest 2 + 4070 Ti SUPER)
- WiVRn does no motion reprojection (only rotational timewarp on the headset), so a **locked**
  frame rate matters more than a high one. Start at 72 Hz; move to 80/90 only with headroom.
- Resolution scale and bitrate live in the **headset app's settings**, not config.json.
- In DCS: Pixel Density 1.0 (WiVRn's scale owns resolution), DLAA or DLSS Quality via NVAPI,
  MSAA off. Watch frame time with MangoHud (`MANGOHUD=1` in front of `%command%`).

Verified 2026-10-18: 72 Hz (WiVRn settings → Refresh rate, automatic off), default scale and
bitrate. The MiG-21 flew smoothly in VR with the HOTAS. Raise refresh/scale/bitrate from here only if frame time allows.

### Desktop windows / browser while flying
- To show the wayvr overlays, **double-tap Y**. To open the **dashboard**, look at your left wrist and click the watch's wayvr button.
- A mirrored *desktop* window (e.g. Firefox on Hyprland) shows fine, but it gets clicks only
  through the real mouse cursor, which DCS keeps locked. So the controller trigger does nothing there.
- For anything you need to click, launch **Firefox (VR)** from the dashboard's app list. It is a separate Firefox instance
  (`vr-browser`, own profile under `~/.local/share/vr-browser`) running in wayvr's nested
  display, which takes controller input directly. It has to be a separate instance: otherwise the launch is
  handed to the desktop Firefox and the window opens on Hyprland. Verified in DCS 2026-10-18.

### Gotchas
- **Connect the headset before launching DCS.** WiVRn only provides the OpenXR runtime while a
  headset is connected. Without one, DCS logs `XR_ERROR_RUNTIME_UNAVAILABLE` and starts flat on the desktop.
- Steam's launch picker: choose **OpenXR**. "Oculus VR" needs Meta's Windows runtime.
- To open WiVRn's own window (settings, stats, disconnect) during a stream, **click both thumbsticks**.
- **Don't `rebuild` during a VR session.** The switch re-executes the user systemd manager, and
  wivrn-server 26.6.2 segfaults in `systemd_units_manager::on_unit_result`. The unit restarts
  on its own, but the headset drops to the Quest menu; replug or run `vr-connect`.
- Pairing lives in `~/.config/wivrn/known_keys.json` (`wivrnctl list-paired`); the unit creates
  the directory, because the server doesn't and would otherwise forget the headset on every restart.

## War Thunder (Steam appid 236390)
The native Linux client has no VR, so this uses the **Windows client under GE-Proton**. Gaijin
doesn't support Proton. BattlEye runs under it via Valve's Proton BattlEye Runtime (see setup).
Online play passing BattlEye under Proton is Gaijin's server-side opt-in. If a game update
brings back "anti-cheat is not loaded", that is why, and the native client (no VR) is the fallback.
The Windows client speaks **OpenXR natively** (`win64/openxr_loader.dll`), so it talks to
WiVRn through wineopenxr like DCS does; xrizer is not involved.

**Daily use:** plug the headset in, then click **"War Thunder (VR)"** (or run `wt-vr`). It is the same
launcher as DCS's (`mkVrLauncher` in vr.nix): it waits for the headset session, then runs
`steam://launch/236390/VR`. That is Steam's own hidden VR entry,
`beac_wt_mlauncher.exe -config:gameplay/enableVR:b=yes`. Steam's normal "Launch Game" entry
passes `enableVR:b=no` and always starts flat.

**One-time setup:**
1. In Steam → War Thunder → Properties → Compatibility, pick a GE-Proton so Steam downloads the
   Windows client (~90 GB).
2. Install **GE-Proton11-9 or newer** into `~/.local/share/Steam/compatibilitytools.d`
   ([releases](https://github.com/GloriousEggroll/proton-ge-custom/releases); nixpkgs'
   `proton-ge-bin` was still 11-7 on 2026-10-18). The tarball's directory name is fine as is,
   because Steam maps games by the tool's *internal* name (`GE-Proton11-9-x86_64`).
3. Install the **Proton BattlEye Runtime**: `steam steam://install/1161040`. Without it the game
   runs but online play refuses with "anti-cheat is not loaded". Once it's installed, Steam passes
   `PROTON_BATTLEYE_RUNTIME` to the game by itself. With it installed (2026-10-19), sim battles
   queued. A full match had not been played yet.
4. Quit Steam, run `wt-vr-setup`. It checks for the BattlEye runtime, maps the game to the newest
   GE-Proton11, and sets the launch options to `PROTON_DISABLE_NVAPI=1 XR_SRGB_FIX=1 %command%`.

No registry keys or winetricks are needed: GE-Proton 11 writes the `HKCU\Software\Wine\VR`
keys itself at start-up, provided WiVRn is reachable.

Verified 2026-10-18: a test flight in VR on DX11 at 72 Hz with correct colours, mouse working,
no stutter.

### Why each piece is needed (all found the hard way)
- **GE-Proton 11-9+, not 10-x or 11-7.** War Thunder calls `xrConvertWin32PerformanceCounterToTimeKHR`
  every frame to locate the eyes. wineopenxr in GE-Proton10-34 and 11-7 stubs it out (`FIXME`,
  `XR_ERROR_INITIALIZATION_FAILED`). The game then gets no pose, `xrLocateViews` returns
  `XR_ERROR_TIME_INVALID`, and the headset *and* the mirror stay black while sound plays.
  Proton 11 implements it ([Proton#9347](https://github.com/ValveSoftware/Proton/pull/9347)).
- **DX11 (the default `driver:t="auto"`).** DX12 refuses under Wine ("Unsupported OS") and falls back
  to DX11. `driver:t="vulkan"` does reach the headset, but tracking jitters badly and the mirror is black.
- **`xr-srgb-fix` (washed-out colours).** Windows runtimes give D3D11 apps *typeless* swapchain
  textures. wineopenxr gives them typed `*_SRGB` ones, so War Thunder's own gamma is encoded a
  second time: the headset looks pale while the desktop mirror looks right.
  `modules/nixos/profiles/vr-srgb-fix/` is a host-side OpenXR API layer that runs between
  wineopenxr and WiVRn. On each `xrReleaseSwapchainImage` of an 8-bit sRGB colour swapchain it
  copies the image to a UNORM scratch image, runs one sRGB→linear compute pass, and copies it back.
  - It is an implicit layer, enabled only when `XR_SRGB_FIX` is set (per-game launch option), so
    DCS is untouched. `XR_SRGB_FIX_DISABLE=1` turns it off for a run.
  - It runs on the Linux side, outside the game's Windows process, so BattlEye never sees a
    modified file. The alternative, patching `wineopenxr.dll` to return typeless textures, was
    rejected for that reason.
  - It must **never block** in release. wineopenxr holds DXVK's submission lock during the call,
    and an unbounded `vkWaitForFences` there froze the game on its first frames: black headset,
    then Gaijin's "Freeze" crash report. If a previous pass is still running, it skips that frame
    and logs a count.
  - Hiding the sRGB formats instead (forcing a UNORM swapchain) doesn't work: War Thunder then
    silently never starts VR.
  - The manifest is linked into `~/.local/share/openxr/1/api_layers/implicit.d/` by a user tmpfiles
    rule, because Steam's container sees `$HOME` and `/nix/store` but not the host's `/etc/xdg`.
    The link is refreshed at login; after a rebuild that changes the layer, run
    `systemd-tmpfiles --user --create`.
- **XWayland primary output.** XWayland lists outputs in its own order, with no primary set, so
  the fullscreen Wine window opened on a side monitor. The mouse then only worked there and the
  game window was the wrong size. Hyprland's `exec-once` now runs `xrandr --output <main> --primary`
  (the monitor named `main`, as in the XFCE config). Run it by hand if Hyprland was started from an
  older generation.
- **`PROTON_DISABLE_NVAPI=1`.** Game build 2.59.0.78 (2026-10-20) crashes ~2 s in (seen in flat
  mode; VR goes through the same DX11 start-up):
  an access violation in `nvapi64.dll` (dxvk-nvapi) right after the `adapter <NVIDIA ...>` log
  line, before any window opens. 2.59.0.73 ran fine with it on the same GE-Proton11-9. Disabling
  NVAPI costs DLSS/Reflex, which are off in our settings anyway. Worth retrying without it after a
  later GE-Proton or game update. To find the faulting module, read the exception stream of the
  minidump in `.game_logs/reports/`.

### Gotchas
- **The headset must be streaming before the game starts**, as with DCS. GE-Proton 11 removes
  its OpenXR registry keys when the runtime isn't reachable at start-up
  (`get_vulkan_extensions ... status 0x2` in a `PROTON_LOG=1` log). The game then runs flat.
- **The login session must carry `PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1`.** If Hyprland was
  started under a generation without the VR profile (e.g. another worktree owned the live
  system at boot), Steam can't see WiVRn and every game starts flat. Log out and back in. To fix it
  live instead: `hyprctl keyword env PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES,1`, then
  `systemctl --user set-environment PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1`, then restart Steam.
- War Thunder's logs (`.game_logs/*.clog`) are XOR-obfuscated with a 128-byte repeating key. To
  read them, recover the key from byte frequency: per position mod 128, assume the most common
  plaintext byte is a space. Look for `[XR][device]` lines.
- Reports elsewhere mention breakage after game updates. If VR stops working after a patch, check the
  `.clog` for `[XR]` errors first.

## Phasmophobia (Steam appid 739630)
Windows build under GE-Proton. The game uses Unity's OpenXR plugin
(`Phasmophobia_Data/Plugins/x86_64/openxr_loader.dll`), so like War Thunder it reaches WiVRn
through wineopenxr, and xrizer is not involved. No anti-cheat.

**Daily use:** plug the headset in, then click **"Phasmophobia (VR)"** (or run `phasmo-vr`).
This uses the same `mkVrLauncher` as DCS and War Thunder and ends with `steam://launch/739630/VR`, which is
Steam's "Phasmophobia in VR (exc. Steam Home)" entry (`Phasmophobia.exe --enable-vr`).

**One-time setup:** quit Steam and run `phasmo-vr-setup`. It maps the game to the newest
GE-Proton11 (11-9 or newer, for the same wineopenxr reason as War Thunder) and resets its
launch options to plain `%command%`.

Verified 2026-10-26: starts in VR from the launcher on GE-Proton11-9; no colour fix needed.
