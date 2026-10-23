# ~/nixos-config/modules/home-manager/hyprland/desktops/xbox360/default.nix
# Xbox 360 "Blades" dashboard (2005) as a Hyprland desktop: its own login entry
# ("Xbox 360 Dashboard", meta.nix), enabled by listing "xbox360" in
# customConfig.homeManager.hyprland.desktops.enabled. session.nix adds this
# desktop's Hyprland settings and startup; ../../desktops.nix renders them onto
# the functional layer. The program itself (shell, controller daemon) is
# pkgs/xbox360-dashboard, from its own repo.
{ ... }:

{
  imports = [
    ./session.nix
  ];
}
