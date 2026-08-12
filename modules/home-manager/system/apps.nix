# ~/nixos-config/modules/home-manager/system/apps.nix
{ config, pkgs, lib, customConfig, ... }:

let
  cfg = customConfig.apps.programs;

  # Every attribute of apps.programs except the enable flag is an application role.
  roles = lib.filterAttrs (name: _: name != "enable") cfg;

  # modules/home-manager/programs/librewolf.nix installs its own configured
  # librewolf via programs.librewolf when customConfig.homeManager.librewolf is
  # enabled. Installing pkgs.librewolf alongside it puts two derivations that
  # both ship policies.json into the profile, which collides. When that module
  # is enabled it owns the browser role, so skip the package here — the role's
  # `command` still points at librewolf, which is what the keybinds need.
  librewolfModuleOwnsBrowser =
    customConfig.homeManager.librewolf.enable
    && cfg.browser.package != null
    && lib.hasPrefix "librewolf" (lib.getName cfg.browser.package);

  wanted = if librewolfModuleOwnsBrowser then lib.filterAttrs (n: _: n != "browser") roles
           else roles;

  packages = lib.filter (p: p != null) (lib.mapAttrsToList (_: role: role.package) wanted);
in
{
  # Installs the user applications declared in customConfig.apps.programs.
  #
  # This is the single place user-facing programs get installed. Previously they
  # were hardcoded in the Hyprland home-manager module, which meant enabling a
  # window manager silently pulled in a browser, a chat client and a dozen other
  # applications that the host file never mentioned.
  #
  # Note this deliberately does not include the gaming platforms: those come from
  # customConfig.profiles.gaming, and their roles carry no package.
  config = lib.mkIf (customConfig.desktop.enable && cfg.enable) {
    home.packages = packages;
  };
}
