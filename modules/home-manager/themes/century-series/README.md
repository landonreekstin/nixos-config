# Century Series - Cold War Aviation Cockpit Theme

A comprehensive Hyprland theme inspired by Cold War-era fighter jet cockpits, specifically the Century Series fighters (F-100, F-101, F-102, F-104, F-105, F-106) and their Soviet counterparts (MiG-17, MiG-19, MiG-21).

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
- MFD-style window borders with 3px bezel frames
- Dual-tone gradient borders for active windows (amber/green glow)
- Hydraulic-inspired animations for window movements
- Dim inactive windows like unpowered displays
- Tinted blur effect simulating cockpit glass

### Waybar (Instrument Panel)
Waybar is configured as a full instrument panel with:

**Workspace Labels** - Tactical mode indicators:
- `NAV` - Navigation (workspace 1)
- `COM` - Communications (workspace 2)
- `SYS` - Systems (workspace 3)
- `WPN` - Weapons (workspace 4)
- `ECM` - ECM/Misc (workspace 5)

**System Monitors** - Styled as cockpit gauges:
- **PWR** - CPU usage (power output gauge)
- **MEM** - Memory usage (fuel quantity indicator)
- **TMP** - Temperature (EGT - Exhaust Gas Temperature)
- **LINK** - Network status (IFF transponder)
- **VOL** - Audio (intercom volume)
- **BAT** - Battery (electrical system)

**Warning States**:
- Normal: Green/Amber borders
- Warning (>70%): Yellow caution lights
- Critical (>90%): Blinking red master warning

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

## Configuration Options

### Current Configuration
The theme currently uses these default settings:

- **Accent Mode**: `mixed` - Context-aware colors (green for terminals, amber for highlights)
- **Border Style**: `mfd` - Full MFD bezel with 3px visible borders

### Accent Modes (Available)
- **amber** - Amber CRT displays throughout (radar altimeter style)
- **green** - Green phosphor displays (traditional radar/scope)
- **mixed** - Context-aware: green for terminals, amber for highlights

### Border Styles (Available)
- **mfd** - Full MFD bezel with 3px visible borders
- **clean** - Minimal 2px borders for cleaner look

**Note**: To customize accent mode or border style, edit `modules/home-manager/themes/century-series/theme.nix` lines 46-49. These options could be exposed via `customConfig` in a future update.

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
