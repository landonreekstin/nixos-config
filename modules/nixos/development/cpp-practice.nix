# ~/nixos-config/modules/nixos/development/cpp-practice.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.profiles.development.cpp-practice;
in
{
  options.customConfig.profiles.development.cpp-practice.devShell = lib.mkOption {
    type = lib.types.package;
    internal = true;
    description = "C++ practice dev shell derivation.";
  };

  config = lib.mkIf cfg.enable {
    customConfig.profiles.development.cpp-practice.devShell = pkgs.mkShell {
      name = "cpp-practice";
      packages = with pkgs; [
        gcc          # g++ compiler
        clang        # clang++ compiler
        cmake
        gnumake
        gdb
        clang-tools  # clangd LSP for editors
      ];
      shellHook = ''
        code .
      '';
    };
  };
}
