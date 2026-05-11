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
        # Generate .vscode/c_cpp_properties.json from the compiler's actual include paths.
        # This runs inside the devShell so g++ reports its real nix store paths,
        # staying correct after any flake update without hardcoding store hashes.
        mkdir -p .vscode
        _cpp_paths=()
        while IFS= read -r _p; do
          [[ -n "$_p" ]] && _cpp_paths+=("\"$_p\"")
        done < <(g++ -v -x c++ /dev/null -fsyntax-only 2>&1 \
          | awk '/#include <...> search starts here:/{f=1;next} /End of search list/{f=0} f{gsub(/^ +/,""); if(length) print}')
        _cpp_joined=$(IFS=,; printf '%s' "''${_cpp_paths[*]}")
        cat > .vscode/c_cpp_properties.json << CPPEOF
        {
          "configurations": [
            {
              "name": "NixOS",
              "includePath": ["\''${workspaceFolder}/**", $_cpp_joined],
              "defines": [],
              "compilerPath": "$(command -v g++)",
              "cStandard": "c17",
              "cppStandard": "c++17",
              "intelliSenseMode": "linux-gcc-x64"
            }
          ],
          "version": 4
        }
        CPPEOF
        code .
      '';
    };
  };
}
