# ~/nixos-config/modules/home-manager/system/uno-calculator.nix
{ config, pkgs, lib, customConfig, ... }:

let
  appId = "uno.platform.uno-calculator";

  # Mirrors the guard in modules/nixos/programs/flatpak.nix: the calculator role
  # is the single place this app is chosen.
  enabled =
    customConfig.apps.programs.enable
    && lib.hasInfix appId customConfig.apps.programs.calculator.command;
in
{
  # Forces Uno Calculator into dark mode.
  #
  # The app has no theme setting of its own. The Flathub build is 1.2.9, forked
  # from microsoft/calculator before the Settings page that carries the "App
  # theme" option: its assembly exposes an About page and no Settings page, and
  # carries neither ThemeHelper nor the SelectedAppTheme key upstream writes. So
  # putting SelectedAppTheme into the app's own settings store (Local.dat) is
  # silently ignored — the app preserves the key and never reads it.
  #
  # What it does have is Uno's GtkSystemThemeHelperExtension, which derives the
  # XAML theme from GTK. That checks the theme *name* (IsGtkThemeDark), so
  # GTK_THEME=Adwaita:dark does not work: the ":dark" suffix sets only the
  # variant flag and leaves the name "Adwaita". A name containing "dark" is what
  # flips it.
  #
  # It has to be the flatpak's own config dir — ~/.config/gtk-3.0 is not visible
  # inside the sandbox. Verified on gaming-pc by bisecting the two mechanisms:
  # this file alone renders dark, a GTK_THEME=Adwaita-dark flatpak override alone
  # stays light.
  config = lib.mkIf (customConfig.desktop.enable && enabled) {
    home.file.".var/app/${appId}/config/gtk-3.0/settings.ini".text = ''
      [Settings]
      gtk-application-prefer-dark-theme=1
      gtk-theme-name=Adwaita-dark
    '';
  };
}
