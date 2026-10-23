# ~/nixos-config/modules/home-manager/hyprland/desktops.nix
# Hyprland desktops (customConfig.homeManager.hyprland.desktops): imports every
# desktops/<name>/ and renders each enabled one, other than the default, to its own
# ~/.config/hypr/desktops/<name>.conf, which that desktop's display-manager entry
# starts Hyprland with (modules/nixos/desktop/hyprland.nix). The default desktop
# keeps ~/.config/hypr/hyprland.conf.
#
# How a desktop's config is built: home-manager merges every module's
# wayland.windowManager.hyprland.{settings,extraConfig} into the ONE hyprland.conf,
# and once merged nothing can be taken back out. So instead of reading the merged
# value, each desktop's file re-merges the option's individual definitions — those
# of the functional layer (functional.nix, swayidle.nix, ...) — with the
# desktop's own (hyprDesktops.<name>, see desktops/lib.nix), keeping priorities.
# The functional layer therefore reaches every desktop from a single source.
{ config, options, pkgs, lib, customConfig, ... }:

let
  dcfg = customConfig.homeManager.hyprland.desktops;
  on = lib.elem "hyprland" customConfig.desktop.environments;

  # Every subdirectory of desktops/ is a desktop.
  desktopNames = lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir ./desktops));

  hyprOpts = options.wayland.windowManager.hyprland;
  declared = options.hyprDesktops or { };

  # Which definitions of wayland.windowManager.hyprland.* are the functional layer's.
  # Desktops not yet moved under desktops/ (century-series, glade, future-aviation in
  # themes/) still write theirs straight into hyprland.conf; matching on the file the
  # module system records for each definition is what keeps them out of every other
  # desktop. A desktop under desktops/ may also add to hyprland.conf (xbox360 cleans
  # up after itself there), and that is the default session's alone too.
  isFunctional = def:
    let f = toString def.file; in
    !(lib.hasInfix "/modules/home-manager/themes/" f
      || lib.hasInfix "/modules/home-manager/hyprland/desktops/" f);

  mergeOnto = opt: desktopDefs:
    (lib.modules.mergeDefinitions opt.loc opt.type
      (lib.filter isFunctional opt.definitionsWithLocations ++ desktopDefs)).mergedValue;

  render = name:
    let
      d = declared.${name};
      settings = config.hyprDesktops.${name}.transformSettings
        (mergeOnto hyprOpts.settings d.settings.definitionsWithLocations);
    in
    lib.hm.generators.toHyprconf {
      attrs = settings;
      inherit (config.wayland.windowManager.hyprland) importantPrefixes;
    }
    + mergeOnto hyprOpts.extraConfig d.extraConfig.definitionsWithLocations;

  sessionDesktops = lib.filter (n: n != dcfg.default && declared ? ${n}) dcfg.enabled;

  # The same reload home-manager does for hyprland.conf: `hyprctl reload` re-reads
  # whichever file each running instance was started with.
  reload = ''
    (
      XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
      if [[ -d "$XDG_RUNTIME_DIR/hypr" ]]; then
        for i in $(${pkgs.hyprland}/bin/hyprctl instances -j | ${pkgs.jq}/bin/jq -r ".[].instance"); do
          ${pkgs.hyprland}/bin/hyprctl -i "$i" reload config-only
        done
      fi
    )
  '';
in
{
  imports = map (n: ./desktops + "/${n}") desktopNames;

  config = lib.mkIf on {
    assertions = map (n: {
      assertion = n == dcfg.default || lib.elem n desktopNames;
      message = ''
        customConfig.homeManager.hyprland.desktops.enabled lists "${n}", but there is no
        modules/home-manager/hyprland/desktops/${n}/ (only the default desktop may still
        live in themes/).
      '';
    }) dcfg.enabled;

    xdg.configFile = lib.listToAttrs (map (name:
      lib.nameValuePair "hypr/desktops/${name}.conf" {
        text = render name;
        onChange = reload;
      }) sessionDesktops);
  };
}
