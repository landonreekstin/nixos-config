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
  
    partydeck-pkg = 
      let
      pversion = "0.5.2"; # Define version here
    in
    pkgs.rustPlatform.buildRustPackage {
    pname = "partydeck-rs";
    version = pversion;

    src = pkgs.fetchFromGitHub {
      owner = "wunnr";
      repo = "partydeck"; # Note: The repo is named 'partydeck', not 'partydeck-rs'
      rev = "v${pversion}";
      hash = "sha256-3v/JGh6aX/zd5gMxKe4Cwlmwn9jREo1MklyIZaqS7ZI=";
    };

    cargoHash = "sha256-3hO5ZtTX3uNqQBnSpm0rK3YsmgCRM7jcwPDb3J0aKVQ=";

    # These are needed by dependencies of partydeck
    nativeBuildInputs = [
      pkgs.pkg-config
    ];

    # These are the libraries partydeck links against
    buildInputs = [
      pkgs.openssl
      pkgs.libarchive
      pkgs.wayland
      pkgs.libxkbcommon
      pkgs.xorg.libX11
      pkgs.xorg.libXcursor
      pkgs.xorg.libXrandr
      pkgs.xorg.libXi
      pkgs.vulkan-loader
    ];

    # This is the crucial part. We patch the source code before building.
    postPatch = ''
      substituteInPlace src/main.rs \
        --replace 'current_exe.join("gamescope")' 'PathBuf::from("${pkgs.gamescope}/bin/gamescope")'
    '';

    postInstall = ''
      # Copy the resources and default config to the output directory
      cp -r ${pkgs.writeText "config.toml" (builtins.readFile ./partydeck-default-config.toml)} $out/bin/config.toml
      cp -r $src/res $out/bin/
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
  # We now also need to ensure gamescope and bubblewrap are in the system path
  # for the patched executable to find and run.
  config = lib.mkIf partydeckCondition {
    environment.systemPackages = [
      partydeck-pkg
      pkgs.gamescope
      pkgs.bubblewrap
    ];
  };
}