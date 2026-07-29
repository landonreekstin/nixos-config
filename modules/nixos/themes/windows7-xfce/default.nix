# ~/nixos-config/modules/nixos/themes/windows7-xfce/default.nix
{ config, pkgs, lib, ... }:

# System-side wiring for the XFCE windows7 theme: exposes the vendored theme/asset
# derivations on pkgs (via a gated overlay) and installs the Segoe UI font stack.
# Mirrors themes/aerothemeplasma/plasma-system.nix but carries NO Plasma/Qt/xserver
# config, so it can't drag KDE onto an XFCE-only host.
let
  win7XfceCondition = lib.elem "xfce" config.customConfig.desktop.environments
    && config.customConfig.homeManager.themes.xfce == "windows7";
in {
  config = lib.mkIf win7XfceCondition {
    nixpkgs.overlays = [
      (final: prev: {
        windows7-xfce-gtk = prev.callPackage ./windows7-xfce-gtk.nix { };
        windows7-xfce-assets = prev.callPackage ./windows7-xfce-assets.nix { };
        windows7-xfce-sounds = prev.callPackage ./windows7-xfce-sounds.nix { };

        # Windows 7 "Aero" unlock-dialog palette. xscreensaver 6's raw-Xlib password dialog
        # reads its theme ONLY from the XScreenSaver app-defaults file (not ~/.xscreensaver or
        # xrdb), so the custom theme must be baked into the package. It uses the FIRST occurrence
        # of each resource and ignores anything after the file's trailing "xrdb prevention
        # kludge" comment — so we must rewrite the built-in "default" dialogTheme's values
        # IN PLACE (appending does nothing). Light Aero panel, aero-blue heading/labels, white
        # password field, subtle bevel, aero-blue thermometer. Font is "Segoe UI" to match the
        # rest of the theme's xsettings. This patched xscreensaver is used by both the HM
        # daemon/autostart (screensaver.nix) and the setuid xscreensaver-auth wrapper
        # (modules/nixos/desktop/xfce.nix), so the lock dialog they draw picks it up.
        xscreensaver = prev.xscreensaver.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            ad="$out/share/xscreensaver/app-defaults/XScreenSaver"
            sed -i -E \
              -e 's|^(\*Dialog\.headingFont:).*|\1 Segoe UI bold 18|' \
              -e 's|^(\*Dialog\.bodyFont:).*|\1 Segoe UI 13|' \
              -e 's|^(\*Dialog\.labelFont:).*|\1 Segoe UI 13|' \
              -e 's|^(\*Dialog\.unameFont:).*|\1 Segoe UI 12|' \
              -e 's|^(\*Dialog\.buttonFont:).*|\1 Segoe UI bold 13|' \
              -e 's|^(\*Dialog\.errorFont:).*|\1 Segoe UI bold 13|' \
              -e 's|^(\*default\.Dialog\.foreground:).*|\1 #12395e|' \
              -e 's|^(\*default\.Dialog\.background:).*|\1 #eaf1fb|' \
              -e 's|^(\*default\.Dialog\.topShadowColor:).*|\1 #ffffff|' \
              -e 's|^(\*default\.Dialog\.bottomShadowColor:).*|\1 #b4cbe6|' \
              -e 's|^(\*default\.Dialog\.borderColor:).*|\1 #6f9bc9|' \
              -e 's|^(\*default\.Dialog\.borderWidth:).*|\1 1|' \
              -e 's|^(\*default\.Dialog\.text\.foreground:).*|\1 #1a1a1a|' \
              -e 's|^(\*default\.Dialog\.text\.background:).*|\1 #ffffff|' \
              -e 's|^(\*default\.Dialog\.button\.foreground:).*|\1 #12395e|' \
              -e 's|^(\*default\.Dialog\.button\.background:).*|\1 #e2edfb|' \
              -e 's|^(\*default\.Dialog\.thermometer\.foreground:).*|\1 #2f8fdf|' \
              -e 's|^(\*default\.Dialog\.thermometer\.background:).*|\1 #cfe0f4|' \
              -e 's|^(\*default\.Dialog\.logo\.background:).*|\1 #eaf1fb|' \
              "$ad"
          '';
        });
      })
    ];

    # Install the Segoe UI font stack (from vista-fonts) so XFCE's xsettings Gtk/FontName
    # = "Segoe UI 9" resolves. Deliberately does NOT set fonts.defaultFonts — that would
    # change the system-wide default sans for ALL desktops (KDE/Hyprland) whenever this
    # theme is enabled. The font is selected per-session via xsettings instead, keeping
    # XFCE enablement non-disruptive on multi-DE hosts.
    fonts.packages = with pkgs; [ corefonts vista-fonts ];
  };
}
