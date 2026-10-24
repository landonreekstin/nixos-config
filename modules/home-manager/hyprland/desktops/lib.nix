# ~/nixos-config/modules/home-manager/hyprland/desktops/lib.nix
# The options every Hyprland desktop has, declared by ../desktops.nix as
# options.hyprDesktops.<name> for each directory here. One option set per desktop
# (rather than one attrsOf submodule for all) so that ../desktops.nix can read the
# raw definitions, mkForce/mkDefault and all, and merge them against the
# functional layer's own definitions of the same Hyprland options.
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
    plugins = mkOption {
      type = types.listOf (types.either types.package types.path);
      default = [ ];
      description = "Hyprland plugins this desktop loads (glade: hyprbars).";
    };
    transformSettings = mkOption {
      type = types.raw;
      default = s: s;
      description = ''
        A function applied to the fully merged settings, for the few edits that
        can only be made after merging (dropping a functional exec-once line,
        rewriting a keybind's command). Not applied when this is the default
        desktop, whose settings home-manager renders into hyprland.conf.
      '';
    };
    leaveExtraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Added to the default desktop's config when this desktop is offered as a
        separate session: undoes state this desktop leaves behind (xbox360 turns
        TV Mode back off).
      '';
    };
    waybar = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether the shared waybar runs in this desktop. A desktop with its own
        shell (xbox360) sets false: its rendered config drops waybar-start, and
        waybar-restart does nothing while it is live. Only honoured for a
        non-default desktop.
      '';
    };
    lockCommand = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        What locks the screen while this desktop is live (idle, before sleep).
        null: swaylock.
      '';
    };
  };

  # The systemd user target that is active exactly while desktop `name`'s session
  # runs (../desktops.nix). A unit that belongs to one desktop merges in
  # `bindTo name`, so it starts with that session and stops when it ends.
  target = name: "hypr-desktop-${name}.target";
  bindTo = name: {
    Unit = {
      PartOf = [ "hypr-desktop-${name}.target" ];
      After = [ "hypr-desktop-${name}.target" ];
    };
    Install.WantedBy = [ "hypr-desktop-${name}.target" ];
  };

  # Shell: the name of the desktop whose session is live, or "" outside one (and
  # for the moment at login before its target has started). Absolute, because
  # systemd units and swayidle run with a minimal PATH.
  current = "$(/etc/profiles/per-user/$(id -un)/bin/hypr-desktop current)";

  # Whether desktop `name` is offered on this host, and whether it is the default.
  # The default desktop alone owns the global app configs (waybar, rofi, kitty,
  # GTK, ...), since each of those apps reads a single file.
  state = customConfig: name:
    let
      on = elem "hyprland" customConfig.desktop.environments;
      d = customConfig.homeManager.hyprland.desktops;
    in
    {
      enabled = on && elem name d.enabled;
      isDefault = on && d.default == name;
    };
}
