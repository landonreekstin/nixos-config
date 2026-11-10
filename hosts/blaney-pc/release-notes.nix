# ~/nixos-config/hosts/blaney-pc/release-notes.nix
# "Lando's nix release notes for you" — shown to Blaney in a popup after an update.
# Not a module: a plain list imported by home.nix. NEWEST FIRST. One short, plain-English
# line per change he would actually notice; no jargon, nothing about other machines.
# New blaney-todo tasks are listed automatically — don't add notes for them.
[
  {
    date = "2026-11-09";
    changes = [
      "Right-click the volume button to pick where sound plays: your headphones, either screen, or a Bluetooth speaker."
    ];
  }
  {
    date = "2026-11-08";
    changes = [
      "A new \"Internet\" squid in your trees shows every time the internet dropped or got laggy, Discord said \"No Route\", Claude had errors, or Lando's VPN or games could not be reached, and whose fault it was: your PC, your router, your internet provider, or Discord, Claude or Lando's side. You can also type net-log."
      "Prism Launcher is installed for Minecraft. It opens CurseForge modpacks, so you can play your modded Minecraft here."
      "Minecraft is in your Games tab: click it and it goes straight into your Immersed With Shaders modpack."
      "Minecraft LAN worlds on your home network now show up in your server list."
    ];
  }
  {
    date = "2026-11-07";
    changes = [
      "Your keyboard lights are a soft teal now, and they stay lit while you type."
      "War Thunder opens full screen now, so the top bar no longer covers the top of it."
      "Hold the Windows key and press Tab to see every open window on both screens. Click the one you want, or keep tapping Tab and let go of the Windows key to jump to it. (Alt+Tab still works like before.)"
      "Your main screen now runs at 120 Hz instead of 60, so everything (games too) moves twice as smoothly."
    ];
  }
  {
    date = "2026-11-06";
    changes = [
      "prin-rpg now lives on Lando's own server instead of GitHub, and you save your changes straight into the game: no more waiting for Lando to merge. Turn the VPN on (top bar) when you work on it."
    ];
  }
  {
    date = "2026-11-05";
    changes = [
      "The squids and owls in the Glade's trees now hold only your own projects. Click one to start that project and try it. New projects get a squid by themselves."
      "The terminal on your dock has a green-on-black screen picture instead of the cat."
    ];
  }
  {
    date = "2026-11-04";
    changes = [
      "The top bar now sits behind your windows, so you can always grab a window that was stuck under it, and fullscreen games cover it."
    ];
  }
  {
    date = "2026-10-30";
    changes = [
      "Sub of Seas got a big update: sounds, music, a settings menu, bot crewmen and a rec room. It also starts without the homelab VPN now (you still need it to join Lando)."
      "VibeNote is now a proper app: open it from your app menu like any other."
      "VibeNote is in your dock and has its own tree squid in the Glade."
      "VibeNote has its own icon now: a glowing green notepad."
      "The top bar now shows whether you're on the VPN: \"VPN on\" glows green, \"VPN off\" is grey. Click it to switch."
    ];
  }
  {
    date = "2026-10-29";
    changes = [
      "The Notes icon is gone from your desktop. Your notes list and the add-notes / work-notes commands still work."
      "After an update, this window now tells you what Lando changed. Type whats-new to see it again."
      "Lando moved your commands (blaney-todo, branch-switch, add-notes, smart-rebuild and the rest) to a new home and couldn't test it on your PC. If one of them acts strangely, that's probably why. Tell Claude in vibe or tell Lando."
    ];
  }
]
