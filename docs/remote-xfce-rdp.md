<!-- ~/nixos-config/docs/remote-xfce-rdp.md -->
> **Read this when**: working on the XFCE/Windows-7 desktop over xrdp, or debugging why
> a `rebuild` did not visibly change a live XFCE session.

# Remote XFCE via RDP (gaming-pc)

For desktop/theme work that needs a visible session (e.g. the `feat/xfce-windows7`
branch) while working remotely from the Windows 11 box. Enabled by
`customConfig.desktop.xrdp.enable` on gaming-pc (`modules/nixos/desktop/xrdp.nix`).
Port **3389 is firewalled** — access is SSH-tunnel only, never exposed.

**Windows flow:**

1. Open the tunnel (leave it running):
   ```
   ssh -L 3389:localhost:3389 lando@192.168.1.62
   ```
   `192.168.1.62` is gaming-pc on the LAN — substitute its reachable address when off-LAN.
2. Launch **Remote Desktop** (`mstsc`) and connect to **`127.0.0.2`** — NOT `localhost`
   / `127.0.0.1`. Windows throws error `0x708` ("console session in progress") when the
   RDP target looks like the local machine; `127.0.0.2` dodges that self-connect check.
3. Session type **Xorg**, user `lando`, your password → you land in the XFCE session.

**Iteration loop** (no reboot): edit the theme → `rebuild` over SSH → **log out the RDP
session and reconnect**. A fresh session re-seeds the xfconf theme and re-runs the
autostarts, which is exactly the boundary the win7 theme needs.

**Why a plain reconnect/logout often isn't enough — the XFCE daemon-cache problem.** The
XFCE settings stack caches aggressively: `xfconfd` reads the per-channel XML *only at
startup* and never re-reads it, and the consumer daemons apply their state once and hold it
in memory — `xfsettingsd` (GTK theme / Segoe UI / Aero icons / cursor / sounds), `xfwm4`
(window decorations **and** keyboard shortcuts) and `xfce4-panel` (layout + launcher icons).
So a `rebuild` reseeds the XML on disk while the live session keeps the old look/binds.
`xfconfd` is D-Bus-activated and can linger on the user bus across logout, which is why a
change sometimes only takes after a **reboot**. Concrete reload levers (all confirmed): a
new keybind needs `kill -HUP <xfwm4-pid>`; panel launcher icons need the panel restarted;
xsettings needs `xfsettingsd --replace`.

**`win7-xfce-refresh`** (module: `modules/home-manager/themes/windows7-xfce/refresh.nix`,
installed on win7-xfce hosts) bundles those reloads into one command to apply a `rebuild`
without logout/reboot: drop xfconfd's stale cache → `xfsettingsd --replace` → SIGHUP xfwm4 →
re-run the login panel bind (`win7-bind-panels`) → `xfdesktop --reload`. **Run it from a
terminal *inside* the XFCE session** (it needs the full session env — launching the panel from
an external shell without XAUTHORITY/XDG_* leaves it unmapped/invisible). Runtime-verified live
over RDP (2026-08-06). The panel step reuses `win7-bind-panels` (the same seed→`xfce4-panel -r`
the login autostart runs), so the Win7 power flyout's `command-logout` survives a refresh — a
naive panel kill+relaunch would skip the whiskermenu-rc seed and regress the Start power button
to the two-click dialog.

**Gotchas:**
- The remote session runs on its own private D-Bus bus (`dbus-run-session -- startxfce4`)
  so it coexists with the physical KDE/Hyprland login. Use `startxfce4` (the launcher),
  not `xfce4-session` (the bare binary), or the session exits instantly.
- NixOS does **not** auto-restart `xrdp-sesman` on a `rebuild` (restarting it kills live
  sessions), so changes *to the xrdp module itself* only take effect after
  `sudo systemctl restart xrdp-sesman`. Theme changes don't need this — just reconnect.
- No audio (login jingle/event sounds) — needs `pulseaudio-module-xrdp` redirection, not
  wired up.

