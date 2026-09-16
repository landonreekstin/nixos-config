# ~/nixos-config/hosts/gaming-pc/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    apps = {
      defaultSet = "kde";
      defaults.kde.browser = "firefox.desktop";

      # Firefox is the primary browser (Super+B) as of the 2026-09-15 checklist
      # pass in docs/browsers.md: chrome theme, Widevine/Prime playback, .lan,
      # saved logins surviving a restart, search keywords and the sops-backed
      # bookmarks were all verified on this machine.
      #
      # It is configured by customConfig.homeManager.browser.firefox in home.nix,
      # which builds its own wrapped package — so the collision guard in
      # modules/home-manager/system/apps.nix drops this package from
      # home.packages and the role's command resolves `firefox` from PATH. See
      # docs/browsers.md "ownsAppRole".
      programs.browser = {
        package = pkgs.firefox;
        exe = "firefox";
      };

      # Spotify tracks unstable here; the desktop entry with the Ozone/Wayland
      # flags is defined in the home-manager block in home.nix.
      programs.music.package = pkgs.unstable.spotify;

      # Discord comes from Flatpak, not nixpkgs: it self-updates, so it never
      # hits the "update required" wall that blocks the native package whenever
      # upstream ships a client bump ahead of nixpkgs. package = null keeps
      # pkgs.discord out of the closure while the command still drives Super+C,
      # the COMM launcher button (desktop.nix), the XFCE panel pin and the XFCE
      # autostart (home.nix) — this line is the single switch for all of them.
      programs.chat = {
        package = null;
        command = "flatpak run com.discordapp.Discord";
      };

      # Alternative browser (Super+Alt+B) is Chromium here rather than the
      # default Brave. ungoogled-chromium's binary is named `chromium`, so `exe`
      # must be set alongside the package. It used to be installed via
      # packages.homeManager; the role owns the install now, so it is not listed
      # in both places.
      programs.browserAlt = {
        package = pkgs.ungoogled-chromium;
        exe = "chromium";
      };

      # Alternative gaming platform (Super+Alt+G) is Heroic rather than Lutris.
      # Both come from customConfig.profiles.gaming, so this role carries no
      # package and resolves `heroic` from PATH.
      programs.gamingAlt.command = "heroic";
    };

    programs = {
      partydeck.enable = true;

      claudeCode = {
        enable = true;
        # lando's hyprland-keys working clone lives alongside nixos-config on this host.
        extraChownPaths = [ "/home/lando/hyprland-keys" ];
        remoteControl = {
          atStartup = true;
          server = {
            enable = true;
            directories = [
              # nixos-config stays root: `rebuild` needs it, and the settings.json
              # hooks already chown its files back to lando.
              "/home/lando/nixos-config"
              # analogue-pocket needs no root, so serve it as its owner — files stay
              # lando-owned and no chown hook is involved.
              { path = "/home/lando/emulation/analogue-pocket"; user = "lando"; }
            ];
          };
        };
      };
    };

    packages = {
      nixos = with pkgs; [
        kitty
        pavucontrol
        mullvad-vpn
        tmux
        mgba

        # pupdate and flashgbx now live in the `emulation` devShell, not here:
        #   nix develop ~/nixos-config#emulation   (or just cd ~/emulation, via direnv)
        # See modules/nixos/development/emulation.nix. flashgbx still needs no udev
        # rule — the CH340 lands in group dialout, which lando is already in.

        # rom archive handling; general-purpose enough to stay global
        zip
        unzip
        p7zip

        # smbclient and kio-extras for Dolphin network shares
        kdePackages.kio-extras
        cifs-utils
        samba

        # Webcam (Logitech C920e on /dev/video0). guvcview is the GUI app — resolution/format
        # picker plus exposure/focus/white-balance sliders; v4l-utils provides v4l2-ctl for
        # enumerating what the camera actually supports (`v4l2-ctl --list-formats-ext`).
        guvcview
        v4l-utils

        # Quick low-latency webcam preview. Usage: webcam [WxH] [fps]  (default 1280x720 30)
        #
        # Tuned for the XFCE-over-xrdp session (see CLAUDE.md "Remote XFCE via RDP"):
        #   --vo=x11    xorgxrdp has NO hardware GL, so mpv's default vo=gpu would silently
        #               fall back to llvmpipe software GL. Force the software X11 path instead
        #               so the render pipeline is predictable rather than accidental.
        #   input_format=mjpeg
        #               The C920e only reaches 720p/1080p at 30fps in MJPEG; the driver default
        #               is raw YUYV, which caps out low and pushes a far larger USB stream.
        #   --untimed --profile=low-latency
        #               Live source — don't buffer for A/V sync.
        #   --no-audio  There is no audio over xrdp on this host (needs pulseaudio-module-xrdp,
        #               not wired up), so the webcam mic is never audible. Don't stall on it.
        # mpv is referenced by absolute store path: it comes from the per-user profile, which a
        # systemPackages script must not depend on being present.
        (writeShellScriptBin "webcam" ''
          set -euo pipefail
          RES="''${1:-1280x720}"
          FPS="''${2:-30}"
          DEV="''${WEBCAM_DEV:-/dev/video0}"

          if [ ! -e "$DEV" ]; then
            echo "webcam: no capture device at $DEV" >&2
            echo "Plugged in? Check: ls /dev/video*  and  v4l2-ctl --list-devices" >&2
            exit 1
          fi
          if [ ! -r "$DEV" ]; then
            echo "webcam: $DEV exists but is not readable by $(id -un)" >&2
            echo "The 'video' group grants access — check: id -nG" >&2
            exit 1
          fi

          # A v4l2 capture device is exclusive; a browser tab or the other desktop session
          # holding it makes mpv fail with an opaque ioctl error. Name the real cause.
          if ${pkgs.psmisc}/bin/fuser "$DEV" >/dev/null 2>&1; then
            echo "webcam: $DEV is already in use by another program:" >&2
            ${pkgs.psmisc}/bin/fuser -v "$DEV" >&2 || true
            echo "Close it (browser tab, other desktop session) and retry." >&2
            exit 1
          fi

          exec ${pkgs.mpv}/bin/mpv \
            --title="Webcam" \
            --vo=x11 \
            --profile=low-latency \
            --untimed \
            --no-audio \
            --demuxer-lavf-o=input_format=mjpeg,video_size="$RES",framerate="$FPS" \
            "av://v4l2:$DEV"
        '')

        # Build all host configs and push their store paths to the NAS binary cache.
        # Run after a big nixpkgs update to warm the cache for all machines.
        # Usage: cache-push-all
        (writeShellScriptBin "cache-push-all" ''
          set -euo pipefail
          NAS="ssh://lando@192.168.1.76"
          FLAKE="/home/lando/nixos-config"
          HOSTS="gaming-pc optiplex blaney-pc justus-pc asus-laptop asus-m15 atl-mini-pc optiplex-nas"

          for host in $HOSTS; do
            echo "==> [$host] evaluating..."
            drv=$(NIXPKGS_ALLOW_UNFREE=1 nix eval --impure --raw \
              "$FLAKE#nixosConfigurations.$host.config.system.build.toplevel" 2>/dev/null) || {
              echo "    SKIP: eval failed for $host"
              continue
            }
            echo "==> [$host] building $drv"
            nix build "$drv" --no-link || {
              echo "    SKIP: build failed for $host"
              continue
            }
            echo "==> [$host] pushing to NAS cache..."
            nix copy --to "$NAS" "$drv"
            echo "==> [$host] done"
          done

          echo ""
          echo "cache-push-all complete."
        '')
      ];
      unstable-override = [
        "obs-studio"
        "vscode"
        "librewolf"
        "brave"
        "ungoogled-chromium"
        "claude-code"
        "gurk-rs"
        "vlc"
        "signal-desktop"
      ];
      # vscode, firefox, discord and signal-desktop now come from
      # customConfig.apps.programs (ide, browser, chat, chatAlt). browserAlt is
      # Chromium here, so brave is listed below to keep it installed.
      homeManager = with pkgs; [
        # Kept installed alongside Firefox, but no longer on the browser role and
        # deliberately NOT managed by customConfig.homeManager.browser — its
        # hand-configured ~/.librewolf profile is untouched and stays as a
        # fallback. Still needs the unstable-override above: stable 25.11 marks
        # librewolf insecure, so Hydra never builds it.
        librewolf

        jamesdsp
        remmina
        md-tui
        brave  # no longer installed by the browserAlt role (now Chromium)
        qbittorrent
        obs-studio
        kdePackages.konversation
        kdePackages.kdenlive
        claude-code
        (callPackage ../../pkgs/worldmonitor { })
        zoom-us
        gurk-rs
        vlc
        keepassxc
      ];
      # Declared here rather than installed by hand, so nix-flatpak owns it and a
      # fresh deploy reinstalls it. Discord is the only Flatpak on this host.
      flatpak = {
        enable = true;
        packages = [ "com.discordapp.Discord" ];
      };
    };

  };


  # Two bookmarks in the shared tree embed a credential in their URL. Home
  # Manager renders bookmarks.html into the Nix store, which is world-readable,
  # and this repo is public — so the tokens live only here and are substituted
  # into a copy under $HOME at activation. owner is required: the substitution
  # runs in the user's Home Manager activation, not as root.
  # Consumed by customConfig.homeManager.browser.firefox.personal.bookmarks.secrets.
  sops.secrets = {
    browser-dashboard-token = {
      sopsFile = ../../secrets/gaming-pc.yaml;
      owner = config.customConfig.user.name;
      mode = "0400";
    };
    browser-reader-hash = {
      sopsFile = ../../secrets/gaming-pc.yaml;
      owner = config.customConfig.user.name;
      mode = "0400";
    };
  };

  programs.zoom-us.enable = true;
}
