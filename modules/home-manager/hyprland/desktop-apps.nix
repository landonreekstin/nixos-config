# ~/nixos-config/modules/home-manager/hyprland/desktop-apps.nix
# The shared apps of a Hyprland desktop that is not the default.
#
# waybar, rofi, wlogout, swaylock and kitty each read one config file, which the
# default desktop owns. A desktop with hyprDesktops.<name>.ownApps gets its own
# copies when it is offered as a separate session: home-manager is evaluated a
# second time with that desktop as the only, default one, and the files it would
# write for these apps are collected into ~/.config/hypr/desktops/<name>/:
#
#   waybar/ kitty/ rofi/ swaylock/ wlogout/   what that evaluation writes
#   bin/{rofi,wlogout,swaylock}               the app, started on those files
#   env                                       PATH, KITTY_CONFIG_DIRECTORY, GTK_THEME
#
# The session's start script sources `env` (modules/nixos/desktop/hyprland.nix),
# so everything the compositor starts finds the wrappers first, and waybar-start
# takes this waybar config. That is why keybinds and bar buttons call these apps
# by bare name: an absolute store path would skip the wrapper.
#
# Apps whose one config file the default desktop keeps regardless (btop, yazi,
# zathura, imv, dunst) are not covered.
{ config, pkgs, lib, customConfig, extendModules, ... }:

let
  dcfg = customConfig.homeManager.hyprland.desktops;
  on = lib.elem "hyprland" customConfig.desktop.environments;

  sessionDesktops = lib.filter (n: n != dcfg.default) dcfg.enabled;
  owners = lib.filter (n: config.hyprDesktops.${n}.ownApps) sessionDesktops;

  dirOf = name: "${config.home.homeDirectory}/.config/hypr/desktops/${name}";

  # Home-manager as it would be with `name` as the host's only desktop. Only one
  # desktop is enabled in it, so it renders no other desktop and does not recurse.
  evalAs = name: (extendModules {
    specialArgs.customConfig = lib.recursiveUpdate customConfig {
      homeManager.hyprland.desktops = { enabled = [ name ]; default = name; };
    };
  }).config;

  apps = name:
    let
      c = evalAs name;
      dir = dirOf name;
      files = lib.filterAttrs (_: f: f.enable) c.xdg.configFile;
      under = prefix: lib.filterAttrs (p: _: lib.hasPrefix "${prefix}/" p) files;
      has = p: files ? ${p};

      # home-manager writes rofi's config with home.file. rofi finds an attrset
      # theme by name in ~/.local/share/rofi/themes, where the
      # default desktop's theme has the same name; point at the file instead.
      rofiThemes = lib.filterAttrs (p: _: lib.hasPrefix "rofi/themes/" p)
        (lib.filterAttrs (_: f: f.enable) c.xdg.dataFile);
      rofiConfig = pkgs.writeText "rofi-${name}.rasi" (lib.replaceStrings
        (lib.mapAttrsToList (p: _: "@theme \"${lib.removeSuffix ".rasi" (lib.removePrefix "rofi/themes/" p)}\"") rofiThemes)
        (lib.mapAttrsToList (_: f: "@theme \"${f.source}\"") rofiThemes)
        c.home.file.${c.programs.rofi.configPath}.text);

      wrapper = bin: cmd: pkgs.writeShellScript bin ''exec ${cmd} "$@"'';
      wrappers =
        lib.optionalAttrs c.programs.rofi.enable {
          rofi = wrapper "rofi" "${c.programs.rofi.finalPackage}/bin/rofi -config ${rofiConfig}";
        }
        // lib.optionalAttrs (has "wlogout/layout" || has "wlogout/style.css") {
          wlogout = wrapper "wlogout" (lib.concatStringsSep " " ([ "${c.programs.wlogout.package}/bin/wlogout" ]
            ++ lib.optional (has "wlogout/layout") "-l ${files."wlogout/layout".source}"
            ++ lib.optional (has "wlogout/style.css") "-C ${files."wlogout/style.css".source}"));
        }
        // lib.optionalAttrs (has "swaylock/config") {
          swaylock = wrapper "swaylock" "${c.programs.swaylock.package}/bin/swaylock -C ${files."swaylock/config".source}";
        };

      env = pkgs.writeText "hypr-desktop-${name}-env" (''
        export HYPR_DESKTOP_APPS="${dir}"
        export PATH="${dir}/bin:$PATH"
      '' + lib.optionalString (under "kitty" != { }) ''
        export KITTY_CONFIG_DIRECTORY="${dir}/kitty"
      '' + lib.optionalString (c.gtk.enable && c.gtk.theme != null) ''
        export GTK_THEME="${c.gtk.theme.name}"
      '');
    in
    {
      farm = pkgs.linkFarm "hypr-desktop-${name}-apps" (
        lib.mapAttrsToList (p: f: { name = p; path = f.source; })
          (under "waybar" // under "kitty" // under "swaylock" // under "wlogout")
        ++ lib.optional c.programs.rofi.enable { name = "rofi/config.rasi"; path = rofiConfig; }
        ++ lib.mapAttrsToList (bin: path: { name = "bin/${bin}"; inherit path; }) wrappers
        ++ [ { name = "env"; path = env; } ]);
      swaylock = wrappers ? swaylock;
    };
in
{
  config = lib.mkIf on {
    xdg.configFile = lib.listToAttrs (map (name:
      lib.nameValuePair "hypr/desktops/${name}" { source = (apps name).farm; }) owners);

    # Idle and before-sleep locking, too. Named after every session desktop, not
    # just the owners: the names may not depend on hyprDesktops itself.
    hyprDesktops = lib.genAttrs sessionDesktops (name: {
      lockCommand = lib.mkIf (lib.elem name owners && (apps name).swaylock)
        (lib.mkDefault "${dirOf name}/bin/swaylock");
    });
  };
}
