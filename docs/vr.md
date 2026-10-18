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
| `/etc/nvidia/nvidia-application-profiles-rc.d/50-wivrn.json` | Stops CUDA (NVENC) holding the GPU in P2 instead of P0 (upstream `docs/nvenc.md`). |

## Daily use

1. Quest Wi-Fi can stay on. Upstream warns that a USB session misbehaves if the headset also
   reaches the server over Wi-Fi, but that path is closed here: `publish-service = null` (no
   avahi announcement) and port 9757 isn't opened in the firewall. Fallback if a session
   stutters: airplane mode for that session, to rule out background downloads.
2. Plug the USB-C cable in. A notification says "Headset detected" → "VR connected".
3. Launch the game from Steam on the desktop, or from the WiVRn/wayvr launcher in the headset.

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

## War Thunder (follow-up, not done)
The native Linux client has no VR. VR needs the Windows client under GE-Proton through
xrizer (already configured here). Gaijin doesn't support Proton, but BattlEye supports it.
Reports describe position jitter and breakage on game updates.
