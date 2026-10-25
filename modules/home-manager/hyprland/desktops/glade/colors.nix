# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/colors.nix
#
# The Glade's palette — it is always night there — taken from the scene (pkgs/glade; the name
# boards in main.py, the glow colours in art.py), so the bar, window title bars and
# menus are made of the same carved wood and glowing moss as the signs in the scene.
{
  night = "#110d26";    # the night sky: bar and menu backgrounds
  board = "#422a4e";    # the carved wooden name boards
  boardHi = "#5c3c6a";  # a board you are pointing at
  ink = "#180e22";      # outlines and hard drop shadows
  text = "#ffeed6";     # carved lettering
  moss = "#6effbe";     # the things that glow
  cyan = "#6ee2ff";
  pink = "#fface4";
  violet = "#ba8cff";
  amber = "#ffc478";
  font = "Departure Mono"; # a pixel font, to match the glade's pixels

  # The terminal's 16 colours: the same glows on the night sky (kitty.nix).
  terminal = [
    "#180e22" "#ff6f91" "#4fd9a0" "#ffc478" "#6e9cff" "#ba8cff" "#6ee2ff" "#d8c8e0"
    "#5c3c6a" "#ff9ab3" "#6effbe" "#ffe0a8" "#9cbcff" "#fface4" "#a8f0ff" "#ffeed6"
  ];
}
