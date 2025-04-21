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
    nix-ld-rs = { # Using the newer nix-ld-rs flake
        url = "github:nix-community/nix-ld-rs";
        inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-cosmic, home-manager, nixos-vscode-server, nix-ld-rs, ... }@inputs: {
    # Define NixOS configurations for each host
    nixosConfigurations = {
      # Configuration for the Optiplex host
      optiplex = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # Pass flake inputs down to the modules if needed (good practice)
        specialArgs = { inherit inputs nixos-vscode-server nix-ld-rs; };
        modules = [
          # Host-specific entrypoint
          ./hosts/optiplex/default.nix

          # We will integrate Home Manager modules here later
          home-manager.nixosModules.home-manager
          # {
          #   home-manager.useGlobalPkgs = true;
          #   home-manager.useUserPackages = true;
          #   # User configs will be imported within the host or profile modules
          # }
        ];
      };

      # Configuration for the Gaming PC (placeholder for now)
      # gamingpc = nixpkgs.lib.nixosSystem {
      #   system = "x86_64-linux";
      #   specialArgs = { inherit inputs; };
      #   modules = [ ./hosts/gamingpc/default.nix /* ... */ ];
      # };
    };

    # Define Home Manager configurations later (optional alternative structure)
    # homeConfigurations = {
    #   "lando@optiplex" = home-manager.lib.homeManagerConfiguration { /* ... */ };
    #   "lando@gamingpc" = home-manager.lib.homeManagerConfiguration { /* ... */ };
    # };
  };
}
