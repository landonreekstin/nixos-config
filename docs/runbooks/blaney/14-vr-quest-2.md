# Play DCS, War Thunder and Phasmophobia in VR on your Quest 2

**What's wanted:** Blaney's own Quest 2, plugged into blaney-pc with a USB-C cable, playing
the same three VR games lando plays on gaming-pc: DCS World, War Thunder and Phasmophobia.
Everything is already built and verified on gaming-pc (`customConfig.profiles.vr`,
`modules/nixos/profiles/vr.nix`, **read `docs/vr.md` first**). Nothing in it is gaming-pc
specific, so this task is: turn it on, set the games up, get his headset connected.

**Do runbook 08 (War Thunder Gaijin login) first** if it is still in the queue. See the War
Thunder note under Part 3.

**Hardware (already checked):** RTX 3060, which does NVENC 10-bit HEVC fine. The CPU is a
non-X3D Ryzen, so vr.nix's V-Cache switching does nothing there (it is guarded). The headset
is his own Quest 2 and is **not** in Developer Mode yet.

## Part 1: config (Claude, can run unattended)

1. Branch `blaney/vr-quest-2`. In `hosts/blaney-pc/profiles.nix` add `vr.enable = true;` to
   `customConfig.profiles`, with a one-line comment pointing at docs/vr.md.
2. Add a line to `hosts/blaney-pc/release-notes.nix`, newest first, plain English, e.g.
   "VR is ready: plug your Quest 2 into the PC and click DCS World (VR), War Thunder (VR) or
   Phasmophobia (VR) in your app menu."
3. chown, `rebuild`. **No headset may be streaming during the rebuild** (the switch crashes
   wivrn-server mid-session; see docs/vr.md → DCS → Gotchas).
4. Check: `systemctl --user -M insideabush@ is-active wivrn` is `active`; `vr-setup`,
   `dcs-vr`, `wt-vr`, `phasmo-vr` are on PATH; the three "(VR)" entries are in his app menu.
5. **His login session has to restart once.** Steam only sees WiVRn when the session carries
   `PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1`, and a rebuild doesn't add it to a session
   that is already running. Tell Blaney to log out and back in, or reboot, before playing.
   Otherwise every game starts flat.
6. **Steam setup: run `vr-setup` as him, never as root.** Claude runs as root on blaney-pc,
   and the script edits `$HOME/.local/share/Steam`:
   `runuser -u insideabush -- env HOME=/home/insideabush XDG_RUNTIME_DIR=/run/user/$(id -u insideabush) vr-setup`.
   It closes Steam if it is open (warn him first if he's in a game), sets all three games
   up **whether or not they are installed yet**, and reopens Steam with the Proton BattlEye
   Runtime install dialog if that is missing. Each game must report `Using GE-Proton
   (GE-Proton11-NN)` with NN ≥ 9: that is the Nix `proton-ge-bin`, nothing to download.
7. Check disk space (`df -h ~` and any other Steam libraries). On gaming-pc they take
   DCS 268 GB (with extra maps; a fresh free install is smaller), War Thunder's **Windows**
   client 93 GB, Phasmophobia 45 GB. If there isn't room
   for all three, tell him plainly and let him choose.

If running unattended, stop here: open the PR as a **draft**, list Parts 2–4 as waiting
for Blaney, and say whether he needs to log out (step 5).

## Part 2: his headset (Blaney, in person; Claude walks him through it)

One step at a time, in plain words. He does these, Claude can't:

1. **Developer Mode.** Phone → Meta Horizon app → Devices → his Quest 2 → Headset settings →
   Developer Mode → on. The first time, Meta asks him to create a "developer organisation"
   at developer.oculus.com (any name, e.g. his own) and may want a verified phone number or
   payment method on his Meta account. Then restart the headset.
2. **Plug in** the USB-C cable (PC first, then headset), put the headset on.
   A notification says "Headset detected". In the headset: **Allow USB debugging** → tick
   **Always allow from this computer** → OK. `vr-connect` then installs the WiVRn app by
   itself ("VR: installing headset app").
3. **Pairing code.** A notification "VR pairing code: 123456" appears on the PC. He types it
   into WiVRn in the headset. Only needed once. **This notification path is new and has
   not been seen on real hardware yet** (only its D-Bus reads were checked, on gaming-pc).
   If it doesn't appear, read the code from `journalctl --user -M insideabush@ -u wivrn | grep PIN`
   and tell lando in the PR.
4. He should now see his desktop in the headset (wayvr). To open WiVRn's own menu in the
   headset: click both thumbsticks.

## Part 3: the games (Blaney installs, Claude checks)

- Install in Steam: **DCS World** and **War Thunder** are free, **Phasmophobia** he has to
  own. Because Part 1 ran `vr-setup` first, they install already set up for VR. No need to
  run it again, unless he deletes and reinstalls a game.
- Then, with the headset plugged in: click **DCS World (VR)** / **War Thunder (VR)** /
  **Phasmophobia (VR)** once. Notifications go "Starting … in VR" → "… is loading" → game in
  the headset. The first start of each takes a minute or two (Proton sets up the game);
  don't let him click twice.
- **War Thunder account:** VR only works in Steam's War Thunder (the Windows client under
  Proton). That signs in with the War Thunder account tied to his **Steam** account, not his
  Gaijin.net one (runbook 08). Whatever 08 set up, check which account VR War Thunder ends
  up on and tell him plainly. Don't try to make VR use the standalone client: the native Linux
  client has no VR.

## Part 4: if something goes wrong (all seen on gaming-pc 2026-11-02)

| What he sees | What it is | Fix |
|---|---|---|
| Headset: "cannot connect to localhost: connection refused", over and over | USB link re-enumerating every few seconds: `journalctl -k \| grep "usb .*USB disconnect"` shows dozens. vr-connect restarts on each, and the adb tunnel dies with it. On gaming-pc it stopped once nothing reconnected for a while; cable and port were fine. | `systemctl --user -M insideabush@ mask --runtime vr-connect`, `pkill -u insideabush -x adb`, wait 30 s and confirm no new disconnects, then `unmask --runtime` and replug. If it keeps happening on every plug-in, add a settle delay/debounce to vr-connect in vr.nix and tell lando. |
| Headset connects but stays **black** | The WiVRn session left stuck by a messy connect (log only says `failed to recenter local spaces`). | `systemctl --user -M insideabush@ restart wivrn`, then replug or reopen WiVRn in the headset. |
| Clicking a game does nothing; Steam log says `DCS.exe: cannot execute binary file` | Steam doesn't see GE-Proton. Fixed in `profiles/gaming.nix` (a bare `steam` package used to shadow `programs.steam`). | Check `steam` on PATH carries `STEAM_EXTRA_COMPAT_TOOLS_PATHS` (in its fhsenv `etc/profile`), and that Steam was restarted after the rebuild. |
| Game starts **flat** on the monitor | No headset session when the game started, or the login session predates the VR profile (Part 1 step 5). | Headset streaming first, then the launcher. Log out/in once. |
| Fullscreen game opens on the **lower** monitor, mouse stuck there | XWayland primary output; see docs/vr.md → War Thunder → "XWayland primary output". Hyprland sets it for the monitor named `main`. | Check under whichever session he plays in (XFCE or Glade). |
| War Thunder: black fullscreen after **Exit** | Known, harmless, happens on every Proton build. | Close it from the taskbar / force-quit. A minidump in `.game_logs/reports/` is expected. |
| Phasmophobia: "Uploading Crash Report" in Player.log | A `NullReferenceException` in the game's own `VRLocalPlayerCalibrator`; it carries on to the VR menu. | Nothing. |
| Anything after a `rebuild` while in the headset | wivrn-server crashes when the switch re-executes the user manager. | Replug, or `vr-connect`. Don't rebuild mid-session. |

Logs: DCS `…/compatdata/223750/pfx/drive_c/users/steamuser/Saved Games/DCS/Logs/dcs.log`
(look for `LAUNCH IN VR OpenXR` and `END OF INIT`); Phasmophobia `…/compatdata/739630/…/Kinetic Games/Phasmophobia/Player.log`
(`XR_SESSION_STATE_FOCUSED`); War Thunder `.game_logs/*.clog` (XOR'd, see docs/vr.md).
WiVRn: `journalctl --user -M insideabush@ -u wivrn -u vr-connect`.

**Done when:** each game he has installed starts in VR in his headset from its "(VR)" menu
entry with one click, and he's told how to plug in and play next time. Open the
`blaney/vr-quest-2` PR (not a draft), saying which games he tested and whether the pairing
notification appeared. Delete this runbook in that PR.

**Notes:**
- Quality settings (refresh rate, resolution scale, bitrate) live in the WiVRn app's settings
  in the headset, not in config. A 3060 has less headroom than gaming-pc's 4070 Ti SUPER:
  keep 72 Hz and lower the resolution scale before anything else if DCS stutters.
- Don't touch `vr.nix` for anything gaming-pc specific; if a fix is needed, keep it generic
  and say in the PR that lando should re-test on gaming-pc.
