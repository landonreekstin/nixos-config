# ~/nixos-config/modules/nixos/profiles/partydeck.nix
{ lib, config, pkgs, ... }:

let
  partydeckCondition = config.customConfig.programs.partydeck.enable
                   && config.customConfig.profiles.gaming.enable
                   && lib.elem "kde" config.customConfig.desktop.environments;

  # Create a default config.toml file in the Nix store.
  default-config = pkgs.writeText "partydeck-default-config.toml" ''
    # The amount of players to show on the screen
    # Allowed values: 1, 2, 3, 4
    players = 4

    # The list of applications to show in the launcher
    # For each application, you can specify the following:
    # - name: The name of the application
    # - command: The command to execute (required)
    # - icon: The path to the icon to show (optional)
    # - background: The path to the background to show (optional)
    [[apps]]
    name = "Steam"
    command = "steam"
    # You can also use flatpak apps
    # command = "flatpak run com.valvesoftware.Steam"
    icon = "./res/default_icon.png"
    background = "./res/default_background.png"
  '';
  
  partydeck-pkg = pkgs.stdenv.mkDerivation {
    pname = "partydeck-rs";
    version = "0.5.2";

    src = pkgs.fetchurl {
      url = "https://github.com/wunnr/partydeck-rs/releases/download/v0.5.2/PartyDeck-0.5.2.tar.gz";
      hash = "sha256-HQ4rEOPgfFdRLz+uARpaX4f6tFzDmFndX1Soy1CzObA=";
    };

    nativeBuildInputs = [ 
      pkgs.autoPatchelfHook
    ];

    buildInputs = with pkgs; [
      # For partydeck-rs
      libarchive
      libgcc
      openssl

      # For the vendored gamescope and bubblewrap
      libavif
      libcap
      libdrm
      libei            # Corrected: was libeis
      libglvnd
      libinput
      seatd
      libxkbcommon
      luajit
      pixman
      SDL2
      vulkan-loader
      wayland
      xorg.libX11
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXmu
      xorg.libXrender
      xorg.libXres
      xorg.libXtst
      xorg.libXxf86vm
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp ../partydeck-rs $out/bin/partydeck
      cp -r ../res $out/bin/
      # Install the default config.toml right next to the executable.
      cp ${default-config} $out/bin/config.toml
      runHook postInstall
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
    environment.systemPackages = [
      partydeck-pkg
    ];
  };
}