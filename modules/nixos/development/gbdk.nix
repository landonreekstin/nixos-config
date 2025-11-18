# ~/nixos-config/modules/nixos/development/gbdk.nix
{ lib, pkgs, config, ... }:

let
  gbdk = pkgs.stdenv.mkDerivation rec {
    pname = "gbdk-2020";
    version = "4.2.0";

    src = pkgs.fetchurl {
      url = "https://github.com/gbdk-2020/gbdk-2020/releases/download/4.2.0/gbdk-linux64.tar.gz";
      # --- THIS IS THE FIX ---
      # Corrected 'sha265' to 'sha256'
      hash = "sha256-6WxOJ87H8IRpkh6s2o0RIg/hZYVT1xL7UUbJbl6CVwY=";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];

    buildInputs = [ pkgs.glibc ];

    # This installPhase is correct for the source tarball structure.
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
  options.customConfig.profiles.development.gbdk.devShell = with lib; mkOption {
    type = types.package;
    internal = true;
    description = "The derivation for the GBDK development shell.";
  };

  config = lib.mkIf config.customConfig.profiles.development.gbdk.enable {
    customConfig.profiles.development.gbdk.devShell = pkgs.mkShell {
      packages = [
        gbdk
        pkgs.mgba
        pkgs.gnumake
        pkgs.vscode
      ];

      shellHook = ''
        export GBDK_HOME="${gbdk}"
        echo "--- GBDK 2020 Dev Shell ---"
        echo "GBDK_HOME is set to: $GBDK_HOME"
        echo "Compiler 'lcc' and emulator 'mgba' are available in your path."
      '';
    };
  };
}