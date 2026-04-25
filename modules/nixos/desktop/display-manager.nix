# ~/nixos-config/modules/nixos/desktop/display-manager.nix
# Handles selection and configuration of the display manager (SDDM or Cosmic Greeter)
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.desktop.displayManager;
  des = config.customConfig.desktop.environments;
  firstDE = if des != [] then lib.head des else "none";
  monitors = config.customConfig.hardware.monitors;

  # Minimal seed file for fresh installs (no existing KWin config yet).
  # KWin will enrich this on first boot; subsequent rebuilds will use the patch path.
  sddmKwinConfigSeed = pkgs.writeText "kwinoutputconfig.json" (
    builtins.toJSON [
      {
        name = "outputs";
        data = map (m: {
          connectorName = m.name;
          transform = m.rotation;
          scale = m.scale;
        }) monitors;
      }
    ]
  );

in
{
config = lib.mkIf cfg.enable {
    
    # == Cosmic Greeter Configuration ==
    services.displayManager.cosmic-greeter = lib.mkIf (cfg.type == "cosmic") {
      enable = true;
    };

    # == SDDM Configuration ==
    services.displayManager.sddm = lib.mkIf (cfg.type == "sddm") {
      enable = true;
      wayland.enable = true;
      settings.Theme = {
        CursorTheme = "Adwaita";
        CursorSize = 24;
      };
    };

    # Write KWin cursor config for the sddm user so the cursor is visible on Wayland.
    # KWin ignores sddm.conf's CursorTheme and reads kcminputrc instead.
    system.activationScripts.sddm-cursor-config = lib.mkIf (cfg.type == "sddm") {
      deps = [ "users" "groups" ];
      text = ''
        mkdir -p /var/lib/sddm/.config
        cat > /var/lib/sddm/.config/kcminputrc << 'EOF'
[Mouse]
cursorTheme=Adwaita
cursorSize=24
EOF
        chown sddm:sddm /var/lib/sddm/.config/kcminputrc
        chmod 644 /var/lib/sddm/.config/kcminputrc
      '';
    };

    # Patch KWin output config for SDDM so monitor rotation/scale applies at the login screen.
    #
    # Root cause of the previous approach failing: KWin ignores per-output transforms
    # unless it also finds a matching "setups" entry (which encodes the full connected-
    # output fingerprint). Replacing the file with a minimal seed destroys the setups
    # section, so KWin falls back to defaults (all "Normal") and overwrites the file.
    #
    # Fix: if the file already exists (KWin has written it), use jq to patch only the
    # transform/scale fields while preserving uuid, edidIdentifier, setups, and all
    # other KWin-managed data. On fresh installs where no file exists yet, write the
    # minimal seed; after the first SDDM boot KWin will populate the file and the next
    # rebuild switches to the patch path.
    system.activationScripts.sddm-kwin-monitor-config = lib.mkIf (cfg.type == "sddm" && monitors != []) {
      deps = [ "users" "groups" ];
      text = let
        # Build a jq filter that updates transform/scale for each configured monitor.
        firstMon = lib.head monitors;
        restMons = lib.tail monitors;
        firstCase = ''if .connectorName == "${firstMon.name}" then .transform = "${firstMon.rotation}" | .scale = ${toString firstMon.scale}'';
        restCases = lib.concatMapStringsSep " " (m:
          ''elif .connectorName == "${m.name}" then .transform = "${m.rotation}" | .scale = ${toString m.scale}''
        ) restMons;
        jqFilter = "map(if .name == \"outputs\" then .data |= map(${firstCase} ${restCases} else . end) else . end)";
      in ''
        mkdir -p /var/lib/sddm/.config
        _file=/var/lib/sddm/.config/kwinoutputconfig.json
        if [ -f "$_file" ] && ${pkgs.jq}/bin/jq empty "$_file" 2>/dev/null; then
          # Patch existing file in-place, preserving uuid/edid/setups so KWin can match it.
          _tmp=$(mktemp)
          ${pkgs.jq}/bin/jq '${jqFilter}' "$_file" > "$_tmp" && mv "$_tmp" "$_file" || rm -f "$_tmp"
        else
          # No existing file yet — place a minimal seed.  KWin will enrich it on first
          # boot, and the next rebuild will switch to the patch path above.
          rm -f "$_file"
          cp ${sddmKwinConfigSeed} "$_file"
        fi
        chown sddm:sddm "$_file"
        chmod 644 "$_file"
      '';
    };

    # == Ly Greeter Configuration ==
    services.displayManager.ly = lib.mkIf (cfg.type == "ly") {
      enable = true;
      settings = {
        x_cmd = "/bin/false"; # Ensures it doesn't try to run X11
      };
    };

    # Unlock gnome-keyring on ly login so NetworkManager's secret agent has a
    # keyring to store/retrieve WiFi passwords — works for both KDE and Hyprland.
    services.gnome.gnome-keyring.enable = lib.mkIf (cfg.type == "ly") true;
    security.pam.services.ly.enableGnomeKeyring = lib.mkIf (cfg.type == "ly") true;

    # == Greetd + ReGreet Configuration ==
    services.greetd = lib.mkIf (cfg.type == "greetd") {
      enable = true;
      settings = {
        default_session = {
          command = ''
            ${pkgs.hyprland}/bin/Hyprland -c /etc/greetd/hyprland-greeter.conf
          '';
          user = "greeter";
        };
      };
    };

    # == Auto-Login / Direct Session Start Configuration ==
    # Autologin the configured user when no display manager is selected.
    services.getty.autologinUser = lib.mkIf (cfg.type == "none" && config.customConfig.desktop.enable) config.customConfig.user.name;

    # XDG portal for the first DE when no display manager is used
    xdg.portal = lib.mkIf (cfg.type == "none" && firstDE != "none") {
      enable = true;
      extraPortals =
        lib.optionals (firstDE == "hyprland") [ pkgs.xdg-desktop-portal-hyprland ]
        ++ lib.optionals (firstDE == "cosmic") [ pkgs.xdg-desktop-portal-cosmic ];
    };


    # ==> Create /etc/regreet.toml directly using environment.etc <==
    environment.etc."greetd/regreet.toml" = lib.mkIf (cfg.type == "greetd") {
      # Target path: /etc/greetd/regreet.toml
      text = ''
        # regreet configuration generated directly

        [background]
        path = "/etc/greetd/concorde-vertical-art.jpg"
        fit = "cover"

        # Add any other regreet settings directly here in TOML format
        # [theme]
        # name = "Adwaita-Dark" # Example

        # [icons]
        # name = "breeze" # Example
      '';
      mode = "0444"; # Read-only
    };

    # == Deploy Greeter Wallpaper File ==
    environment.etc."greetd/concorde-vertical-art.jpg" = lib.mkIf (cfg.type == "greetd") {
      # Target path: /etc/greetd/concorde-vertical-art.jpg
      source = ../../../assets/wallpapers/concorde-vertical-art.jpg; # Path relative to this Nix file
      mode = "0444"; # Read-only is appropriate
    };

    # == Greeter Hyprland Config File (managed by environment.etc) ==
    # Define the minimal config file for Hyprland when run by greetd
    environment.etc."greetd/hyprland-greeter.conf" = lib.mkIf (cfg.type == "greetd") {
      text = ''
        # Minimal Hyprland config for greetd + regreet

        # Monitors (ensure rotation applies correctly for the greeter)
        monitor=HDMI-A-3,1920x1080,0x0,1,transform,1
        monitor=HDMI-A-1,preferred,1080x0,1
        monitor=HDMI-A-4,1920x1080,0x0,1,transform,1
        monitor=HDMI-A-2,preferred,1080x0,1

        # Basic Environment Variables
        env = XCURSOR_SIZE,24
        env = QT_QPA_PLATFORMTHEME,qt6ct # Or qt5ct depending on regreet build

        # Basic Input
        input { kb_layout = us; follow_mouse = 1; }

        # Basic Appearance (regreet handles most visuals)
        general { border_size = 1; layout = dwindle; }
        decoration { rounding = 0; drop_shadow = no; blur { enabled = false; } }
        animations { enabled = false; }

        # Execute ReGreet
        exec-once = ${pkgs.greetd.regreet}/bin/regreet

        # Minimal misc settings
        misc { disable_hyprland_logo = true; force_default_wallpaper = -1; } # No wallpaper needed here
      ''; # End text block
    }; # End environment.etc definition

    # == Packages needed based on DM selection (Using lib.optionals) ==
    environment.systemPackages =
      # Use lib.optionals which returns a list or []
      (lib.optionals (cfg.type == "sddm") [
        pkgs.sddm-sugar-dark
        pkgs.adwaita-icon-theme
      ])
      ++ # Concatenate the lists
      (lib.optionals (cfg.type == "greetd") [
        pkgs.greetd.greetd
        pkgs.greetd.regreet
        pkgs.hyprland
        pkgs.qt6.qtwayland
        pkgs.libjpeg pkgs.gdk-pixbuf pkgs.librsvg pkgs.qt6.qtimageformats
      ])
      ++
      (lib.optionals (cfg.type == "none" && firstDE == "hyprland") [ pkgs.xdg-desktop-portal-hyprland ])
      ++ (lib.optionals (cfg.type == "none" && firstDE == "cosmic") [ pkgs.xdg-desktop-portal-cosmic ]);

    # == Assertions ==
    # Ensure that configuration choices don't conflict
    assertions = [
      # Assertion 1: Only allow one display manager to be enabled simultaneously
      {
        assertion = builtins.length (lib.filter (x: x == true) [
          config.services.displayManager.cosmic-greeter.enable or false # Use 'or false' in case module isn't evaluated
          config.services.displayManager.sddm.enable or false
          config.services.displayManager.ly.enable or false
          config.services.greetd.enable or false
        ]) <= 1;
        message = "Configuration Error: Only one display manager (SDDM, Greetd, or Cosmic Greeter) can be enabled at a time. Check profiles.desktop.displayManager setting.";
      }
      # Assertion 2: Warn if a desktop profile is enabled but no display manager is selected (optional, can be noisy)
      # {
      #   assertion = !(
      #        (config.profiles.desktop.cosmic.enable || config.profiles.desktop.hyprland.enable) # Check relevant profiles
      #     && (config.profiles.desktop.displayManager == "none")
      #   );
      #   message = "Configuration Warning: A desktop profile (COSMIC or Hyprland) is enabled, but profiles.desktop.displayManager is set to 'none'. Graphical login might not work as expected.";
      # }
    ]; # End assertionssessionComman
  };
}