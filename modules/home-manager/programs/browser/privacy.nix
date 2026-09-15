# ~/nixos-config/modules/home-manager/programs/browser/privacy.nix
{ lib }:

# The LibreWolf-equivalent hardening layer, as a pure data module.
#
# Where this comes from: LibreWolf's privacy behaviour does NOT live in its user
# prefs. It ships a 782-line `mozilla.cfg` (autoconfig, applied at every startup)
# plus a `distribution/policies.json` inside the package. Plain Firefox has
# neither, so everything LibreWolf-ish has to be restated here.
#
# Ported by category rather than 1:1. Deliberately NOT ported:
#   * every `librewolf.*` pref and `general.config.*` — no Firefox equivalent
#   * LibreWolf's branding/support URLs
#   * policies `EncryptedMediaExtensions.Enabled = false` (kills Widevine),
#     `HttpsOnlyMode = "enabled"` (breaks the plain-HTTP .lan homelab), and
#     `DisableAppUpdate`/`AppUpdateURL` (meaningless for a Nix-managed package)

{
  # Prefs applied whenever the privacy layer is on, regardless of options.
  alwaysSettings = {
    # ── Tracking protection ────────────────────────────────────────────────
    # Only the category is set. Firefox derives the whole strict preset from it
    # at startup (cookieBehavior = 5 / dFPI, cryptomining, fingerprinting,
    # email + social tracking, query stripping, bounce-tracking) and *overwrites*
    # the individual prefs to match. Restating them here would either be
    # redundant or, where a value differs, silently flip the category to
    # "custom" in the UI while Firefox still applies the strict value.
    "browser.contentblocking.category" = "strict";

    # ── Global Privacy Control ─────────────────────────────────────────────
    "privacy.globalprivacycontrol.enabled" = true;
    "privacy.globalprivacycontrol.pbmode.enabled" = true;
    "privacy.globalprivacycontrol.functionality.enabled" = true;

    # ── Telemetry and data reporting ───────────────────────────────────────
    "toolkit.telemetry.unified" = false;
    "toolkit.telemetry.enabled" = false;
    "toolkit.telemetry.server" = "data:,";
    "toolkit.telemetry.archive.enabled" = false;
    "toolkit.telemetry.newProfilePing.enabled" = false;
    "toolkit.telemetry.updatePing.enabled" = false;
    "toolkit.telemetry.firstShutdownPing.enabled" = false;
    "toolkit.telemetry.shutdownPingSender.enabled" = false;
    "toolkit.telemetry.bhrPing.enabled" = false;
    "toolkit.telemetry.cachedClientID" = "";
    "toolkit.telemetry.previousBuildID" = "";
    "toolkit.telemetry.server_owner" = "";
    "toolkit.coverage.opt-out" = true;
    "toolkit.coverage.enabled" = false;
    "toolkit.coverage.endpoint.base" = "";
    "datareporting.healthreport.uploadEnabled" = false;
    "datareporting.policy.dataSubmissionEnabled" = false;
    "datareporting.usage.uploadEnabled" = false;
    "datareporting.policy.dataSubmissionPolicyAcceptedVersion" = 999;
    "datareporting.policy.dataSubmissionPolicyBypassNotification" = true;
    "app.normandy.enabled" = false;
    "app.normandy.api_url" = "";
    "app.shield.optoutstudies.enabled" = false;
    "browser.discovery.enabled" = false;
    "dom.private-attribution.submission.enabled" = false;
    "nimbus.rollouts.enabled" = false;
    "termsofuse.bypassNotification" = true;

    # ── Crash reporting ────────────────────────────────────────────────────
    "browser.tabs.crashReporting.sendReport" = false;
    "breakpad.reportURL" = "";
    "browser.crashReports.onDemand" = false;
    "browser.crashReports.requestedNeverShowAgain" = true;

    # ── Sponsored content, promos and other annoyances ─────────────────────
    "browser.newtabpage.activity-stream.telemetry" = false;
    "browser.newtabpage.activity-stream.feeds.telemetry" = false;
    "browser.newtabpage.activity-stream.feeds.weatherfeed" = false;
    "browser.newtabpage.activity-stream.default.sites" = "";
    "browser.newtabpage.activity-stream.asrouter.providers.cfr" = "null";
    "browser.newtabpage.activity-stream.asrouter.providers.message-groups" = "null";
    "browser.newtabpage.activity-stream.asrouter.providers.messaging-experiments" = "null";
    "browser.newtabpage.activity-stream.asrouter.providers.onboarding" = "null";
    "browser.topsites.useRemoteSetting" = false;
    "browser.topsites.contile.enabled" = false;
    "browser.urlbar.quicksuggest.enabled" = false;
    "browser.urlbar.suggest.weather" = false;
    "browser.urlbar.addons.featureGate" = false;
    "browser.urlbar.trending.featureGate" = false;
    "browser.urlbar.weather.featureGate" = false;
    "browser.urlbar.yelp.featureGate" = false;
    "browser.urlbar.mdn.featureGate" = false;
    "browser.uitour.enabled" = false;
    "browser.uitour.url" = "";
    "browser.vpn_promo.enabled" = false;
    "browser.promo.focus.enabled" = false;
    "browser.contentblocking.report.hide_vpn_banner" = true;
    "browser.contentblocking.report.show_mobile_app" = false;
    "browser.contentblocking.report.lockwise.enabled" = false;
    "extensions.htmlaboutaddons.recommendations.enabled" = false;
    "extensions.getAddons.showPane" = false;
    "extensions.pocket.enabled" = false;
    "browser.startup.homepage_override.mstone" = "ignore";
    "startup.homepage_welcome_url" = "about:blank";
    "browser.aboutConfig.showWarning" = false;

    # ── Firefox AI features (LibreWolf disables these wholesale) ───────────
    "browser.ml.enable" = false;
    "browser.ml.chat.menu" = false;
    "browser.tabs.groups.smart.enabled" = false;
    "extensions.ui.mlmodel.hidden" = true;

    # ── Speculative connections and prefetching ────────────────────────────
    "network.prefetch-next" = false;
    "network.predictor.enabled" = false;
    "network.dns.disablePrefetch" = true;
    "network.dns.disablePrefetchFromHTTPS" = true;
    "network.http.speculative-parallel-limit" = 0;
    "network.early-hints.preconnect.max_connections" = 0;
    "browser.places.speculativeConnect.enabled" = false;
    "browser.urlbar.speculativeConnect.enabled" = false;

    # ── Referers ───────────────────────────────────────────────────────────
    "network.http.referer.XOriginTrimmingPolicy" = 2;
    "network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation" = true;

    # ── TLS / certificates ─────────────────────────────────────────────────
    "security.ssl.require_safe_negotiation" = true;
    "security.ssl.treat_unsafe_negotiation_as_broken" = true;
    "security.cert_pinning.enforcement_level" = 2;
    "security.pki.crlite_mode" = 2;
    "security.remote_settings.crlite_filters.enabled" = true;
    "security.tls.enable_0rtt_data" = false;
    "network.http.http3.enable_0rtt" = false;
    "security.tls.version.enable-deprecated" = false;
    "network.IDN_show_punycode" = true;
    "browser.xul.error_pages.expert_bad_cert" = true;

    # ── Geolocation ────────────────────────────────────────────────────────
    "geo.provider.use_geoclue" = false;
    "geo.provider.ms-windows-location" = false;
    "geo.provider.use_corelocation" = false;
    "browser.region.network.url" = "";
    "browser.region.update.enabled" = false;

    # ── Search suggestions (leak keystrokes to the engine) ─────────────────
    "browser.search.suggest.enabled" = false;
    "browser.urlbar.suggest.searches" = false;
    "browser.search.serpEventTelemetryCategorization.enabled" = false;
    "browser.search.separatePrivateDefault" = true;

    # ── Misc hardening ─────────────────────────────────────────────────────
    "browser.sessionstore.privacy_level" = 2;
    "network.captive-portal-service.enabled" = false;
    "network.connectivity-service.enabled" = false;
    "captivedetect.canonicalURL" = "";
    "pdfjs.enableScripting" = false;
    "dom.disable_window_move_resize" = true;
    "dom.webserial.enabled" = false;
    "permissions.delegation.enabled" = false;
    "network.file.disable_unc_paths" = true;
    "network.gio.supported-protocols" = "";
    "network.proxy.socks_remote_dns" = true;
    "media.peerconnection.ice.proxy_only_if_behind_proxy" = true;
    "browser.helperApps.deleteTempFileOnExit" = true;
    "browser.shell.shortcutFavicons" = false;
    "extensions.formautofill.creditCards.enabled" = false;
    "cookiebanners.service.mode" = 1;
    "cookiebanners.service.mode.privateBrowsing" = 1;
    "gecko.handlerService.defaultHandlersVersion" = 999;
    "default-browser-agent.enabled" = false;
  };

  # Prefs that depend on the per-host toggles. `cfg` is the privacy submodule.
  mkOptionalSettings = cfg:
    # Cookie/cache wipe on shutdown. LibreWolf does this; it is the single
    # biggest usability cost (logins and site state die with the browser), so it
    # defaults off here.
    #
    # Written as explicit booleans rather than omitted when false. Omitting
    # works on Firefox, whose stock default is already off — but LibreWolf's
    # mozilla.cfg turns sanitize-on-shutdown ON by default, so an omitted pref
    # would leave the option silently doing nothing there and cookies would
    # still die on every close.
    ({
      "privacy.sanitize.sanitizeOnShutdown" = cfg.sanitizeOnShutdown;
      "privacy.clearOnShutdown_v2.cookiesAndStorage" = cfg.sanitizeOnShutdown;
      "privacy.clearOnShutdown_v2.cache" = cfg.sanitizeOnShutdown;
      "privacy.clearOnShutdown_v2.historyFormDataAndDownloads" = false;
      "privacy.clearOnShutdown_v2.browsingHistoryAndDownloads" = false;
      "browser.cache.disk.enable" = !cfg.sanitizeOnShutdown;
    }
    // lib.optionalAttrs cfg.sanitizeOnShutdown {
      "privacy.sanitize.timeSpan" = 0;
    })

    # LibreWolf strips Safe Browsing entirely to avoid talking to Google. That
    # also removes malware and phishing protection, so it is opt-in here.
    // (lib.optionalAttrs cfg.disableSafeBrowsing {
      "browser.safebrowsing.malware.enabled" = false;
      "browser.safebrowsing.phishing.enabled" = false;
      "browser.safebrowsing.blockedURIs.enabled" = false;
      "browser.safebrowsing.downloads.enabled" = false;
      "browser.safebrowsing.downloads.remote.enabled" = false;
      "browser.safebrowsing.downloads.remote.block_potentially_unwanted" = false;
      "browser.safebrowsing.downloads.remote.block_uncommon" = false;
      "browser.safebrowsing.downloads.remote.url" = "";
      "browser.safebrowsing.provider.google4.gethashURL" = "";
      "browser.safebrowsing.provider.google4.updateURL" = "";
      "browser.safebrowsing.provider.google4.dataSharingURL" = "";
      "browser.safebrowsing.provider.google.gethashURL" = "";
      "browser.safebrowsing.provider.google.updateURL" = "";
    })

    # Downloads: prompt for a location every time (LibreWolf) vs a fixed dir.
    // (if cfg.promptDownloadDir then {
      "browser.download.useDownloadDir" = false;
      "browser.download.start_downloads_in_tmp_dir" = true;
    } else {
      "browser.download.useDownloadDir" = true;
      "browser.download.folderList" = 2;
      "browser.download.dir" = cfg.downloadDir;
    })

    # resistFingerprinting forces a light theme, a fixed window size and breaks
    # canvas/font rendering on many sites. LibreWolf enables it; this is the
    # relaxation that was already in the live user.js on gaming-pc.
    // {
      "privacy.resistFingerprinting" = cfg.resistFingerprinting;
      "privacy.fingerprintingProtection" = cfg.resistFingerprinting;
    }
    // (lib.optionalAttrs cfg.resistFingerprinting {
      "privacy.resistFingerprinting.block_mozAddonManager" = true;
      "privacy.resistFingerprinting.letterboxing" = false;
    })

    # The homelab (jellyfin.lan, radarr.lan, …) is plain HTTP.
    // {
      "dom.security.https_only_mode" = cfg.httpsOnlyMode;
      "dom.security.https_only_mode_ever_enabled" = cfg.httpsOnlyMode;
    }

    # trr.mode = 5 is "DoH explicitly off, use the system resolver". Required
    # for .lan: DoH bypasses the local Unbound resolver and .lan stops resolving.
    // (lib.optionalAttrs cfg.useSystemDNS {
      "network.trr.mode" = 5;
      "doh-rollout.enabled" = false;
    })

    // {
      "signon.rememberSignons" = cfg.rememberPasswords;
      "signon.autofillForms" = cfg.rememberPasswords;
      "browser.formfill.enable" = cfg.rememberPasswords;
    }

    # Widevine.
    // {
      "media.eme.enabled" = cfg.enableDRM;
      "browser.eme.ui.enabled" = cfg.enableDRM;
      "media.gmp-widevinecdm.enabled" = cfg.enableDRM;
      "media.gmp-widevinecdm.visible" = cfg.enableDRM;
    }
    // (lib.optionalAttrs cfg.enableDRM {
      # media.eme.enabled on its own is not enough on LibreWolf: it also blanks
      # the GMP manager URL and disables the provider, so the Widevine CDM can
      # never download and DRM playback fails with EME apparently "on". These
      # three are Firefox's stock values, so writing them is a no-op there and
      # an unblock on LibreWolf.
      "media.gmp-provider.enabled" = true;
      "media.eme.require-app-approval" = false;
      "media.gmp-manager.url" =
        "https://aus5.mozilla.org/update/3/GMP/%VERSION%/%BUILD_ID%/%BUILD_TARGET%"
        + "/%LOCALE%/%CHANNEL%/%OS_VERSION%/%DISTRIBUTION%/%DISTRIBUTION_VERSION%/update.xml";
    })
    # WebGL is needed by streaming sites and web apps; LibreWolf leaves it on
    # but blocks WebGPU.
    // {
      "webgl.disabled" = false;
      "dom.webgpu.enabled" = false;
    }

    # Autoplay: LibreWolf blocks everything (media.autoplay.default = 5).
    // {
      "media.autoplay.default" = if cfg.allowAutoplay then 0 else 5;
      "media.autoplay.blocking_policy" = if cfg.allowAutoplay then 0 else 2;
    };

  # Straight from LibreWolf's distribution/policies.json, minus the three
  # entries called out in the header comment.
  policies = {
    DisableTelemetry = true;
    DisableFirefoxStudies = true;
    DisablePocket = true;
    DisableFeedbackCommands = true;
    DisableDefaultBrowserAgent = true;
    DontCheckDefaultBrowser = true;
    SkipTermsOfUse = true;
    OverridePostUpdatePage = "";
    FirefoxHome = {
      Weather = false;
      TopSites = false;
      SponsoredTopSites = false;
      Highlights = false;
      Stories = false;
      SponsoredStories = false;
    };
    FirefoxSuggest = {
      WebSuggestions = false;
      SponsoredSuggestions = false;
      ImproveSuggest = false;
    };
    UserMessaging = {
      UrlbarInterventions = false;
      SkipOnboarding = true;
      MoreFromMozilla = false;
      FirefoxLabs = false;
    };
  };

  # Attribute names in pkgs.nur.repos.rycee.firefox-addons. Resolved by
  # default.nix inside its mkIf so pkgs.nur is never forced on a host that has
  # not loaded the NUR module.
  extensionNames = [
    "ublock-origin"
    "facebook-container"
    "clearurls"
  ];
}
