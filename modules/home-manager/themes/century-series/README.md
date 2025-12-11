# Century Series - Cold War Aviation Cockpit Theme

A comprehensive Hyprland theme inspired by Cold War-era fighter jet cockpits, specifically the Century Series fighters (F-100, F-101, F-102, F-104, F-105, F-106) and their Soviet counterparts (MiG-17, MiG-19, MiG-21).

**✅ Status**: Fully functional and tested (December 2024)

## Design Philosophy

This theme recreates the aesthetic of 1950s-1960s military aviation cockpits, featuring:

- **CRT Phosphor Displays**: Terminal and UI elements use amber and green phosphor colors reminiscent of early radar and flight instrument displays
- **MFD-Style Borders**: Window borders emulate Multi-Function Display bezels with visible frames and button layouts
- **Instrument Panel Layout**: Waybar and widgets are designed like cockpit instrument clusters
- **Warning Light System**: Notifications styled as master caution/warning lights
- **Gunmetal & Steel**: Color palette based on aircraft aluminum, steel, and panel materials
- **Tactical Typography**: Monospace fonts that evoke military stencil markings

## Color Palette

### Base Colors (Panel & Structure)
- **Panel Black** (`#0a0e14`) - Deep instrument panel background
- **Secondary Panel** (`#1a1f29`) - Raised panel sections
- **Tertiary Panel** (`#141920`) - Control surfaces
- **Gunmetal Frame** (`#2a3441`) - MFD bezels and structural elements
- **Active Border** (`#4a5568`) - Focused window frames

### Accent Colors (Displays)
- **Amber CRT** (`#ff9e3b`) - Primary accent, radar altimeter displays
- **Phosphor Green** (`#7fda89`) - Secondary accent, attitude indicators
- **Radar Green** (`#39ff14`) - High-intensity radar displays
- **Steel Blue** (`#5ccfe6`) - Informational elements

### Warning System
- **Warning Red** (`#ff3838`) - Master warning/critical alerts
- **Caution Amber** (`#ffb454`) - Advisory warnings
- **Info Blue** (`#5ccfe6`) - Informational messages

### Text Colors
- **Instrument White** (`#e6e1cf`) - Primary markings
- **Dimmed Text** (`#a6a69c`) - Secondary labels
- **Subdued Text** (`#6a6a5e`) - Tertiary information

## Components

### Hyprland
- ✅ MFD-style window borders with 3px bezel frames
- ✅ Amber accent borders for active windows with subtle glow effect
- ✅ Rectangular rounding (cockpit displays are angular)
- ✅ Dim inactive windows like unpowered displays (15% strength)
- ✅ Proper functional/theme separation maintains all keybindings
- ✅ Compatible with latest Hyprland (deprecated properties removed)

### Waybar (Instrument Panel)
✅ **Fully Functional** - Waybar is configured as a full instrument panel with:

**Workspace Labels** - Tactical mode indicators:
- ✅ `NAV` - Navigation (workspace 1)
- ✅ `COM` - Communications (workspace 2) 
- ✅ `SYS` - Systems (workspace 3)
- ✅ `WPN` - Weapons (workspace 4)
- ✅ `ECM` - ECM/Misc (workspace 5)

**Visual Features**:
- ✅ Instrument panel background styling
- ✅ Amber accent colors for active workspaces
- ✅ Mission chronometer clock styling
- ✅ Module borders resembling cockpit readouts
- ✅ System tray integration
- ✅ Tooltip styling for information displays

**System Monitors** - Styled as cockpit gauges:
- ✅ **CPU** - Processor usage monitoring
- ✅ **Memory** - RAM usage display
- ✅ **Temperature** - System thermal monitoring
- ✅ **Network** - Connection status
- ✅ **Audio** - Volume and sink switching
- ✅ **Battery** - Power system status (on battery-equipped hosts)

### Rofi (MFD Menu Interface)
- Command entry styled as tactical data input
- Menu items with bordered selection boxes
- Mode switcher resembling function selectors
- Amber highlight for selected items
- Green indicators for active applications

### Kitty Terminal (CRT Display)
- Phosphor green or amber color scheme (configurable)
- Background opacity for subtle glow effect
- Tab bar styled as multi-display selector
- Blinking block cursor emulating CRT cursor
- Color palette optimized for phosphor aesthetic

### Dunst (Warning Lights)
Notifications categorized by urgency:

- **Low (Blue)** - Informational advisories
- **Normal (Amber)** - Caution/advisory warnings
- **Critical (Red)** - Master warning (no timeout, requires acknowledgment)

Custom notification types:
- Volume/brightness controls
- Battery warnings
- Network status
- System updates

## Architecture

### Functional vs Theme Separation
✅ **Properly Implemented** - Following NixOS configuration best practices:

- **Functional modules** (`*/functional.nix`) - Always active, provide core functionality:
  - Hyprland keybindings (Super+Space, Super+Return, etc.)
  - Essential settings and variables
  - Monitor configurations
  - Package dependencies

- **Theme modules** (`themes/century-series/*.nix`) - Visual styling only:
  - Colors, borders, styling
  - Override functional defaults with `mkForce`
  - Pure aesthetic configuration
  - No functional dependencies

### Current Configuration
The theme uses these settings:

- ✅ **Colors**: Centralized in `colors.nix` for consistency
- ✅ **Border Style**: 3px MFD-style bezels with amber accents  
- ✅ **Architecture**: Clean functional/theme separation
- ✅ **Compatibility**: Works with latest Hyprland and NixOS

## Installation

1. Enable the theme in your host configuration (e.g., `hosts/your-host/default.nix`):

```nix
{
  customConfig = {
    # ... other configuration ...

    desktop = {
      environments = [ "hyprland" ];  # Make sure Hyprland is enabled
    };

    homeManager = {
      themes = {
        hyprland = "century-series";  # Enable Century Series theme
      };
    };
  };
}
```

2. Rebuild your system:
```bash
rebuild
```

3. Restart Hyprland or log out and back in

**Note**: The theme is automatically imported via `modules/home-manager/themes/default.nix`. No manual imports needed!

## Known Working State

✅ **Latest Test**: December 11, 2024
- All Hyprland deprecation errors resolved
- Waybar CSS fully restored and functional  
- Proper functional/theme architecture implemented
- System rebuilds without errors
- All keybindings operational
- MFD borders and styling active

## Testing Notifications

A test script is included to preview the notification theme:

```bash
~/.local/bin/century-notify-test
```

This will display example notifications at each urgency level.

## Customization

### Using Different Phosphor Colors
Edit `theme.nix` and modify the accent color definitions:

```nix
accent-amber = "#ff9e3b";    # Change to your preferred amber
accent-green = "#7fda89";    # Change to your preferred green
```

### Adjusting Border Width
In `hyprland.nix`, modify the `mfdBorderSize`:

```nix
mfdBorderSize = if centuryConfig.borderStyle or "mfd" == "mfd" then 3 else 2;
```

### Custom Waybar Workspace Labels
Edit `waybar.nix` format-icons to change workspace names:

```nix
format-icons = {
  "1" = "YOUR_LABEL";
  "2" = "YOUR_LABEL";
  # ...
};
```

## Design References

This theme draws inspiration from:

- **F-104 Starfighter** - Angular design, minimal aesthetic
- **F-105 Thunderchief** - Comprehensive instrument panel layout
- **F-106 Delta Dart** - Early radar displays
- **MiG-21 Fishbed** - Soviet analog instrument design
- **Early AN/APG radar systems** - Amber CRT displays
- **1960s attitude indicators** - Green phosphor displays
- **Master caution panel design** - Warning light layout

## Font Recommendations

The theme uses **JetBrains Mono** and **Fira Code** by default, which provide:
- Clean, readable monospace characters
- Excellent terminal rendering
- Military/technical aesthetic
- Good Unicode coverage

Alternative fonts that work well:
- **IBM Plex Mono** - Corporate/technical feel
- **Source Code Pro** - Clean and professional
- **Inconsolata** - Compact and precise

## Screenshots

*(Screenshots would go here showing the various components)*

## Troubleshooting

### Common Issues

**Waybar not appearing**:
- Ensure functional waybar is enabled: check `modules/home-manager/de-wm-components/waybar/functional.nix`
- Restart waybar: `pkill waybar && waybar &`
- Check for CSS syntax errors in the generated config

**Keybindings not working**:
- Verify Hyprland functional module is active
- Check that theme doesn't override essential bindings
- Reload Hyprland: `hyprctl reload`

**Build errors**:  
- Remove deprecated Hyprland properties if present
- Ensure proper functional vs theme separation
- Check NixOS syntax in theme files

## Recent Fixes (December 2024)

✅ **Architectural Issues**:
- Fixed functional vs theme paradigm violations
- Removed `_module.args` from theme.nix (not supported)
- Centralized colors in dedicated colors.nix

✅ **Hyprland Compatibility**:
- Removed deprecated shadow properties
- Removed deprecated master layout settings
- Updated to work with latest Hyprland

✅ **Waybar Restoration**:
- Fixed JSON syntax conflicts
- Incrementally restored all CSS styling
- Added proper tray and tooltip styling

## Future Enhancements

Potential additions to the theme:

- [ ] Hyprpaper configuration with cockpit-themed wallpapers
- [ ] Custom Waybar modules (altimeter, heading indicator, etc.)
- [ ] Rofi power menu styled as systems panel
- [ ] Swaylock screen styled as startup/shutdown sequence
- [ ] GTK theme matching the cockpit aesthetic
- [ ] Custom icon set with aviation symbols
- [ ] Hyprlock configuration with instrument startup animation

## Credits

Created for NixOS with Hyprland, inspired by the legendary aircraft of the Cold War era.

**"Speed is Life"** - Fighter pilot motto

## License

This theme configuration is part of a personal NixOS configuration. Feel free to adapt and modify for your own use.
