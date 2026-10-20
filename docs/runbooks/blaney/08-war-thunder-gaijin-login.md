# Log into War Thunder with your Gaijin account

**What's wrong:** when Blaney starts War Thunder from Steam, it signs him straight into the
War Thunder account tied to his **Steam** account, which has none of his progress. His real
account (all his vehicles and research) is a **Gaijin.net** account, signed in with email +
password. On Windows he can get the Gaijin launcher to show its login screen; on blaney-pc he
can't, because Steam logs him in automatically and there's no way to switch.

**What's wanted:** a War Thunder entry in his start menu that opens the Gaijin login, so he
plays on his Gaijin account. Starting it from Steam can keep doing what it does now.

**Background (check it, don't trust it blindly):**
- Steam's War Thunder (appid 236390) uses Steam's login. The game gets a Steam ticket and
  Gaijin signs in whichever Gaijin account is bound to that Steam account. Nothing in Steam's
  copy offers a "use a different account" option on Linux.
- Gaijin also ships a **standalone native Linux client** (warthunder.com → Download → Linux).
  Its launcher has its own email/password login (plus Gaijin's 2FA, if he has it on). It doesn't
  need Steam. This is the reliable way to reach the Gaijin login.
- That launcher is a generic-Linux binary, so on NixOS it needs an FHS environment
  (`steam-run`, or a `buildFHSEnv`) to start.
- blaney-pc has `profiles.gaming.enable = true` (`hosts/blaney-pc/profiles.nix`) and Steam,
  Lutris and Heroic. There's no War Thunder-specific config here yet. gaming-pc's War Thunder
  setup in `docs/vr.md` is the **Windows client under Proton, for VR**. Don't copy it; it's
  unrelated to this.

**Do this:**
1. **Look at what's there first.** Is War Thunder installed in Steam
   (`~/.local/share/Steam/steamapps/appmanifest_236390.acf`)? Is it the native Linux build
   or Proton (Properties → Compatibility)? How big is the install, and how much free disk is
   there (`df -h ~`)? The game is roughly 30–90 GB depending on what's downloaded.
2. **Quick try, no config change:** the Steam install's game folder contains Gaijin's own
   `launcher` binary. With Steam fully closed, run it from that folder under `steam-run`,
   **outside** Steam (no Steam env vars; temporarily move any `steam_appid.txt` aside if
   one is there). If it shows the Gaijin login, this is a strong lead. Note what you saw.
   Don't leave the Steam install changed: put back anything you moved.
3. **Make it permanent, declaratively.** Use whichever approach step 2 points to. If it
   showed nothing useful, the standalone client is the default:
   - Add an opt-in module, e.g. `customConfig.programs.warThunder.enable` in
     `modules/nixos/programs/war-thunder.nix`, enabled in `hosts/blaney-pc/apps.nix`.
     `modules/nixos/programs/batman.nix` is the precedent: launcher script + desktop
     entries + first-run download into `~/.local/share/<game>`.
   - The launcher wrapper runs Gaijin's Linux `launcher` inside an FHS env. On first run it
     downloads the standalone launcher into a user dir (e.g. `~/.local/share/WarThunder`),
     then hands over to it. The game files stay in that user dir, **not** in the Nix store:
     the launcher updates itself and the game in place.
   - If Steam already has the native Linux game downloaded, have the Gaijin launcher reuse
     those files instead of downloading again. Copy them (or point the launcher at a copy),
     but don't share one folder between Steam and the standalone launcher: each updater
     fights the other.
   - Start-menu entry named plainly, e.g. "War Thunder (Gaijin account)". Ask Blaney
     what he wants it called and whether he wants it on the taskbar too. Those are his
     decisions.
4. `chown`, `rebuild`, then have Blaney open the new entry. **He types his Gaijin email and
   password himself.** Never ask him for them, and never put them in the repo or a script.
5. Have him confirm it's his real account: his nation/vehicles/research level should match
   what he sees on Windows. Then have him start a test drive or a quick battle to be sure
   the game itself launches, not just the launcher.
6. Commit on a `blaney/` branch and open a PR. In the PR, say which approach worked and why.

**Done when:** Blaney clicks the new start-menu entry, signs in with his Gaijin account, sees
his own progress, and gets into a match or test drive.

**Don't:**
- **Don't bind, link, or merge accounts.** Leave Gaijin's "link Steam account" / account
  binding settings alone, on both the website and in the game. Binding is effectively
  permanent and could cost Blaney progress. If that turns out to be the only way, stop and tell
  Blaney to ask Lando.
- Don't change Steam's own War Thunder launch options or compatibility setting to force this.
  Steam should keep working as it does now.
- Don't run the Windows Gaijin launcher under Wine/Proton for this. The native Linux client
  is the supported path, and BattlEye under Proton is Gaijin's opt-in, which can be withdrawn.

**Notes:**
- Blaney types his own credentials and any 2FA code. If he has Gaijin's 2FA app on his
  phone, tell him to have it handy before he opens the launcher.
- If the launcher window opens blank or crashes, run it from a terminal under the FHS env
  and read its output. Missing libraries mean the FHS env needs more `targetPkgs`; add them
  in the module. Don't patch the binary.
- If the game can't be made to work at all, write down what you tried and what failed, tell
  Blaney to pass it on to Lando, and stop. Don't open a PR for a half-working setup.
