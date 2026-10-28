# ~/nixos-config/hosts/gaming-pc/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    gaming.enable = true;
    # Quest 2 over USB via WiVRn (DCS World first). See docs/vr.md.
    vr.enable = true;
    development = {
      fpga-ice40.enable = true;
      kernel.enable = true;
      embedded-linux.enable = true;
      gbdk.enable = true;
      cpp-practice.enable = true;
      emulation.enable = true;
      # REA + Ghidra + the `re` launcher and ~/reverse-engineering workspace.
      reverse-engineering.enable = true;
      # Godot/LÖVE/pygame + the gamedev skills, the `gd` launcher and ~/gamedev.
      gamedev.enable = true;
      # Not used on this host. flake.nix builds every devShell from THIS host's
      # evaluated config (referenceHostConfig), so a shell left disabled here does not
      # exist as a flake output at all — and blaney-pc's project .envrc files point at
      # `~/nixos-config#vibe-python`. These two modules declare the shell and nothing
      # else, so enabling them adds nothing to gaming-pc's system closure.
      vibe-python.enable = true;
      vibe-web.enable = true;
    };
  };
}
