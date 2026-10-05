<!-- ~/nixos-config/docs/theming.md -->
> **Read this when**: working on Plasma/SDDM/Hyprland themes, or adding/editing any
> `modules/home-manager/themes/*` module. The functional-vs-theme split below is the
> rule that governs every Wayland component module in this repo.

# Working with Themes

## Plasma Themes
- `default` - Stock Breeze with this repo's panel/pin layout
- `bigsur` - macOS Big Sur appearance
- `windows7-alt` - AeroThemePlasma. **Mothballed — see below.**

Theme configuration is set via `customConfig.homeManager.themes.kde`.

### AeroThemePlasma (`windows7-alt`) is mothballed

The modules are still in the tree (`modules/nixos/themes/aerothemeplasma/`,
`modules/home-manager/themes/aerothemeplasma/`) but **no host selects them**, so the
gated overlay in `plasma-system.nix` is never applied: the three gitgud sources are never
fetched, the ~9 C++ derivations never build, and those attributes do not exist on `pkgs`
at all. CI no longer builds them either.

Why: the rev in `aerothemeplasma.nix` is versioned against the **Plasma release**, not
against the theme, so it has to be re-pinned every time nixpkgs moves Plasma — and from
`Plasma/6.6` upstream split the KWin half into separate repositories, so moving forward
means packaging new upstreams rather than bumping a hash. That is a build-breaking
maintenance burden on every release upgrade, for a look that the XFCE theme now delivers
without compiling anything.

**The supported Windows 7 route is `customConfig.homeManager.themes.xfce = "windows7"`**
(`modules/{nixos,home-manager}/themes/windows7-xfce/`), which is what blaney-pc and
gaming-pc's XFCE session run. It extracts images and sounds from the same upstream repo
(pinned separately at 6.3.4) and compiles nothing.

If you do re-enable `windows7-alt` on a host, restore the aero target list in
`.github/workflows/check.yml` at the same time — otherwise nothing will build it until a
host rebuild fails.

### KDE applications without Plasma

`customConfig.apps.kdeSuite.enable` (`modules/nixos/apps/kde-suite.nix`) installs konsole,
gwenview, okular, ark, elisa, kcalc, partitionmanager and the Dolphin companions. These
used to arrive only as a side effect of `services.desktopManager.plasma6.enable`, which
made `apps.defaultSet = "kde"` a hidden dependency on the whole Plasma session. It
defaults on for any host with `defaultSet = "kde"` or `"kde"` in `desktop.environments`,
so gaming-pc and blaney-pc keep the KDE app set and their file associations while running
only Hyprland and XFCE.

## Custom SDDM Themes
Configure via `customConfig.desktop.displayManager.sddm.customTheme` with wallpaper, colors, and styling options.

## Hyprland Themes
- `future-aviation` - Sleek aerospace aesthetic with modern fighter jet inspiration
- `century-series` - Cold War aviation cockpit theme (F-100 through F-106, MiG-17/19/21)

Theme configuration is set via `customConfig.homeManager.themes.hyprland`.

## Functional vs Theme Paradigm for Wayland Components

The Wayland component architecture follows a strict separation of concerns between **functional** and **theme** modules:

### Functional Modules (`modules/home-manager/*/functional.nix`)
**Always active** when the component is enabled. Provide:
- **Essential functionality**: Keybindings, startup commands, base settings
- **Hardware configuration**: Monitor layouts, input settings
- **Service management**: Process startup, systemd services
- **Package dependencies**: Required binaries and tools
- **Default configurations**: Base module settings with `mkDefault` priority

Examples:
- `hyprland/functional.nix` - Keybindings, exec-once, monitor config, variables
- `waybar/functional.nix` - Module layout, click actions, base formatting

### Theme Modules (`modules/home-manager/themes/*/`)
**Conditionally active** when theme is selected. Provide only:
- **Visual styling**: Colors, fonts, borders, animations
- **Theme-specific overrides**: Custom formats, icons, CSS styling
- **Wallpapers and assets**: Theme-specific media files
- **Aesthetic configuration**: Gaps, rounding, shadows, effects
- **Priority overrides**: Use `mkForce` for conflicting visual settings

Examples:
- `themes/century-series/hyprland.nix` - MFD borders, cockpit colors, tactical animations
- `themes/century-series/waybar.nix` - Aviation terminology, instrument panel styling

### Key Principles
1. **Themes never duplicate functional settings** - Always inherit base functionality
2. **Functional modules use `mkDefault`** - Allow themes to override with `mkForce`
3. **Settings merge cleanly** - No conflicts between functional base and theme overrides
4. **Themes remain portable** - Can be applied to any host without breaking functionality
5. **Functional modules stay stable** - Theme changes don't affect core functionality

### Example Architecture
```nix
# functional.nix (always active)
bind = mkDefault [
  "$mainMod, SPACE, exec, $menu"
  "$mainMod, RETURN, exec, $terminal"
];

# theme.nix (when theme active) 
general = {
  border_size = mkForce 3;  # Override for theme
  "col.active_border" = "rgb(ff9e3b)";  # Theme colors
};
```

This ensures themes provide visual identity while maintaining core Wayland functionality.

