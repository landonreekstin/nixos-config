# ~/nixos-config/modules/home-manager/themes/xbox360/default.nix
# Xbox 360 "Blades" dashboard (2005) rice. Unlike the other Hyprland themes this
# one is SESSION-SCOPED: it never touches ~/.config/hypr/hyprland.conf and is
# offered as its own display-manager entry, enabled through
# customConfig.homeManager.themes.hyprlandExtraSessions. See session.nix.
{ ... }:

{
  imports = [
    ./session.nix
  ];
}
