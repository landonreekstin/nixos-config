# ~/nixos-config/hosts/gaming-pc/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    apps = {
      defaultSet = "kde";
      defaults.kde.browser = "librewolf.desktop";

      # Spotify tracks unstable here; the desktop entry with the Ozone/Wayland
      # flags is defined in the home-manager block in home.nix.
      programs.music.package = pkgs.unstable.spotify;
    };

    programs = {
      partydeck.enable = true;
      firefox = {
        enable = true;
        package = pkgs.firefox;

        extensions = with pkgs.nur.repos.rycee.firefox-addons; [
          ublock-origin
          darkreader
          facebook-container
        ];

        bookmarks = [
          { name = "YouTube"; url = "https://www.youtube.com"; }
          { name = "Netflix"; url = "https://www.netflix.com"; }
          { name = "GitHub";  url = "https://github.com"; }
        ];
      };
      flatpak.enable = true;

      claudeCode = {
        enable = true;
        # lando's hyprland-keys working clone lives alongside nixos-config on this host.
        extraChownPaths = [ "/home/lando/hyprland-keys" ];
      };
    };

    packages = {
      nixos = with pkgs; [
        kitty
        pavucontrol
        mullvad-vpn
        tmux
        mgba
        pupdate

        # rom archive handling for the analogue pocket workflow
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
        "pupdate"
      ];
      # vscode, librewolf, brave and signal-desktop now come from
      # customConfig.apps.programs (ide, browser, browserAlt, chatAlt).
      homeManager = with pkgs; [
        jamesdsp
        remmina
        md-tui
        ungoogled-chromium
        vesktop
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
      flatpak = {
        enable = true;
        packages = [];
      };
    };

  };

  programs.zoom-us.enable = true;
}
