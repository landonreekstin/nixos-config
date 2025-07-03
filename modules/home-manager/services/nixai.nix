# ~/nixos-config/modules/home-manager/services/nixai.nix
{ config, lib, customConfig, pkgs, inputs, ... }:

{

    imports = [ inputs.nixai.homeManagerModules.default ];

    config = lib.mkIf customConfig.services.nixai.enable {
        services.nixai = {
            enable = true;

            # MCP Server configuration
            mcp = {
                enable = false;
                package = inputs.nixai.packages.${pkgs.system}.nixai;

                # User-specific paths
                socketPath = "$HOME/.local/share/nixai/mcp.sock";
                host = "localhost";
                port = 8081;

                # AI settings
                aiProvider = "gemini";
                aiModel = "gemini-pro";

                documentationSources = [
                    "https://wiki.nixos.org/wiki/NixOS_Wiki"
                    "https://nix.dev/manual/nix"
                    "https://nixos.org/manual/nixpkgs/stable/"
                    "https://nix.dev/manual/nix/2.28/language/"
                    "https://nix-community.github.io/home-manager/"
                ];
            };

            # VS Code integration
            vscodeIntegration.enable = true;

            # Neovim integration
            neovimIntegration.enable = false;
        };
    };
}