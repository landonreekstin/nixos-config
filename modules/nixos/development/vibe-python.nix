# ~/nixos-config/modules/nixos/development/vibe-python.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.profiles.development.vibe-python;
in
{
  options.customConfig.profiles.development.vibe-python.devShell = lib.mkOption {
    type = lib.types.package;
    internal = true;
    description = "Python dev shell for vibe-coded apps (see customConfig.programs.vibeProjects).";
  };

  options.customConfig.profiles.development.vibe-python.enable = with lib; mkOption {
    type = types.bool;
    default = false;
    description = ''
      Expose the `vibe-python` dev shell. This declares the shell ONLY — it adds nothing
      to the system — so it is free to enable on a host that merely needs the flake output.

      It must be enabled on gaming-pc regardless of which host uses it: flake.nix reads
      devShells off `referenceHostConfig = self.nixosConfigurations."gaming-pc".config`,
      so a shell left disabled there does not exist as `nix develop .#vibe-python` and
      every project .envrc pointing at it fails.
    '';
  };

  config = lib.mkIf cfg.enable {
    customConfig.profiles.development.vibe-python.devShell = pkgs.mkShell {
      name = "vibe-python";

      packages = with pkgs; [
        # One interpreter carrying its libraries: a bare python3 plus loose
        # python3Packages.* would not see them on sys.path.
        (python3.withPackages (ps: with ps; [
          tkinter    # stdlib GUI toolkit — no build step, ships with the interpreter
          pygame     # 2D games
          pillow     # images
          requests   # anything that talks HTTP
          pyqt6      # when tkinter is not enough to look native
        ]))
        ruff         # lint + format, one binary
      ];

      shellHook = ''
        export DEV_ENV_NAME="vibe-python"
        echo "--- Python app workspace ---"
        echo "Run your app with:  python <file>.py        Check your code with:  ruff check ."
        echo "----------------------------"
      '';
    };
  };
}
