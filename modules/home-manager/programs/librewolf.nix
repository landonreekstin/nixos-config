# ~/nixos-config/modules/home-manager/programs/librewolf.nix
{ config, lib, pkgs, customConfig, ... }:

let
  cfg      = customConfig.homeManager.librewolf;
  userName = customConfig.user.name;
  userHome = customConfig.user.home;

  # Defined outside mkIf — no pkgs.nur reference here
  userJsSettings = {
    # DRM / Widevine
    "media.eme.enabled"                                    = true;
    "browser.eme.ui.enabled"                               = true;
    # Disable resistFingerprinting for usability (dark mode, canvas, fonts)
    "privacy.resistFingerprinting"                         = false;
    "privacy.fingerprintingProtection"                     = false;
    # Cookies: block third-party trackers, allow first-party
    "network.cookie.cookieBehavior"                        = 1;
    # Password saving
    "signon.rememberSignons"                               = true;
    "signon.generation.enabled"                            = true;
    # WebGL (web apps, streaming)
    "webgl.disabled"                                       = false;
    # Session restore on startup
    "browser.startup.page"                                 = 3;
    # Autoplay (streaming sites)
    "media.autoplay.default"                               = 0;
    "media.autoplay.blocking_policy"                       = 0;
    # Signal dark mode preference to websites
    "ui.systemUsesDarkTheme"                               = 1;
    # Enable userChrome.css
    "toolkit.legacyUserProfileCustomizations.stylesheets"  = true;
    # Downloads
    "browser.download.dir"                                 = "${userHome}/Downloads";
    "browser.download.folderList"                          = 2;
    # Tracking protection (standard, not strict — allows usable cookie behavior)
    "browser.contentblocking.category"                     = "standard";
    "privacy.trackingprotection.enabled"                   = true;
  };

  userChromeCSS = ''
    /* Managed by NixOS Home Manager — dark Librewolf chrome (Catppuccin Mocha) */
    :root {
      --toolbar-bgcolor: #1e1e2e !important;
      --toolbar-color:   #cdd6f4 !important;
    }
    #nav-bar,
    #toolbar-menubar,
    #TabsToolbar,
    #PersonalToolbar {
      background-color: #1e1e2e !important;
      color:            #cdd6f4 !important;
      border-color:     #45475a !important;
    }
    #urlbar,
    .urlbar-input-container {
      background-color: #181825 !important;
      color:            #cdd6f4 !important;
    }
    .tab-background[selected="true"] {
      background-color: #313244 !important;
    }
    .tab-label {
      color: #cdd6f4 !important;
    }
  '';

  bookmarkList = [
    { name = "YouTube";    url = "https://www.youtube.com"; }
    { name = "TV"; bookmarks = [
        { name = "Netflix";  url = "https://www.netflix.com"; }
        { name = "Jellyfin"; url = "http://192.168.1.76:8096"; }
        { name = "Requests"; url = "http://192.168.1.76:5055"; }
        { name = "Torrent";  url = "http://192.168.1.76:9091"; }
      ]; }
    { name = "Sports"; bookmarks = [
        { name = "StreamEast"; url = "https://the.streameast.xyz/"; }
        { name = "NFLBite";    url = "https://www.nflbite.is/"; }
        { name = "Sportsurge"; url = "https://v2.sportsurge.net/home5/"; }
        { name = "OnHockey";   url = "https://onhockey.tv/"; }
      ]; }
    { name = "Dev"; bookmarks = [
        { name = "GitHub";     url = "https://github.com/"; }
        { name = "NixOS Opts"; url = "https://search.nixos.org/options"; }
        { name = "HM Opts";    url = "https://home-manager.dev/manual/23.11/options.xhtml"; }
      ]; }
    { name = "Google"; bookmarks = [
        { name = "Drive"; url = "https://drive.google.com/drive/?dmr=1&ec=wgc-drive-hero-goto"; }
        { name = "Gmail"; url = "https://mail.google.com/mail/u/0/#inbox"; }
        { name = "Maps";  url = "https://www.google.com/maps"; }
      ]; }
    { name = "Gaming"; bookmarks = [
        { name = "ProtonDB"; url = "https://www.protondb.com/"; }
        { name = "Vimm";     url = "https://vimm.net/"; }
      ]; }
    { name = "Prime";      url = "https://www.amazon.com/amazonprime"; }
    { name = "LinkedIn";   url = "https://www.linkedin.com/feed/"; }
    { name = "HomeAssist"; url = "http://192.168.100.103:8123/home/overview"; }
    { name = "Claude";     url = "https://claude.ai/new"; }
  ];

in
{
  config = lib.mkIf cfg.enable (
    let
      # pkgs.nur reference scoped here — only evaluated when enable = true.
      # Hosts without NUR loaded (blaney-pc, etc.) are never affected since
      # customConfig.homeManager.librewolf.enable defaults to false.
      extensions = with pkgs.nur.repos.rycee.firefox-addons; [
        ublock-origin
        darkreader
        facebook-container
        # teleparty is not confirmed in NUR rycee addons.
        # To add manually once sha256 is known:
        # (pkgs.fetchFirefoxAddon {
        #   name = "teleparty";
        #   url = "https://addons.mozilla.org/firefox/downloads/latest/netflix-party2/";
        #   sha256 = "sha256-REPLACE_ME";
        # })
      ];
    in {
      programs.librewolf = {
        enable = true;

        profiles.${userName} = {
          extensions = { packages = extensions; };

          userChrome = userChromeCSS;

          # Settings written as user.js only when overrideConfig = true.
          # When false, the activation script below handles a one-time write.
          settings = lib.mkIf cfg.overrideConfig userJsSettings;

          bookmarks = {
            # force = true resets bookmarks to this list on every rebuild.
            # force = false only writes them if the bookmarks file is absent.
            force = cfg.overrideConfig;
            settings = [
              {
                name = "Bookmarks Toolbar";
                toolbar = true;
                bookmarks = bookmarkList;
              }
            ];
          };
        };
      };

      # When overrideConfig = false: write user.js once if not present so the
      # user can make persistent edits that survive rebuilds.
      home.activation.librewolfUserJs = lib.mkIf (!cfg.overrideConfig)
        (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          lw_dir="${userHome}/.librewolf/${userName}"
          lw_js="$lw_dir/user.js"
          if [ ! -f "$lw_js" ]; then
            mkdir -p "$lw_dir"
            cat > "$lw_js" << 'USERJS'
          // Written once by NixOS activation — edit freely, will not be overwritten on rebuild.
          user_pref("media.eme.enabled", true);
          user_pref("browser.eme.ui.enabled", true);
          user_pref("privacy.resistFingerprinting", false);
          user_pref("privacy.fingerprintingProtection", false);
          user_pref("network.cookie.cookieBehavior", 1);
          user_pref("signon.rememberSignons", true);
          user_pref("signon.generation.enabled", true);
          user_pref("webgl.disabled", false);
          user_pref("browser.startup.page", 3);
          user_pref("media.autoplay.default", 0);
          user_pref("media.autoplay.blocking_policy", 0);
          user_pref("ui.systemUsesDarkTheme", 1);
          user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
          user_pref("browser.download.folderList", 2);
          user_pref("browser.contentblocking.category", "standard");
          user_pref("privacy.trackingprotection.enabled", true);
          USERJS
            echo "librewolf: wrote initial user.js to $lw_js"
          else
            echo "librewolf: user.js already exists, skipping (overrideConfig=false)"
          fi
        '');
    }
  );
}
