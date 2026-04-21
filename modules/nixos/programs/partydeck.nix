# ~/nixos-config/modules/nixos/profiles/partydeck.nix
{ lib, config, pkgs, ... }:

let
  partydeckCondition = config.customConfig.programs.partydeck.enable
                   && config.customConfig.profiles.gaming.enable
                   && lib.elem "kde" config.customConfig.desktop.environments;

  partydeck-icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/wunnr/partydeck-rs/main/.github/assets/icon.png";
    hash = "sha256-pbhWe+R6TAxW0FPPZfqwJetG8YI+Znyb98VDZjOCsnI=";
  };

  gamescope-kbm-glm = pkgs.fetchFromGitHub {
    owner = "g-truc";
    repo = "glm";
    rev = "0af55ccecd98d4e5a8d1fad7de25ba429d60e863";
    hash = "sha256-GnGyzNRpzuguc3yYbEFtYLvG+KiCtRAktiN+NvbOICE=";
  };

  gamescope-kbm-stb = pkgs.fetchFromGitHub {
    owner = "nothings";
    repo = "stb";
    rev = "5736b15f7ea0ffb08dd38af21067c314d6a3aae9";
    hash = "sha256-s2ASdlT3bBNrqvwfhhN6skjbmyEnUgvNOrvhgUSRj98=";
  };

  gamescope-kbm-pkg = pkgs.stdenv.mkDerivation {
    pname = "gamescope-kbm";
    version = "3.x-kbm-unstable-2026-03-11";

    src = pkgs.fetchFromGitHub {
      owner = "partydeck";
      repo = "gamescope";
      rev = "074c4f6f6f07d473af995717cc647e43efef741c";
      fetchSubmodules = true;
      hash = "sha256-IHxM1j2HMf5hC2GjTq4fI3qs3ev/AFwP2CPcyF6203o=";
    };

    # No nixpkgs gamescope patches — they target v3.16+ and won't apply to this old fork.
    # Pre-populate meson subprojects that would otherwise require network downloads.
    postPatch = ''
      cp -r ${gamescope-kbm-glm} subprojects/glm
      chmod -R u+w subprojects/glm
      cp subprojects/packagefiles/glm/meson.build subprojects/glm/meson.build

      cp -r ${gamescope-kbm-stb} subprojects/stb
      chmod -R u+w subprojects/stb
      cp subprojects/packagefiles/stb/meson.build subprojects/stb/meson.build

      patchShebangs subprojects/libdisplay-info/tool/gen-search-table.py || true
      patchShebangs default_extras_install.sh || true
    '';

    nativeBuildInputs = [
      pkgs.meson
      pkgs.pkg-config
      pkgs.ninja
      pkgs.wayland-scanner
      pkgs.cmake
      pkgs.makeBinaryWrapper
      pkgs.glslang
      pkgs.python3
      pkgs.hwdata
      pkgs.v4l-utils
      (pkgs.writeShellScriptBin "git" "echo 3.x-kbm")
    ];

    buildInputs = [
      pkgs.pipewire
      pkgs.hwdata
      pkgs.xorg.libX11
      pkgs.xorg.libxcb
      pkgs.wayland
      pkgs.wayland-protocols
      pkgs.vulkan-loader
      pkgs.vulkan-headers
      pkgs.xorg.libXcomposite
      pkgs.xorg.libXcursor
      pkgs.xorg.libXdamage
      pkgs.xorg.libXext
      pkgs.xorg.libXi
      pkgs.xorg.libXmu
      pkgs.xorg.libXrender
      pkgs.xorg.libXres
      pkgs.xorg.libXtst
      pkgs.xorg.libXxf86vm
      pkgs.libavif
      pkgs.libdrm
      pkgs.libei
      pkgs.SDL2
      pkgs.libdecor
      pkgs.libinput
      pkgs.libxkbcommon
      pkgs.gbenchmark
      pkgs.pixman
      pkgs.libcap
      pkgs.lcms2
      pkgs.luajit
      pkgs.seatd
      pkgs.xwayland
      pkgs.xorg.xcbutilwm        # xcb-ewmh, xcb-icccm
      pkgs.xorg.xcbutilimage     # xcb-image
      pkgs.xorg.xcbutilkeysyms   # xcb-keysyms
      pkgs.xorg.xcbutilrenderutil # xcb-render-util
      pkgs.xorg.xcbutilcursor    # xcb-cursor
      pkgs.xorg.xcbutilerrors    # xcb-errors
    ];

    mesonFlags = [
      (lib.mesonBool "enable_gamescope" true)
      (lib.mesonBool "enable_gamescope_wsi_layer" true)
    ];

    mesonInstallFlags = [ "--skip-subprojects" ];
    strictDeps = true;

    depsBuildBuild = [ pkgs.pkg-config ];

    postInstall = ''
      # partydeck looks for 'gamescope-kbm' in PATH
      mv $out/bin/gamescope $out/bin/gamescope-kbm
    '';

    meta = with lib; {
      description = "gamescope fork with per-player KBM isolation for partydeck";
      homepage = "https://github.com/partydeck/gamescope";
      license = licenses.bsd2;
      platforms = platforms.linux;
    };
  };

  partydeck-pkg = pkgs.rustPlatform.buildRustPackage rec {
    pname = "partydeck-rs";
    version = "0.8.6";

    src = pkgs.fetchFromGitHub {
      owner = "wunnr";
      repo = "partydeck-rs";
      rev = "v${version}";
      hash = "sha256-BLgaQxmnLaKWo/RFOCpdjwfoYnyHXxoJy1ImJU/8ceI=";
    };

    cargoHash = "sha256-pPbMKyp3e3umhVwZ7Aj3T9RUPPTdZlGYgWUjUdy2YB8=";

    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.copyDesktopItems
      pkgs.pkg-config
    ];

    buildInputs = [
      pkgs.libarchive
      pkgs.openssl
      # Graphics libraries for eframe/egui
      pkgs.libGL
      pkgs.libxkbcommon
      pkgs.wayland
      # X11 libraries
      pkgs.xorg.libX11
      pkgs.xorg.libXcursor
      pkgs.xorg.libXrandr
      pkgs.xorg.libXi
      pkgs.xorg.libxcb
      # SDL2 support
      pkgs.SDL2
      # Font rendering
      pkgs.fontconfig
      pkgs.freetype
      # D-Bus (for zbus crate)
      pkgs.dbus
      # Input devices (for evdev crate)
      pkgs.libevdev
    ];

    desktopItems = [
      (pkgs.makeDesktopItem {
        name = "partydeck";
        desktopName = "PartyDeck";
        comment = "A split-screen game launcher for Linux";
        exec = "partydeck";
        icon = "partydeck";
        categories = [ "Game" "Utility" ];
        keywords = [ "games" "launcher" "split-screen" "couch" "multiplayer" ];
      })
    ];

    postInstall = ''
      mkdir -p $out/share/icons/hicolor/512x512/apps
      cp ${partydeck-icon} $out/share/icons/hicolor/512x512/apps/partydeck.png

      # Copy required runtime resources (KWin scripts, icons, etc.)
      cp -r $src/res $out/bin/res

      wrapProgram $out/bin/partydeck \
        --prefix PATH : ${lib.makeBinPath [ gamescope-kbm-pkg pkgs.bubblewrap pkgs.umu-launcher pkgs.fuse-overlayfs ]} \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
          pkgs.libxkbcommon
          pkgs.libGL
          pkgs.vulkan-loader
          pkgs.wayland
          pkgs.xorg.libX11
          pkgs.xorg.libXcursor
          pkgs.xorg.libXrandr
          pkgs.xorg.libXi
        ]} \
        --set-default PARTYDECK_SKIP_UMU_UPDATE "1"
    '';

    meta = with lib; {
      description = "A split-screen game launcher for Linux/SteamOS";
      homepage = "https://github.com/wunnr/partydeck-rs";
      license = licenses.gpl3Only;
      platforms = platforms.linux;
      maintainers = with maintainers; [ ];
    };
  };

in
{
  config = lib.mkIf partydeckCondition {
    # We only need to install our final package. The wrapper will provide
    # gamescope and bubblewrap, so they don't need to be in systemPackages.
    environment.systemPackages = [
      pkgs.gamescope
      pkgs.bubblewrap
      gamescope-kbm-pkg
      partydeck-pkg
    ];
  };
}