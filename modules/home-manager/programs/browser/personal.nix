# ~/nixos-config/modules/home-manager/programs/browser/personal.nix
{ lib }:

# The personal layer: appearance, startup behaviour, search and containers.
#
# Deliberately independent of ./privacy.nix — either can be enabled without the
# other, and enabling both just merges the two pref sets into one profile.

{
  # Appearance and chrome visibility. Applied whenever the personal layer is on,
  # independent of `startup.enable` — toolkit.legacyUserProfileCustomizations
  # gates userChrome.css, so tying it to startup would silently disable the
  # chrome theme.
  mkAppearanceSettings = cfg: {
    # Tell pages we prefer dark, and force the chrome itself dark. Without
    # prefers-color-scheme.content-override, sites follow the system and a
    # light GTK theme drags them back to white.
    "ui.systemUsesDarkTheme" = 1;
    "browser.theme.toolbar-theme" = 0;
    "browser.theme.content-theme" = 0;
    "layout.css.prefers-color-scheme.content-override" = 0;

    # Required for userChrome.css / userContent.css to be read at all.
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

    "browser.toolbars.bookmarks.visibility" = cfg.bookmarks.toolbarVisibility;
    "browser.bookmarks.restore_default_bookmarks" = false;
    "findbar.highlightAll" = true;
    "sidebar.visibility" = "hide-sidebar";
  };

  # Startup and new-tab behaviour, gated on personal.startup.enable.
  mkStartupSettings = cfg: {
    # 3 = restore the previous session. 1 = homepage, 0 = blank.
    "browser.startup.page" = if cfg.startup.restoreSession then 3 else 1;
    "browser.startup.homepage" = cfg.startup.homepage;
    "browser.newtabpage.enabled" = cfg.startup.newTabPage != "blank";
    "browser.newtabpage.activity-stream.showSearch" = cfg.startup.newTabPage == "firefox-home";
    "browser.newtabpage.activity-stream.feeds.topsites" = false;
  };

  # Search engines. HM keys `default` by engine *name*, and requires
  # `search.force` because Firefox rewrites search.json.mozlz4 on every launch.
  #
  # "DuckDuckGo No-AI" reproduces the hand-made engine in the live LibreWolf
  # profile: noai.duckduckgo.com strips the AI answer block from results.
  engines = {
    "DuckDuckGo No-AI" = {
      urls = [{
        template = "https://noai.duckduckgo.com/";
        params = [{ name = "q"; value = "{searchTerms}"; }];
      }];
      iconMapObj."16" = "https://duckduckgo.com/favicon.ico";
      definedAliases = [ "@ddg" "@dd" ];
    };

    "Nix Packages" = {
      urls = [{
        template = "https://search.nixos.org/packages";
        params = [
          { name = "type"; value = "packages"; }
          { name = "query"; value = "{searchTerms}"; }
        ];
      }];
      iconMapObj."16" = "https://search.nixos.org/favicon.png";
      definedAliases = [ "@np" ];
    };

    "NixOS Options" = {
      urls = [{
        template = "https://search.nixos.org/options";
        params = [
          { name = "type"; value = "options"; }
          { name = "query"; value = "{searchTerms}"; }
        ];
      }];
      iconMapObj."16" = "https://search.nixos.org/favicon.png";
      definedAliases = [ "@no" ];
    };

    "Home Manager Options" = {
      urls = [{
        template = "https://home-manager-options.extranix.com/";
        params = [
          { name = "query"; value = "{searchTerms}"; }
          { name = "release"; value = "master"; }
        ];
      }];
      definedAliases = [ "@hm" ];
    };

    "GitHub" = {
      urls = [{
        template = "https://github.com/search";
        params = [{ name = "q"; value = "{searchTerms}"; }];
      }];
      iconMapObj."16" = "https://github.com/favicon.ico";
      definedAliases = [ "@gh" ];
    };

    # Built-in engines that only carry metaData are treated as Firefox builtins.
    "google".metaData.hidden = true;
    "bing".metaData.hidden = true;
    "amazondotcom-us".metaData.hidden = true;
    "ebay".metaData.hidden = true;
  };

  # The one user-created container in the live profile. Facebook Container
  # (the extension) writes privacy.userContext.extension and expects this to
  # exist; without it the extension creates its own on first run and the id
  # drifts between machines.
  containers = {
    # The live profile shows color "gray"; Firefox's own palette calls that
    # shade "toolbar", which is the name Home Manager's enum accepts.
    "Facebook" = { id = 6; icon = "fence"; color = "toolbar"; };
  };

  extensionNames = [
    "darkreader"
    "bitwarden"
  ];
}
