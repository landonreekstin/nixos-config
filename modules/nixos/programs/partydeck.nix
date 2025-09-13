# ~/nixos-config/modules/nixos/profiles/partydeck.nix
{ lib, config, pkgs, ... }:

let
  partydeckCondition = config.customConfig.programs.partydeck.enable
                   && config.customConfig.profiles.gaming.enable
                   && lib.elem "kde" config.customConfig.desktop.environments;

  partydeck-pkg = pkgs.stdenv.mkDerivation {
    pname = "partydeck-rs";
    version = "0.5.2";

    src = pkgs.fetchurl {
      url = "https://github.com/wunnr/partydeck-rs/releases/download/v0.5.2/PartyDeck-0.5.2.tar.gz";
      # Correct hash provided by you
      hash = "sha256-HQ4rEOPgfFdRLz+uARpaX4f6tFzDmFndX1Soy1CzObA=";
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      
      # The build process cds into 'res', but the binary is in the parent dir.
      # So we must reference it as ../partydeck-rs
      cp ../partydeck-rs $out/bin/partydeck-rs

      wrapProgram $out/bin/partydeck-rs \
        --prefix PATH : ${lib.makeBinPath [ pkgs.gamescope pkgs.bubblewrap ]}

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
    # We only need to install our final package. The wrapper will provide
    # gamescope and bubblewrap, so they don't need to be in systemPackages.
    environment.systemPackages = [
      pkgs.gamescope
      pkgs.bubblewrap
      partydeck-pkg
    ];
  };
}