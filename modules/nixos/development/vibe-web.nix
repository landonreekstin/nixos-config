# ~/nixos-config/modules/nixos/development/vibe-web.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.profiles.development.vibe-web;
in
{
  options.customConfig.profiles.development.vibe-web.devShell = lib.mkOption {
    type = lib.types.package;
    internal = true;
    description = "Node/TypeScript dev shell for vibe-coded apps (see customConfig.programs.vibeProjects).";
  };

  options.customConfig.profiles.development.vibe-web.enable = with lib; mkOption {
    type = types.bool;
    default = false;
    description = ''
      Expose the `vibe-web` dev shell. Declares the shell ONLY — it adds nothing to the
      system. See vibe-python.nix for why this has to be enabled on gaming-pc as well as
      on the host that actually uses it.
    '';
  };

  config = lib.mkIf cfg.enable {
    customConfig.profiles.development.vibe-web.devShell = pkgs.mkShell {
      name = "vibe-web";

      packages = with pkgs; [
        # The LTS line rather than pkgs.nodejs (24): it is what the ecosystem's
        # prebuilt native modules target, and it is cached.
        nodejs_22
        pnpm
        typescript   # tsc, for a project that is not going through a bundler
      ];

      shellHook = ''
        export DEV_ENV_NAME="vibe-web"
        echo "--- Web app workspace ---"
        echo "Install packages with:  pnpm install        Start the app with:  pnpm dev"
        echo "-------------------------"
      '';
    };
  };
}
