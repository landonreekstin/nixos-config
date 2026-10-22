# ~/nixos-config/modules/home-manager/themes/glade/colors.nix
#
# The Glade's palette — it is always night there — taken from pkgs/glade/src (the name
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
}
