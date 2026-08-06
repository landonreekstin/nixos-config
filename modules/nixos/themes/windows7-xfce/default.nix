# ~/nixos-config/modules/nixos/themes/windows7-xfce/default.nix
{ config, pkgs, lib, ... }:

# System-side wiring for the XFCE windows7 theme: exposes the vendored theme/asset
# derivations on pkgs (via a gated overlay) and installs the Segoe UI font stack.
# Mirrors themes/aerothemeplasma/plasma-system.nix but carries NO Plasma/Qt/xserver
# config, so it can't drag KDE onto an XFCE-only host.
let
  win7XfceCondition = lib.elem "xfce" config.customConfig.desktop.environments
    && config.customConfig.homeManager.themes.xfce == "windows7";

  # Real Segoe UI TTFs (the family the theme actually declares — xfconf Gtk/FontName and the
  # xscreensaver dialog fonts below). vista-fonts does NOT ship Segoe UI, so without this the
  # whole Win7 look silently falls back to Noto Sans. Vendored from a pinned commit; the
  # regular file's internal family name is literally "Segoe UI", so fc-match resolves it exactly
  # (no fontconfig alias needed). Proprietary MS font — same posture as corefonts/vista-fonts.
  segoe-ui = pkgs.stdenvNoCC.mkDerivation {
    pname = "segoe-ui";
    version = "2024-05-16";
    src = pkgs.fetchFromGitHub {
      owner = "mrbvrz";
      repo = "segoe-ui-linux";
      rev = "a89213b7136da6dd5c3638db1f2c6e814c40fa84";
      hash = "sha256-0KXfNu/J1/OUnj0jeQDnYgTdeAIHcV+M+vCPie6AZcU=";
    };
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      install -Dm644 font/*.ttf -t $out/share/fonts/truetype/segoe-ui
      runHook postInstall
    '';
    meta.license = lib.licenses.unfree;
  };
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

    # Install the Segoe UI font stack so XFCE's xsettings Gtk/FontName = "Segoe UI 9"
    # resolves. segoe-ui (vendored above) provides the actual Segoe UI family — vista-fonts
    # ships only Calibri/Cambria/Consolas/etc., NOT Segoe UI, so without segoe-ui the whole
    # Win7 look silently falls back to Noto Sans. corefonts/vista-fonts stay for the other
    # ClearType families the theme references. Deliberately does NOT set fonts.defaultFonts —
    # that would change the system-wide default sans for ALL desktops (KDE/Hyprland) whenever
    # this theme is enabled. The font is selected per-session via xsettings instead, keeping
    # XFCE enablement non-disruptive on multi-DE hosts.
    fonts.packages = with pkgs; [ corefonts vista-fonts segoe-ui ];
  };
}
