# Get Bluetooth working (the icon is missing from the taskbar)

**What's wrong / what's wanted:** Blaney's XFCE system tray has no Bluetooth icon, and he
cannot connect Bluetooth devices from NixOS. **The same PC connects Bluetooth fine when booted
into Windows**, so the hardware exists — this is a Linux-side driver/firmware/state problem,
not a missing tray entry.

**Where:**
- `hosts/blaney-pc/home.nix` (~line 32) — `trayApplets` already includes `"bluetooth"`
- `modules/home-manager/themes/windows7-xfce/panel.nix` (~line 369) — autostarts `blueman-applet`
- `modules/nixos/common/audio.nix` — `hardware.bluetooth.enable = true` (all hosts)
- `hosts/blaney-pc/hardware.nix` — `customConfig.hardware.unstable = false` (stable 6.12 LTS kernel)

## What is already ruled out — do not "fix" these

| Setting | Value on blaney-pc |
|---|---|
| `xfcePanel.trayApplets` | contains `"bluetooth"` |
| `hardware.bluetooth.enable` | `true` |
| `hardware.bluetooth.powerOnBoot` | `true` |
| `hardware.enableRedistributableFirmware` | `true` |

Do **not** add the tray applet again — it is already autostarted. **The missing icon is a
symptom:** blueman 2.4 deliberately *hides* its tray icon whenever bluetoothd reports no
adapter (`StatusIcon.query_visibility` — visible only if `Manager.get_adapters()` is non-empty
or the radio is soft-blocked). So "no icon" almost certainly means "Linux sees no working
Bluetooth controller". Fix the controller and the icon appears on its own.

## Step 1 — diagnose (state which case it is before changing anything)

```bash
bluetoothctl list                       # empty = no controller registered
systemctl status bluetooth --no-pager
rfkill list
lsusb                                   # find the BT device (often the same chip as the WiFi dongle)
lspci -nnk | grep -iA3 -E "network|wireless"
sudo dmesg | grep -iE "bluetooth|btusb|hci|rtl_bt|btmtk|btintel|firmware" | tail -40
pgrep -a blueman
uname -r
```

| What you see | Case |
|---|---|
| dmesg: `firmware ... failed to load` / `direct firmware load ... failed` | **A** — firmware |
| dmesg: `hci0: command 0x.... tx timeout`, `Reading ... version failed`, `setup failed` | **B** — adapter left wedged by Windows |
| No BT device in `lsusb`/`lspci` at all, or the device has no driver bound | **C** — kernel too old for the chip |
| `rfkill` shows `Hard blocked: yes` | **D** — hard block (BIOS switch / Windows airplane state) |
| `bluetoothctl list` shows a controller but still no icon | **E** — applet problem |

## Step 2 — fix

- **A (firmware):** note the exact filename dmesg asked for. Check it exists under
  `/run/current-system/firmware/` (the `rtl_bt/`, `mediatek/`, or `intel/` dirs). If missing
  from linux-firmware, try `hardware.enableAllFirmware = true` (needs unfree) in
  `hosts/blaney-pc/hardware.nix`, or the newer kernel per case C.
- **B (Windows left it wedged):** almost always **Windows Fast Startup** (hibernated Windows
  keeps the combo chip in a state Linux cannot initialise). Ask Blaney to boot Windows once and
  turn off Fast Startup (Control Panel → Power Options → "Choose what the power buttons do" →
  untick "Turn on fast startup"), then shut down, **unplug the PC for 30 s**, boot NixOS. You
  do this part with him — it is a click-path, not a terminal command. No repo change needed.
- **C (kernel too old):** the host is on stable 6.12 LTS (`unstable = false`) because of older
  NVIDIA hardware. Check whether the chip's USB/PCI ID is supported in a newer kernel before
  flipping that; if it is, try `customConfig.hardware.unstable = true` on the branch and
  confirm NVIDIA still works too. If NVIDIA breaks, revert and tell lando in the PR.
- **D (hard block):** BIOS setting or Windows airplane mode; clear it there, then case B's cold boot.
- **E (applet):** check `journalctl --user -b | grep -i blueman`. Enable
  `services.blueman.enable = true` (currently `false` on every host — it installs the
  `blueman-mechanism` system helper the applet's power toggle needs). Because that affects the
  shared theme, set it in a host file (`hosts/blaney-pc/apps.nix`), not the shared module.

## Do this

1. Diagnose per step 1 and say which case it was.
2. Fix per step 2. If the fix is purely Windows-side / power-cycle (case B/D), say so plainly —
   no PR needed.
3. If there is a config change: branch `blaney/fix-bluetooth`, chown, `rebuild`, **reboot**,
   verify, commit, open a PR, and stop.

**Done when:** after a cold boot into NixOS, `bluetoothctl list` shows a controller, the
Bluetooth icon is in the XFCE tray, and Blaney pairs and uses one of his real devices (ask
him which — headphones, controller, etc.) — and it still works after a second reboot.

## Traps

- **Dual-boot pairing keys.** A device paired in Windows is *not* paired in Linux; it must be
  re-paired from NixOS, and doing so usually breaks its Windows pairing (each OS generates its
  own link key). Warn Blaney before pairing so he isn't surprised next time he's in Windows.
  Syncing keys between the OSes is possible but out of scope — mention it in the PR if he cares.
- **Don't "fix" by forcing the icon visible.** An icon with no controller behind it does nothing.
- Test in the **XFCE** session — KDE has its own Bluetooth widget and does not use blueman.
