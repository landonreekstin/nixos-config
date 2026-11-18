# Release notes for blaney-pc

Every change insideabush would notice on blaney-pc adds **one new file here**, in the same PR,
from whichever host the work happens on. It pops up for him after the update ("Lando's nix
release notes for you"). See [Release notes](../../../docs/hosts/blaney-pc.md#release-notes).

- **Name:** `YYYY-MM-DD-<short-slug>.nix`, dated the day you write it, for example
  `2026-11-18-keyboard-ripple.nix`. Evaluation fails on any other `.nix` name.
- **Content:** a list of one or more plain-English lines, written for him: what he will see or can
  now do, no jargon, nothing that only touches other machines.
  ```nix
  [
    "Your keyboard ripples outward from each key you press."
  ]
  ```
- **One file per change.** Never edit another note's file to add yours, since he would see that
  note again. Several files on one date show under a single date heading.
- Dependency bumps and refactors get no note, and new `blaney-todo` tasks are listed automatically.
- `../release-notes.nix` is the frozen archive of the notes from before this folder existed.
  Don't add to it.
