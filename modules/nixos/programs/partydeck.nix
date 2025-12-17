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
    version = "0.5.2";

    src = pkgs.fetchFromGitHub {
      owner = "wunnr";
      repo = "partydeck-rs";
      rev = "v${version}";
      hash = "sha256-3v/JGh6aX/zd5gMxKe4Cwlmwn9jREo1MklyIZaqS7ZI=";
    };

    cargoHash = "sha256-3hO5ZtTX3uNqQBnSpm0rK3YsmgCRM7jcwPDb3J0aKVQ=";

    # Patch to skip UMU launcher download which causes infinite loop on NixOS
    postPatch = ''
      # Patch the check_dependencies function to skip UMU entirely
      if [ -f src/app/app.rs ]; then
        # Comment out the entire UMU check block
        sed -i '/if !PATH_RES.join("umu-run").exists()/,/^        }$/c\
        // UMU launcher check disabled for NixOS - not needed\
        // Original code checked for umu-run and downloaded if missing' src/app/app.rs
      fi
    '';

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
      # SDL2 support
      pkgs.SDL2
      # Font rendering
      pkgs.fontconfig
      pkgs.freetype
    ];

    desktopItems = [
      (pkgs.makeDesktopItem {
        name = "partydeck-rs";
        desktopName = "PartyDeck";
        comment = "A split-screen game launcher for Linux";
        exec = "partydeck-rs";
        icon = "partydeck-rs";
        categories = [ "Game" "Utility" ];
        keywords = [ "games" "launcher" "split-screen" "couch" "multiplayer" ];
      })
    ];

    postInstall = ''
      mkdir -p $out/share/icons/hicolor/512x512/apps
      cp ${partydeck-icon} $out/share/icons/hicolor/512x512/apps/partydeck-rs.png

      wrapProgram $out/bin/partydeck-rs \
        --prefix PATH : ${lib.makeBinPath [ pkgs.gamescope pkgs.bubblewrap ]} \
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
        --set-default PARTYDECK_DATA_DIR "$HOME/.local/share/partydeck" \
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