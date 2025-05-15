# ~/nixos-config/hosts/optiplex/home.nix
{ pkgs, config, lib, inputs, ... }:

{

  imports = [
    ../../modules/home-manager/rice/century-series/default.nix
  ];

  # Home Manager needs its own state version. Start with the same version
  # as the system stateVersion for consistency.
  home.stateVersion = "24.11";

  xdg.enable = true;

  # Define the home directory and username for this configuration.
  # These are usually inferred correctly but setting explicitly is good practice.
  home.username = "lando";
  home.homeDirectory = "/home/lando";

  # == Packages managed by Home Manager ==
  # Packages installed here are available only to this user.
  # You could move user-specific tools like fastfetch, git from core.nix here.
  home.packages = with pkgs; [
    # Example: Add a fun utility
    cowsay
    # Example: Add a tool for finding dotfiles later
    fd # find replacement
    vscodium
    librewolf
  ];

  # == Dotfile Management Example: Kitty Terminal ==
  # Let's manage the kitty config file.
  # Any settings you define here will overwrite ~/.config/kitty/kitty.conf
  home.file.".config/kitty/kitty.conf" = {
    # Use 'text' for simple, single-line content or small multi-line content
    text = ''
      # Basic Kitty Font Settings (Example)
      font_family      MesloLGS NF
      bold_font        auto
      italic_font      auto
      bold_italic_font auto
      font_size 11.0

      # Enable ligature support (if font supports it)
      # font_features MesloLGS-NF +ss01 +ss02 +ss03 +ss04 +ss05 +ss06 +ss07 +ss08 +calt +liga

      # Cursor customization
      cursor_shape     block
      cursor_blink_interval 0.5

      # Scrollback
      scrollback_lines 2000

      # Basic Colors (Example using built-in theme - customize later!)
      # include current_theme.conf
      background #282a36
      foreground #f8f8f2

      # Tab bar
      tab_bar_edge bottom
      tab_bar_style powerline
    '';
    # Use 'source = ./path/to/your/local/kitty.conf;' to link to a file
    # within your git repo instead of writing the text inline.
    # source = ../../modules/home-manager/dotfiles/kitty.conf; # Example path

    # Ensure the target directory exists
    recursive = true; # Creates .config/kitty if it doesn't exist
  };

  # == Other Home Manager Modules ==
  # Example: Configure git user settings
  programs.git = {
    enable = true;
    userName = "Lando";
    userEmail = "landonreekstin@gmail.com";
  };

  # ==> Enable Bash management and configure login startup <==
  programs.bash = {
    enable = true; # Explicitly manage bash config files

    # profileExtra appends to ~/.profile (or .bash_profile)
    profileExtra = ''
      # Start Hyprland automatically on TTY1 if not already in a graphical session
      if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
        echo "Attempting to start Hyprland from profileExtra on TTY1..."
        # Use exec to replace the shell process with Hyprland
        exec ${pkgs.hyprland}/bin/Hyprland
      fi
    ''; # End profileExtra

  };

  # == Enable Home Manager management ==
  # This must be enabled for Home Manager to work.
  programs.home-manager.enable = true;

}
