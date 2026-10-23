# ~/nixos-config/modules/home-manager/hyprland/desktops/lib.nix
# The options every Hyprland desktop declares for itself, as
#   options.hyprDesktops.<name> = (import ../lib.nix { inherit lib; }).desktopOptions;
# Each desktop declares its own (rather than one attrsOf submodule for all) so that
# ../desktops.nix can read the raw definitions, mkForce/mkDefault and all, and merge
# them against the functional layer's own definitions of the same Hyprland options.
{ lib }:

with lib;
{
  desktopOptions = {
    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = ''
        This desktop's wayland.windowManager.hyprland.settings, merged onto the
        functional layer's. Priorities count against the functional layer's values:
        a value it sets without mkDefault needs mkForce here. Never set exec-once
        here — functional.nix's list is mkDefault, so a plain definition replaces it;
        startup lines go in extraConfig.
      '';
    };
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Appended after the functional layer's extraConfig.";
    };
    transformSettings = mkOption {
      type = types.raw;
      default = s: s;
      description = ''
        A function applied to the fully merged settings, for the few edits that
        can only be made after merging (dropping a functional exec-once line,
        rewriting a keybind's command).
      '';
    };
  };
}
