# ~/nixos-config/modules/home-manager/system/apps.nix
{ config, pkgs, lib, customConfig, ... }:

let
  cfg = customConfig.apps.programs;

  # Every attribute of apps.programs except the enable flag is an application role.
  roles = lib.filterAttrs (name: _: name != "enable") cfg;

  # modules/home-manager/programs/browser/ installs its own configured browser
  # via programs.firefox / programs.librewolf when
  # customConfig.homeManager.browser.<browser> is enabled. Installing
  # pkgs.<browser> alongside it puts two derivations that both ship
  # policies.json into the profile, which collides. When that module owns the
  # browser role, skip the package here — the role's `command` still points at
  # the binary, which is what the keybinds need.
  browserCfg = customConfig.homeManager.browser;
  browserModuleOwnsRole =
    cfg.browser.package != null
    && lib.any
      (name: browserCfg.${name}.enable && lib.hasPrefix name (lib.getName cfg.browser.package))
      [ "firefox" "librewolf" ];

  wanted = if browserModuleOwnsRole then lib.filterAttrs (n: _: n != "browser") roles
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
