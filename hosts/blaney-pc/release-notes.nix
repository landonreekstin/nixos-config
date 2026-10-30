# ~/nixos-config/hosts/blaney-pc/release-notes.nix
# "Lando's nix release notes for you" — shown to Blaney in a popup after an update.
# Not a module: a plain list imported by home.nix. NEWEST FIRST. One short, plain-English
# line per change he would actually notice; no jargon, nothing about other machines.
# New blaney-todo tasks are listed automatically — don't add notes for them.
[
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
