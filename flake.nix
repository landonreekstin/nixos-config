# ~/nixos-config/flake.nix
{
  description = "Lando's Modular NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    nixos-cosmic = {
      url = "github:lilyinstarlight/nixos-cosmic";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-vscode-server = {
       url = "github:nix-community/nixos-vscode-server";
       # It might need its own nixpkgs, or follow yours. Following is usually safer.
       inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-cosmic, home-manager, nixos-vscode-server, ... }@inputs: {
    # Define NixOS configurations for each host
    nixosConfigurations = {
      # Configuration for the Optiplex host
      optiplex = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # Pass flake inputs down to the modules if needed (good practice)
        specialArgs = { inherit inputs; };
        modules = [
          # Host-specific entrypoint
          ./hosts/optiplex/default.nix
          # home-manager module
          inputs.home-manager.nixosModules.default
        ];
      };

      # Configuration for the Gaming PC
      gaming-pc = nixpkgs.lib.nixosSystem {
         system = "x86_64-linux";
         specialArgs = { inherit inputs; };
         modules = [ ./hosts/gaming-pc/default.nix inputs.home-manager.nixosModules.default ];
      };

      # Configuration for Blaney's PC
      blaney-pc = nixpkgs.lib.nixosSystem {
         system = "x86_64-linux";
         specialArgs = { inherit inputs; };
         modules = [ ./hosts/blaney-pc/default.nix inputs.home-manager.nixosModules.default ];
      };
    };

    # Define Home Manager configurations later (optional alternative structure)
    # homeConfigurations = {
    #   "lando@optiplex" = home-manager.lib.homeManagerConfiguration { /* ... */ };
    #   "lando@gamingpc" = home-manager.lib.homeManagerConfiguration { /* ... */ };
    # };
  };
}
