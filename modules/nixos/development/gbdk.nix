{ lib, pkgs, config, ... }:

let
  # Define the custom GBDK package here, making the module self-contained.
  gbdk = pkgs.stdenv.mkDerivation rec {
    pname = "gbdk-2020";
    version = "4.2.0";

    src = pkgs.fetchurl {
      url = "https://github.com/gbdk-2020/gbdk-2020/releases/download/4.2.0/gbdk-linux64.tar.gz";
      hash = "sha256-6WxOJ87H8IRpkh6s2o0RIg/hZYVT1xL7UUbJbl6CVwY=";
    };

    # GBDK is pre-compiled, so we just unpack it and install to $out.
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -R ./* $out/
      runHook postInstall
    '';

    meta = with lib; {
      description = "The Game Boy Development Kit";
      homepage = "https://gbdk-2020.github.io/gbdk-2020/";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };
in
{
  # This option will hold the devShell derivation for the flake to consume.
  options.customConfig.profiles.development.gbdk.devShell = with lib; mkOption {
    type = types.package; # A derivation is a type of package
    internal = true;      # This is set by the module, not the user.
    description = "The derivation for the GBDK development shell.";
  };

  # When the profile is enabled, define the devShell.
  config = lib.mkIf config.customConfig.profiles.development.gbdk.enable {
    customConfig.profiles.development.gbdk.devShell = pkgs.mkShell {
      packages = with pkgs; [
        gbdk     # Our local GBDK package
        mgba
        gnumake
        vscode
      ];

      # This hook runs when you enter the shell.
      shellHook = ''
        export GBDK_HOME="${gbdk}"
        echo "--- GBDK 2020 Dev Shell ---"
        echo "GBDK_HOME is set to: $GBDK_HOME"
        echo "Emulator 'mgba' is available in your path."
      '';
    };
  };
}