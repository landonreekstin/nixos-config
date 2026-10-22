// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Controls.js
// What every controller button does, for the Guide's Controls page: one
// section per place the pad behaves differently. Each bind is
// { btns: [...], label }: button names, joined by "+" (press together, a
// Guide chord) or "/" (either one).
//
// This is a description, not the mapping: the mappings themselves live in
// pad/xbox360-pad.py (the Guide chord, desktop emulation), session.nix
// padConfig (passthrough apps, the mpv profile) and each page's handle().
// Change one, change the matching section here.
.pragma library

var sections = [
    {
        label: "Guide Button", icon: "input-gaming",
        about: "Works everywhere, even in a game: no app ever sees the Guide button. Hold it and press another button.",
        binds: [
            { btns: ["guide"], label: "Tap: open the Guide" },
            { btns: ["guide"], label: "Hold: Turn Off Console" },
            { btns: ["guide", "+", "y"], label: "Xbox Dashboard" },
            { btns: ["guide", "+", "lb", "/", "rb"], label: "Previous / next app" },
            { btns: ["guide", "+", "dpad"], label: "Move between windows" },
            { btns: ["guide", "+", "x"], label: "On-screen keyboard" },
            { btns: ["guide", "+", "back"], label: "Close the app" },
            { btns: ["guide", "+", "start"], label: "Full screen" }
        ]
    },
    {
        label: "Dashboard", icon: "go-home",
        about: "The blades.",
        binds: [
            { btns: ["dpad"], label: "Up and down: move through the menu" },
            { btns: ["lb", "/", "rb"], label: "Previous / next blade (or left and right)" },
            { btns: ["lt", "/", "rt"], label: "Top / bottom of the menu" },
            { btns: ["a"], label: "Select" },
            { btns: ["y"], label: "Resume the last app" }
        ]
    },
    {
        label: "Guide", icon: "view-list-details",
        about: "This blade.",
        binds: [
            { btns: ["dpad"], label: "Move; left and right change a setting" },
            { btns: ["a"], label: "Select" },
            { btns: ["b"], label: "Back / close the Guide" },
            { btns: ["y"], label: "Xbox Dashboard" },
            { btns: ["x"], label: "Sign Out; in a list: Close App, Dismiss" }
        ]
    },
    {
        label: "Games and Videos", icon: "applications-games",
        about: "The Games Library and the Videos library.",
        binds: [
            { btns: ["dpad"], label: "Up and down: move through the list" },
            { btns: ["lb", "/", "rb"], label: "Previous / next tab (or left and right)" },
            { btns: ["lt", "/", "rt"], label: "Page up / page down" },
            { btns: ["a"], label: "Play / open" },
            { btns: ["b"], label: "Back" }
        ]
    },
    {
        label: "Apps", icon: "applications-internet",
        about: "Apps made for a mouse and keyboard: the browser, files, the terminal. The pad drives them like a mouse.",
        binds: [
            { btns: ["rs"], label: "Right stick: move the pointer" },
            { btns: ["rt"], label: "Left click" },
            { btns: ["lt"], label: "Right click" },
            { btns: ["rs"], label: "Press the right stick: middle click" },
            { btns: ["ls"], label: "Left stick: scroll" },
            { btns: ["dpad"], label: "Arrow keys" },
            { btns: ["a"], label: "Enter" },
            { btns: ["b"], label: "Back in a browser, Escape elsewhere" },
            { btns: ["x"], label: "Backspace" },
            { btns: ["y"], label: "On-screen keyboard" },
            { btns: ["lb", "/", "rb"], label: "Previous / next tab" }
        ]
    },
    {
        label: "Playing a Video", icon: "video-x-generic",
        about: "A video playing from the Videos library.",
        binds: [
            { btns: ["a", "/", "start"], label: "Pause / play" },
            { btns: ["b"], label: "Stop" },
            { btns: ["dpad"], label: "Left and right: skip 5 seconds" },
            { btns: ["dpad"], label: "Up and down: skip 1 minute" },
            { btns: ["lb", "/", "rb"], label: "Previous / next chapter" },
            { btns: ["lt", "/", "rt"], label: "Volume down / up" },
            { btns: ["x"], label: "Next subtitles" },
            { btns: ["y"], label: "Show the time" }
        ]
    },
    {
        label: "Keyboard", icon: "input-keyboard",
        about: "The on-screen keyboard.",
        binds: [
            { btns: ["dpad"], label: "Move between keys" },
            { btns: ["a"], label: "Type the key" },
            { btns: ["x"], label: "Backspace" },
            { btns: ["y"], label: "Space" },
            { btns: ["lb", "/", "rb"], label: "Move the cursor left / right" },
            { btns: ["lt"], label: "Symbols" },
            { btns: ["ls"], label: "Press the left stick: Caps" },
            { btns: ["b", "/", "start"], label: "Done" }
        ]
    },
    {
        label: "Games", icon: "steam",
        about: "Games, Steam, Heroic, Jellyfin, the emulators and anything full screen read the controller themselves: every button is theirs except the Guide button.",
        binds: [
            { btns: ["guide"], label: "Still opens the Guide" }
        ]
    }
];
