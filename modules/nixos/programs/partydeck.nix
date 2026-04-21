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
        --prefix PATH : ${lib.makeBinPath [ pkgs.gamescope pkgs.bubblewrap pkgs.umu-launcher pkgs.fuse-overlayfs ]} \
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
      partydeck-pkg
    ];
  };
}