# ~/nixos-config/modules/home-manager/programs/browser/default.nix
{ config, lib, pkgs, customConfig, ... }:

# Declarative Firefox and LibreWolf, built from two independent preset layers:
#
#   privacy   LibreWolf-equivalent hardening (./privacy.nix)
#   personal  bookmarks, chrome theme, search, startup (./personal.nix)
#
# Either can be enabled without the other; enabling both merges them into one
# profile. Both browsers are driven by the same code because the two Home
# Manager modules are generated from the same upstream mkFirefoxModule.nix and
# expose identical option surfaces — do not fork this per browser.
#
# Why Firefox at all: nixpkgs regularly marks LibreWolf insecure, at which point
# Hydra stops building it and every host that has not pinned it to unstable
# source-builds a Firefox fork. That is what keeps stalling the weekly
# flake-update PRs. pkgs.firefox is always cached.

let
  cfg = customConfig.homeManager.browser;
  userName = customConfig.user.name;
  userHome = customConfig.user.home;

  privacyPreset = import ./privacy.nix { inherit lib; };
  personalPreset = import ./personal.nix { inherit lib; };
  bookmarksData = import ./bookmarks.nix { inherit lib; };

  chromeCss = theme:
    if theme == "none" then ""
    else import (./chrome + "/${theme}.nix") { inherit lib; };

  # Every pref contributed by the enabled layers, plus the host's escape hatch.
  presetSettings = bcfg:
    lib.optionalAttrs bcfg.privacy.enable
      (privacyPreset.alwaysSettings // privacyPreset.mkOptionalSettings bcfg.privacy)
    // lib.optionalAttrs bcfg.personal.enable
      (personalPreset.mkAppearanceSettings bcfg.personal)
    // lib.optionalAttrs (bcfg.personal.enable && bcfg.personal.startup.enable)
      (personalPreset.mkStartupSettings bcfg.personal)
    // bcfg.extraSettings;

  # Extensions are installed through the ExtensionSettings *policy* rather than
  # profiles.<p>.extensions.packages. Dropping an XPI into the profile's
  # extensions/ dir leaves it side-loaded: Firefox lists it but keeps it
  # disabled until the user clicks through an approval prompt, and it lands in
  # the puzzle-piece menu rather than the toolbar. The policy installs, enables
  # and places it in one go — the same mechanism LibreWolf uses to ship uBlock.
  #
  # installation_mode is "normal_installed", not "force_installed": the
  # extension arrives enabled but stays removable from about:addons. Forcing it
  # would make the button impossible to get rid of.
  #
  # install_url points at the XPI inside the Nix store, so nothing is fetched
  # from AMO at runtime and the version is pinned by the flake lock.
  #
  # pkgs.nur is referenced only from inside this let-body, which is itself only
  # forced from inside the mkIf below. Hosts that never load the NUR module (and
  # every host with the browser disabled) must not evaluate it.
  presetExtensions = bcfg:
    let
      addons = pkgs.nur.repos.rycee.firefox-addons;
      mozillaId = "{ec8030f7-c20a-464f-9b0e-13a3a9e97384}";
      entries =
        lib.optionals bcfg.privacy.enable privacyPreset.extensions
        ++ lib.optionals bcfg.personal.enable personalPreset.extensions;
      toPolicy = entry:
        let
          pkg = addons.${entry.name};
          id = pkg.addonId;
        in
        lib.nameValuePair id {
          installation_mode = "normal_installed";
          install_url = "file://${pkg}/share/mozilla/extensions/${mozillaId}/${id}.xpi";
          default_area = entry.area;
          private_browsing = true;
        };
    in
    lib.listToAttrs (map toPolicy entries);

  # Packages a host added by hand still go through the profile's extensions dir;
  # they carry no placement metadata for the policy to use.
  extraExtensionPackages = bcfg:
    lib.optionals bcfg.privacy.enable bcfg.privacy.extraExtensions
    ++ lib.optionals bcfg.personal.enable bcfg.personal.extraExtensions;
  # ── overrideConfig ────────────────────────────────────────────────────────
  # true  → prefs are written to the profile's user.js and re-enforced at every
  #         browser start. Changing one in the UI reverts on restart.
  # false → prefs are compiled into the package's autoconfig (mozilla.cfg) as
  #         defaultPref(), so they are *defaults*: a change made in the UI lands
  #         in prefs.js and survives.
  #
  # This is the same mechanism LibreWolf itself uses, and it replaces the old
  # librewolf.nix activation script, which wrote a second user.js into
  # ~/.librewolf/<userName> while the real profile was at <profilePath> — two
  # different directories, so the seeded file was never read.
  toDefaultPref = name: value: ''defaultPref("${name}", ${builtins.toJSON value});'';
  mkAutoconfig = settings:
    lib.concatStringsSep "\n" (lib.mapAttrsToList toDefaultPref settings);

  mkPackage = basePkg: bcfg:
    if bcfg.overrideConfig then basePkg
    else basePkg.override { extraPrefs = mkAutoconfig (presetSettings bcfg); };

  # ── Bookmarks that carry credentials ──────────────────────────────────────
  # Home Manager renders bookmarks.html into the Nix store, so the two tokened
  # URLs are kept as @PLACEHOLDER@ there and substituted into a file under $HOME
  # at activation. mkUserJs emits `extraConfig` *after* the settings block, so
  # repointing browser.bookmarks.file there wins over the store path HM wrote.
  bookmarksEnabled = bcfg: bcfg.personal.enable && bcfg.personal.bookmarks.enable;
  secretsEnabled = bcfg: bookmarksEnabled bcfg && bcfg.personal.bookmarks.secrets.enable;
  runtimeBookmarksFile = browser: "${userHome}/.local/share/nix-${browser}/bookmarks.html";

  mkSecretsActivation = browser: bcfg:
    let
      src = config.programs.${browser}.profiles.${userName}.bookmarks.configFile;
      dst = runtimeBookmarksFile browser;
      secretsDir = bcfg.personal.bookmarks.secrets.directory;
      substitutions = lib.mapAttrsToList (placeholder: secretName: ''
        if [ -r "${secretsDir}/${secretName}" ]; then
          $DRY_RUN_CMD ${pkgs.replace-secret}/bin/replace-secret \
            '${placeholder}' '${secretsDir}/${secretName}' "$tmp"
        else
          echo "browser: ${secretsDir}/${secretName} unreadable — leaving ${placeholder} in bookmarks" >&2
        fi
      '') bookmarksData.secretPlaceholders;
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Deliberately no `exit` anywhere below: a bare exit in an activation
      # snippet aborts the whole activate script and can leave the system
      # unbootable. A missing secret degrades to a bookmark with a placeholder
      # still in its URL, which is annoying but harmless.
      tmp="${dst}.new"
      $DRY_RUN_CMD mkdir -p "$(dirname "${dst}")"
      $DRY_RUN_CMD install -m 0600 "${src}" "$tmp"
      ${lib.concatStringsSep "\n" substitutions}
      $DRY_RUN_CMD mv -f "$tmp" "${dst}"
    '';

  # ── The profile itself ────────────────────────────────────────────────────
  mkProfile = browser: bcfg: {
    id = 0;
    isDefault = true;
    path = bcfg.profilePath;

    # Only user.js respects overrideConfig; see mkPackage above for the other
    # half. Extensions, userChrome, bookmarks, search and containers are always
    # managed declaratively.
    settings = lib.mkIf bcfg.overrideConfig (presetSettings bcfg);

    extraConfig = lib.optionalString (secretsEnabled bcfg) ''
      // Bookmarks carrying credentials are rendered outside the Nix store at
      // activation. This must come after the generated settings block.
      user_pref("browser.bookmarks.file", "${runtimeBookmarksFile browser}");
    '';

    userChrome = lib.optionalString bcfg.personal.enable (chromeCss bcfg.personal.chromeTheme);

    extensions.packages = extraExtensionPackages bcfg;

    bookmarks = lib.mkIf (bookmarksEnabled bcfg) {
      # HM refuses to manage bookmarks without this; Firefox rewrites
      # places.sqlite from the HTML on every launch.
      force = true;
      settings = [{
        name = "Bookmarks Toolbar";
        toolbar = true;
        bookmarks =
          lib.optionals bcfg.personal.bookmarks.sharedTree bookmarksData.tree
          ++ bcfg.personal.bookmarks.extra;
      }];
    };

    search = lib.mkIf (bcfg.personal.enable && bcfg.personal.search.enable) {
      force = true;
      default = bcfg.personal.search.default;
      privateDefault = bcfg.personal.search.default;
      order = [ bcfg.personal.search.default ];
      engines = personalPreset.engines;
    };

    containers = lib.mkIf (bcfg.personal.enable && bcfg.personal.containers.enable) personalPreset.containers;
    containersForce = bcfg.personal.enable && bcfg.personal.containers.enable;
  };

  mkBrowser = browser: basePkg: bcfg: {
    enable = true;
    package = mkPackage basePkg bcfg;

    policies =
      lib.optionalAttrs bcfg.privacy.enable privacyPreset.policies
      // lib.optionalAttrs (presetExtensions bcfg != { }) {
        ExtensionSettings = presetExtensions bcfg;
      };

    profiles.${userName} = mkProfile browser bcfg;
  };
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.firefox.enable {
      # HM 26.05 moves the profile root to $XDG_CONFIG_HOME/mozilla/firefox for
      # stateVersion >= 26.05 and warns until configPath is explicit. Migrating
      # would mean physically moving ~/.mozilla/firefox on every host (and it
      # does not move native messaging hosts), so stay on the legacy path
      # deliberately.
      programs.firefox = (mkBrowser "firefox" pkgs.firefox cfg.firefox) // {
        configPath = ".mozilla/firefox";
      };
      home.activation.firefoxBookmarkSecrets =
        lib.mkIf (secretsEnabled cfg.firefox) (mkSecretsActivation "firefox" cfg.firefox);
    })

    (lib.mkIf cfg.librewolf.enable {
      programs.librewolf = mkBrowser "librewolf" pkgs.librewolf cfg.librewolf;
      home.activation.librewolfBookmarkSecrets =
        lib.mkIf (secretsEnabled cfg.librewolf) (mkSecretsActivation "librewolf" cfg.librewolf);
    })
  ];
}
