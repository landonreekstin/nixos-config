{
  config,
  pkgs,
  lib,
  customConfig,
  ...
}:

let
  aerothemeCondition = (lib.elem "kde" customConfig.desktop.environments
    && customConfig.homeManager.enable && customConfig.homeManager.themes.kde == "windows7-alt");
in {
  config = lib.mkIf aerothemeCondition {
  home.file = {
    # TODO: find a better way to do this than home symlinks.
    ".local/share/plasma/desktoptheme".source = "${pkgs.aerothemeplasma-git}/plasma/desktoptheme";
    ".local/share/plasma/look-and-feel".source = "${pkgs.aerothemeplasma-git}/plasma/look-and-feel";
    ".local/share/plasma/plasmoids".source = "${pkgs.aerothemeplasma-git}/plasma/plasmoids";
    ".local/share/plasma/layout-templates".source = "${pkgs.aerothemeplasma-git}/plasma/layout-templates";
    ".local/share/plasma/shells".source = "${pkgs.aerothemeplasma-git}/plasma/shells";
    ".local/share/kwin/effects".source = "${pkgs.aerothemeplasma-git}/kwin/effects";
    ".local/share/kwin/tabbox".source = "${pkgs.aerothemeplasma-git}/kwin/tabbox";
    ".local/share/kwin/outline".source = "${pkgs.aerothemeplasma-git}/kwin/outline";
    # ".config/fontconfig/fonts.conf".source = "${pkgs.aerothemeplasma-git}/misc/fontconfig/fonts.conf";
    ".local/share/smod".source = "${pkgs.aerothemeplasma-git}/plasma/smod";
    ".local/share/sddm/themes/sddm-theme-mod".source = "${pkgs.aerothemeplasma-git}/plasma/sddm/sddm-theme-mod";
  };
  programs.plasma = {
    enable = true;
    overrideConfig = customConfig.homeManager.themes.plasmaOverride;
    
    workspace = {
      colorScheme = "AeroColorScheme1";
      iconTheme = "Windows 7 Aero";
      soundTheme = "Windows 7";
      lookAndFeel = "authui7";
      wallpaper = customConfig.homeManager.themes.wallpaper;
      cursor = {
        theme = "aero-drop";
        size = 48;
      };
      windowDecorations = {
        library = "org.kde.kwin.aurorae";
        theme = "__aurorae__svg__smod";
      };
    };
    
    shortcuts.kwin = {
      "MinimizeAll" = "Meta+D";
      "Peek at Desktop" = [];
      "Walk Through Windows Alternative" = "Meta+Tab";
    };
    configFile = {
      "kwinrc"."TabBox" = {
        "LayoutName" = "thumbnail_seven";
        "ShowDesktopMode" = 1;
      };
      "kwinrc"."TabBoxAlternative" = {
        "LayoutName" = "flipswitch";
      };
      "kwinrc"."MouseBindings"."CommandWheel" = "Nothing";
      "kwinrc"."Plugins" = {
        "kwin4_effect_aeroglassblurEnabled" = lib.mkDefault true;
        "kwin4_effect_aeroglideEnabled" = lib.mkDefault true;
        "smodsnapEnabled" = lib.mkDefault true;
        "smodglowEnabled" = lib.mkDefault true;
        "startupfeedbackEnabled" = lib.mkDefault true;
        "desaturateUnresponsiveAppsEnabled" = lib.mkDefault true;
        "fadingPopupsEnabled" = lib.mkDefault true;
        "loginEnabled" = lib.mkDefault true;
        "squashEnabled" = lib.mkDefault true;
        "smodpeekeffectEnabled" = lib.mkDefault true;
        "dimScreenForAdminModeEnabled" = lib.mkDefault true;
        "minimizeallEnabled" = lib.mkDefault true;
        "dimscreenEnabled" = lib.mkDefault true;
        "backgroundcontrastEnabled" = lib.mkDefault false;
        "blurEnabled" = lib.mkDefault false;
        "maximizeEnabled" = lib.mkDefault false;
        "slidingpopupsEnabled" = lib.mkDefault false;
        "dialogparentEnabled" = lib.mkDefault false;
        "diminactiveEnabled" = lib.mkDefault false;
        "logoutEnabled" = lib.mkDefault false;
      };
      "kwinrc"."Scripts" = {
        "minimizeall" = true;
        "smodpeekscript" = true;
      };
      "ksmserverrc"."General"."confirmLogout" = false;
      "kcminputrc"."Mouse"."BusyCursor" = "none";
      "klaunchrc"."FeedbackStyle"."BusyCursor" = false;
      "kdeglobals"."General"."XftAntialias" = true;
      "kdeglobals"."General"."XftHintStyle" = "hintslight";
      "kdeglobals"."General"."XftSubPixel" = "rgb";
      "kdeglobals"."General" = {
        "font" = lib.mkDefault "Segoe UI,9,-1,5,50,0,0,0,0,0";
        "menuFont" = lib.mkDefault "Segoe UI,9,-1,5,50,0,0,0,0,0";
        "toolBarFont" = lib.mkDefault "Segoe UI,9,-1,5,50,0,0,0,0,0";
        "smallestReadableFont" = lib.mkDefault "Segoe UI,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
      };
      "kdeglobals"."General"."accentColorFromWallpaper" = false;
    };
  };

  # programs.bash = {
  #   enable = true;
  #   initExtra = ''
  #     PS1='C:''${PWD//\//\\\\}> '
  #     echo -e "Microsoft Windows [Version 6.1.7600]\nCopyright (c) 2009 Microsoft Corporation. All rights reserved.\n"
  #   '';
  # };
  }; # close config block
}