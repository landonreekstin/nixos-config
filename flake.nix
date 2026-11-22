# ~/nixos-config/flake.nix
{
  description = "Lando's Modular NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixpkgs-unstable = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    # Version floor for signal-desktop only — see modules/nixos/unstable-overlay.nix.
    # Signal migrates ~/.config/Signal forward to a newer database schema and then
    # refuses to open it with an older build, so a host must never be handed a
    # signal-desktop older than the one that last touched its database. Bump this
    # rev forward when Signal needs updating; never move it backwards.
    nixpkgs-signal = {
      url = "github:NixOS/nixpkgs/c043004d1c6985732bcc1cbc5a9c9aecbbb4e0f0";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:Nixos/nixos-hardware";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    article2pod = {
      url = "github:landonreekstin/article2pod";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, disko, nixos-hardware, home-manager, plasma-manager, nixos-vscode-server, nix-flatpak, ... }@inputs:
    let
      # Define the target system
      system = "x86_64-linux";
      
      # Create the package set for our system. This is the correct way.
      pkgs = nixpkgs.legacyPackages.${system};
      unstablePkgs = import nixpkgs-unstable {
        system = system;  # This is allowed in import context
        config.allowUnfree = true;
      };
      lib = nixpkgs.lib;

      embeddedComponents = referenceHostConfig.customConfig.profiles.development.embedded-linux.components;

      # --- Reference Host for Flake Outputs ---
      # Some flake-level outputs like devShells need a complete NixOS configuration
      # to pull values from. We'll use 'gaming-pc' as our reference host because
      # that is the primary machine for kernel development.
      referenceHostConfig = self.nixosConfigurations."gaming-pc".config;

      # Define specialArgs once to pass to all hosts
      specialArgs = { inherit inputs unstablePkgs; };

      # Build a NixOS host on top of this repo's module library. Exported as
      # `lib.mkSystem` so downstream host repos build their hosts the same way: the
      # library's modules read `inputs.*` / `unstablePkgs` from specialArgs, which a
      # consumer cannot supply through plain imports, so this closes over *this*
      # flake's inputs. `extraSpecialArgs` is merged on top.
      mkSystem = { modules, extraSpecialArgs ? { } }: nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs // extraSpecialArgs;
        modules = modules ++ [
          inputs.home-manager.nixosModules.default
          # NUR — required for firefox-addons (librewolf extensions)
          inputs.nur.modules.nixos.default
          # Disko — declarative disk partitioning
          inputs.disko.nixosModules.default
          { nixpkgs.hostPlatform = system; }
        ];
      };
    in
  {
    lib = { inherit mkSystem; };

    # The module library, for reference. Hosts should use lib.mkSystem instead, which
    # also supplies the specialArgs these modules need.
    nixosModules.default = ./modules/nixos/default.nix;

    # Define NixOS configurations for each host
    nixosConfigurations = {

      # Every host is built with mkSystem (defined above, exported as lib.mkSystem).
      # vm-sandbox / vm-blaney are throwaway QEMU test-VM hosts, not installed to hardware:
      #   nixos-rebuild build-vm --flake .#vm-sandbox --impure && ./result/bin/run-*-vm
      # See hosts/vm-common.nix.
      optiplex = mkSystem { modules = [ ./hosts/optiplex/default.nix ]; };
      gaming-pc = mkSystem { modules = [ ./hosts/gaming-pc/default.nix ]; };
      blaney-pc = mkSystem { modules = [ ./hosts/blaney-pc/default.nix ]; };
      justus-pc = mkSystem { modules = [ ./hosts/justus-pc/default.nix ]; };
      asus-laptop = mkSystem { modules = [ ./hosts/asus-laptop/default.nix ]; };
      asus-m15 = mkSystem { modules = [ ./hosts/asus-m15/default.nix ]; };
      atl-mini-pc = mkSystem { modules = [ ./hosts/atl-mini-pc/default.nix ]; };
      optiplex-nas = mkSystem { modules = [ ./hosts/optiplex-nas/default.nix ]; };
      mini-server = mkSystem { modules = [ ./hosts/mini-server/default.nix ]; };
      vm-sandbox = mkSystem { modules = [ ./hosts/vm-sandbox/default.nix ]; };
      vm-blaney = mkSystem { modules = [ ./hosts/vm-blaney/default.nix ]; };

      # Bootable installer ISO — flash to USB for zero-touch install target setup.
      # SSH is pre-configured with lando's key so nixos-anywhere can connect immediately.
      # Build: nix build .#nixosConfigurations.installer.config.system.build.isoImage
      # Flash: sudo dd if=$(readlink -f result)/iso/*.iso of=/dev/sdX bs=4M status=progress conv=fsync
      installer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          {
            services.openssh = {
              enable = true;
              settings.PermitRootLogin = "yes";
            };
            users.users.root = {
              openssh.authorizedKeys.keyFiles = [ ./keys/lando.pub ];
              # Fallback password for console access (not for SSH)
              initialPassword = "nixos";
            };
            networking = {
              useDHCP = lib.mkDefault true;
              hostName = "nixos-installer";
            };
            documentation.enable = false;

            # On-target bootstrap helper for installs without LAN access to gaming-pc.
            # Usage: sudo nixos-install-local <hostname> <username>
            environment.systemPackages = [
              (nixpkgs.legacyPackages.x86_64-linux.writeShellScriptBin "nixos-install-local" ''
                set -euo pipefail
                HOSTNAME="''${1:?Usage: nixos-install-local <hostname> <username>}"
                USERNAME="''${2:?Usage: nixos-install-local <hostname> <username>}"
                REPO="https://github.com/landonreekstin/nixos-config.git"
                echo "Cloning nixos-config from GitHub..."
                git clone "$REPO" /tmp/nixos-config
                cd /tmp/nixos-config
                sudo ./scripts/install-new-host.sh "$HOSTNAME" "$USERNAME"
              '')
            ];

            environment.etc."issue.nixos-installer".text = ''

              ╔══════════════════════════════════════════════════════╗
              ║           NixOS Installer — landonreekstin           ║
              ╠══════════════════════════════════════════════════════╣
              ║  OPTION A — Admin machine on same LAN (gaming-pc):   ║
              ║    ./scripts/deploy-host.sh <hostname> <ip>          ║
              ║                                                       ║
              ║  OPTION B — No LAN / off-site install:               ║
              ║    sudo nixos-install-local <hostname> <username>     ║
              ╚══════════════════════════════════════════════════════╝

            '';
          }
        ];
      };
    };

    # Custom packages not in nixpkgs
    packages.x86_64-linux = {
      worldmonitor = pkgs.callPackage ./pkgs/worldmonitor { };
      spotatui = pkgs.callPackage ./pkgs/spotatui { };
      tuisic = pkgs.callPackage ./pkgs/tuisic { };
      gamarr = pkgs.callPackage ./pkgs/gamarr { };
      quiver-launcher = pkgs.callPackage ./pkgs/quiver-launcher { };
      f-117 = pkgs.callPackage ./pkgs/f-117 { };
    };

    # Development Shells provided by this flake
    devShells.x86_64-linux = {
      kernel-dev = pkgs.mkShell referenceHostConfig.customConfig.profiles.development.kernel.devShell;

      fpga-dev = referenceHostConfig.customConfig.profiles.development.fpga-ice40.devShell;

      embedded-linux = referenceHostConfig.customConfig.profiles.development.embedded-linux.devShell;

      gbdk-dev = referenceHostConfig.customConfig.profiles.development.gbdk.devShell;

      cpp-practice = referenceHostConfig.customConfig.profiles.development.cpp-practice.devShell;

      emulation = referenceHostConfig.customConfig.profiles.development.emulation.devShell;

      # Blaney's vibe-coded app workspaces (customConfig.programs.vibeProjects).
      # Enabled on gaming-pc purely so these exist as flake outputs — see
      # modules/nixos/development/vibe-python.nix.
      vibe-python = referenceHostConfig.customConfig.profiles.development.vibe-python.devShell;

      vibe-web = referenceHostConfig.customConfig.profiles.development.vibe-web.devShell;

      # ~/reverse-engineering workspace (REA + recompilation toolchains).
      reverse-engineering = referenceHostConfig.customConfig.profiles.development.reverse-engineering.devShell;

      # ~/gamedev workspace (Godot, LÖVE, pygame-ce, Node + asset tools).
      gamedev = referenceHostConfig.customConfig.profiles.development.gamedev.devShell;
    };

  };
}
