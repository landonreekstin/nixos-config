# ~/nixos-config/flake.nix
{
  description = "Lando's Modular NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-hardware = {
      url = "github:Nixos/nixos-hardware";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    nixos-cosmic = {
      url = "github:lilyinstarlight/nixos-cosmic";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nixos-vscode-server = {
       url = "github:nix-community/nixos-vscode-server";
       # It might need its own nixpkgs, or follow yours. Following is usually safer.
       inputs.nixpkgs.follows = "nixpkgs";
    };

    nixai = {
      url = "github:olafkfreund/nix-ai-help";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, nixos-cosmic, home-manager, plasma-manager, nixos-vscode-server, nixai, ... }@inputs:
    let
      # Define the target system
      system = "x86_64-linux";
      
      # Create the package set for our system. This is the correct way.
      pkgs = nixpkgs.legacyPackages.${system};

      # --- Reference Host for Flake Outputs ---
      # Some flake-level outputs like devShells need a complete NixOS configuration
      # to pull values from. We'll use 'gaming-pc' as our reference host because
      # that is the primary machine for kernel development.
      referenceHostConfig = self.nixosConfigurations."gaming-pc".config;
    in
  {
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
         modules = [ 
          ./hosts/gaming-pc/default.nix 
          inputs.home-manager.nixosModules.default
          inputs.nixos-cosmic.nixosModules.default 
        ];
      };

      # Configuration for Blaney's PC
      blaney-pc = nixpkgs.lib.nixosSystem {
         system = "x86_64-linux";
         specialArgs = { inherit inputs; };
         modules = [ ./hosts/blaney-pc/default.nix inputs.home-manager.nixosModules.default ];
      };

      # Configuration for Justus's PC
      justus-pc = nixpkgs.lib.nixosSystem {
         system = "x86_64-linux";
         specialArgs = { inherit inputs; };
         modules = [
          ./hosts/justus-pc/default.nix
          inputs.home-manager.nixosModules.default 
          inputs.disko.nixosModules.default
        ];
      };

      # Configuration for the Asus ROG Zephyrus G14 Laptop
      asus-laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/asus-laptop/default.nix inputs.home-manager.nixosModules.default ];
      };

      # Configuration for the Optiplex NAS
      optiplex-nas = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/optiplex-nas/default.nix
          inputs.home-manager.nixosModules.default
          inputs.disko.nixosModules.default
        ];
      };
    };

    # Development Shells provided by this flake
    devShells.x86_64-linux = {
      # The 'kernel-dev' shell is sourced from our new module.
      # We take the configuration from the evaluated optiplex host.
      kernel-dev = pkgs.mkShell referenceHostConfig.customConfig.profiles.development.kernel.devShell;
    };

  };
}
