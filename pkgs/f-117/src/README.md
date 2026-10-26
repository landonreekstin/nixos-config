# F-117 (Briefing Room)

A calm daily news briefing for the desktop: pages of feeds ranked by how widely each
story is covered, a "Coming Up" horizon of dates and deadlines, a civic checklist, a world
map, and optional AI briefings through the `claude` CLI (each one shows its estimated cost
before it runs).

This is a blank slate. It ships with general news only.

- **Your preferences** (name, what you care about, topics to mute, weather location) are
  set in the app under **My Focus · preferences**.
- **Your own pages and feeds**: copy `sources.json` to `~/.local/share/briefing-room/sources.json`
  and edit it. Add your county/city/state RSS feeds to *Home Front*, your local calendars to
  *Civic Duty*, dated reminders to the checklist's `items`
  (`{"key", "text", "due": "YYYY-MM-DD", "link"}`), or whole new tabs. The app uses that
  file instead of this one when it exists.

Run it with `nix run github:landonreekstin/nixos-config#f-117`.
