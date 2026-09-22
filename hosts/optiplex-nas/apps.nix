# ~/nixos-config/hosts/optiplex-nas/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    programs = {
      claudeCode = {
        enable = true;
        remoteControl = {
          atStartup = true;
          server.enable = true;
        };
      };
    };

    packages = {
      nixos = with pkgs; [
        wget
        git
        vim
        htop
        claude-code
      ];
      unstable-override = [
        "claude-code"
        # 25.11 ships 3.4.6; Gamarr's Vimm source needs the Turnstile handling
        # added in 3.5.0 (it drives the verification control by tab presses),
        # and without it every Vimm download fails at "could not find download
        # form". Prowlarr shares this FlareSolverr and is unaffected by the bump.
        "flaresolverr"
      ];
      homeManager = with pkgs; [
        vscode
      ];
    };

  };
}
