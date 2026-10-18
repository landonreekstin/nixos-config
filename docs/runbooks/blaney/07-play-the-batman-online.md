# Play The Batman online with Lando

**What's wanted:** Blaney plays Robin in Lando's game of *The Batman* (the 2004 JAKKS TV
game, running natively). Lando hosts on gaming-pc as Batman. Blaney joins over the
homelab VPN. Everything is already in the config:
- `customConfig.programs.batman.enable` in `hosts/blaney-pc/apps.nix`;
- the module is `modules/nixos/programs/batman.nix`;
- the game is `pkgs/batman`.

This task gets it onto blaney-pc and checks that it works with him.

**This task needs the homelab VPN.** That is an exception to the "remote, GitHub only" rule:
the game downloads its ROM from the NAS's public drop, and joins Lando through optiplex-fw.
Blaney switches the VPN on himself, from the network icon in the taskbar → `homelab-vpn`.

**Do this:**
1. **Get the latest config.** Run `update` (it pulls `main` and rebuilds). Then check that
   `command -v batman` finds the launcher, and that the start menu has three new entries:
   "The Batman", "The Batman: Two Players" and "The Batman: Join Online Game". If `update`
   fails, follow the usual rebuild-failure path; don't hand-edit around it.
2. **Turn on the VPN.** Ask Blaney to switch on `homelab-vpn`. Then check that the ROM can be
   reached:
   `curl -sI http://192.168.1.76/public/batman/batman.bin | head -1` should say `200`.
3. **First run.** Ask Blaney to open "The Batman" from the start menu.
   - It downloads the game on first run (4 MB, a few seconds, with a progress window), then
     shows the title screen.
   - Everything it keeps is in `~/.local/share/batman`: the ROM, his save, and Robin's sprites,
     which are generated from the ROM.
   - He can close the game with Esc.
4. **Play online.** Lando starts "The Batman: Host Online Game" on gaming-pc. Blaney opens
   "The Batman: Join Online Game".
   - His window says "Waiting for the game at 192.168.1.76..." until Lando is hosting. Then it
     joins Lando's game wherever it is, and he plays Robin.
   - If Lando quits, Blaney's window goes back to waiting and rejoins the next game by
     itself.
5. **Controls** (tell Blaney): arrows move, Z jumps, X attacks, C searches or opens doors,
   Enter pauses. A controller works too. Esc quits. In the menus only Lando's buttons count.

**Done when:** Blaney has played Robin in Lando's game, and the status line at the bottom of
his window showed a ping.

**If it doesn't work:**
- Every failure shows its reason on screen or in a dialog. The full log is
  `~/.local/share/batman/last.log`.
- **"Couldn't download the game from the homelab"**: the VPN is off or not connected. Check
  `nmcli connection show --active`.
- **"no answer from 192.168.1.76 (is the VPN on?)"** with the VPN on: the firewall rule is
  missing. optiplex-fw must forward port 7845 (TCP and UDP) on `192.168.1.76` from `wg0` to
  `10.10.0.11` (see `docs/networking.md`, "The Batman netplay"). Blaney can't fix that: tell
  Lando.
- **"nobody is hosting at 192.168.1.76 yet"**: the network path works; Lando hasn't started
  hosting. It keeps trying by itself.
- **"the host refused: a different build..."**: the two machines are on different versions
  of `pkgs/batman`. Run `update` here, and ask Lando to update gaming-pc too. Both need the
  same pin.
- Don't change `pkgs/batman` or the module from blaney-pc. If something in them is wrong,
  write down what you saw, tell Blaney to pass it on to Lando, and stop.

**Notes:** no PR is needed unless a config fix turned out to be necessary (then a `blaney/`
branch and a PR, as usual).
