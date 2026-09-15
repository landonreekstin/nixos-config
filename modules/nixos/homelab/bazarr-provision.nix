# ~/nixos-config/modules/nixos/homelab/bazarr-provision.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.arr.bazarr.provision;

  bazarrUrl = "http://127.0.0.1:6767";
  configYaml = "/var/lib/bazarr/config/config.yaml";
  stampFile = "/var/lib/bazarr/.nix-provisioned";

  # Language profile lives in Bazarr's SQLite DB, not config.yaml. It is written
  # through POST /api/system/settings, which upserts on profileId - so re-running
  # this is a no-op rather than a duplicate. Item shape and the "cutoff names an
  # item id" semantics come from bazarr's app/database.py.
  #
  # Two items, both English: the normal track is the cutoff, so a hearing-impaired
  # sub satisfies the "has subtitles" requirement immediately while Bazarr keeps
  # looking for a normal one to upgrade to.
  languageProfiles = builtins.toJSON [{
    profileId = 1;
    name = "English";
    cutoff = 1;
    originalFormat = false;
    mustContain = [];
    mustNotContain = [];
    items = [
      { id = 1; language = "en"; audio_exclude = "False"; audio_only_include = "False"; hi = "False"; forced = "False"; }
      { id = 2; language = "en"; audio_exclude = "False"; audio_only_include = "False"; hi = "True";  forced = "False"; }
    ];
  }];

  provisionScript = pkgs.writeShellScript "bazarr-provision" ''
    set -euo pipefail

    curl=${pkgs.curl}/bin/curl
    jq=${lib.getExe pkgs.jq}
    yq=${pkgs.yq-go}/bin/yq

    BAZARR="${bazarrUrl}"
    CONFIG="${configYaml}"
    STAMP="${stampFile}"

    log() { echo "[bazarr-provision] $*" >&2; }

    # ---------------------------------------------------------------
    # Step 1: wait for Bazarr's API (ping is unauthenticated)
    # ---------------------------------------------------------------
    for _ in $(seq 1 60); do
      if $curl -sf "$BAZARR/api/system/ping" >/dev/null 2>&1; then break; fi
      sleep 2
    done
    if ! $curl -sf "$BAZARR/api/system/ping" >/dev/null 2>&1; then
      log "ERROR: Bazarr did not become reachable at $BAZARR"
      exit 1
    fi

    KEY=$($yq -r '.auth.apikey' "$CONFIG")
    if [ -z "$KEY" ] || [ "$KEY" = "null" ]; then
      log "ERROR: could not read auth.apikey from $CONFIG"
      exit 1
    fi

    # curl -f collapses every HTTP error into exit 22, which tells you nothing.
    # Capture the body and print it so a rejected payload is debuggable from the
    # journal alone.
    api() {
      local body code
      body=$($curl -s -w '\n%{http_code}' -H "X-API-KEY: $KEY" "$@") || return 1
      code=''${body##*$'\n'}
      body=''${body%$'\n'*}
      if [ "$code" -ge 400 ]; then
        log "ERROR: HTTP $code from Bazarr; args: $*"
        log "ERROR: response: $body"
        return 1
      fi
      printf '%s' "$body"
    }

    # ---------------------------------------------------------------
    # Step 2: build the settings payload
    # ---------------------------------------------------------------
    args=()

    # The bug this whole module exists to fix: config.yaml shipped with ssl=true
    # for both *arrs while radarr/sonarr serve plain HTTP, so Bazarr could never
    # reach either and its library stayed empty.
    args+=(-d settings-radarr-ssl=false -d settings-radarr-ip=127.0.0.1 -d settings-radarr-port=7878)
    args+=(-d settings-sonarr-ssl=false -d settings-sonarr-ip=127.0.0.1 -d settings-sonarr-port=8989)

    PROVIDERS="${lib.concatStringsSep " " cfg.providers}"
    if [ -n "''${OPENSUBTITLES_USERNAME:-}" ] && [ -n "''${OPENSUBTITLES_PASSWORD:-}" ]; then
      PROVIDERS="opensubtitlescom $PROVIDERS"
      args+=(-d "settings-opensubtitlescom-username=$OPENSUBTITLES_USERNAME")
      args+=(-d "settings-opensubtitlescom-password=$OPENSUBTITLES_PASSWORD")
      args+=(-d settings-opensubtitlescom-use_hash=true)
      args+=(-d settings-opensubtitlescom-include_ai_translated=false)
      args+=(-d settings-opensubtitlescom-include_machine_translated=false)
    else
      log "No OpenSubtitles credentials supplied; enabling no-auth providers only."
    fi
    for p in $PROVIDERS; do
      args+=(-d "settings-general-enabled_providers=$p")
    done

    # English only, and the profile above.
    args+=(-d languages-enabled=en)
    args+=(-d 'languages-profiles=${languageProfiles}')

    # Stamp every newly-synced movie/series with profile 1 so future downloads are
    # covered without any manual step.
    args+=(-d settings-general-movie_default_enabled=true -d settings-general-movie_default_profile=1)
    args+=(-d settings-general-serie_default_enabled=true -d settings-general-serie_default_profile=1)

    # Count embedded English tracks as satisfying the profile, and keep upgrading
    # HI subs towards a normal one.
    args+=(-d settings-general-use_embedded_subs=true)
    args+=(-d settings-general-upgrade_subs=true)

    # ---------------------------------------------------------------
    # Step 3: apply. Idempotent - the profile upserts and save_settings only
    # touches the keys we send.
    # ---------------------------------------------------------------
    log "Applying settings to Bazarr..."
    api -X POST "''${args[@]}" "$BAZARR/api/system/settings" >/dev/null

    # Hash the payload (minus secrets) to decide whether this run changed anything.
    new_stamp=$(printf '%s\n' "''${args[@]}" \
      | grep -v -e OPENSUBTITLES_ -e opensubtitlescom-password -e opensubtitlescom-username \
      | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)
    old_stamp=$(cat "$STAMP" 2>/dev/null || echo "")

    # ---------------------------------------------------------------
    # Step 4: pull the library in from Radarr/Sonarr
    # ---------------------------------------------------------------
    log "Triggering Radarr/Sonarr sync..."
    api -X POST -d taskid=update_movies "$BAZARR/api/system/tasks" >/dev/null || true
    api -X POST -d taskid=update_series "$BAZARR/api/system/tasks" >/dev/null || true
    sleep 30

    ${lib.optionalString cfg.backfill ''
    # ---------------------------------------------------------------
    # Step 5: backfill anything left without a profile.
    #
    # Bazarr applies movie_default_profile only on insert, so the first sync after
    # the ssl fix already enrols the whole existing library. This pass catches
    # items that predate the default (and makes re-runs self-healing).
    # ---------------------------------------------------------------
    backfill() { # <endpoint> <id-field> <id-json-key>
      local endpoint="$1" idfield="$2" idkey="$3"
      local ids
      ids=$(api "$BAZARR/api/$endpoint?length=-1" \
        | $jq -r --arg k "$idkey" '[.data[] | select(.profileId == null) | .[$k]] | .[]')
      [ -z "$ids" ] && return 0
      local n=0 bargs=()
      for id in $ids; do
        bargs+=(-d "$idfield=$id" -d profileid=1)
        n=$((n + 1))
      done
      log "Backfilling profile 1 onto $n $endpoint without one..."
      api -X POST "''${bargs[@]}" "$BAZARR/api/$endpoint" >/dev/null
    }
    backfill movies radarrid radarrId
    backfill series seriesid sonarrSeriesId
    ''}

    # ---------------------------------------------------------------
    # Step 6: kick off the search, but only when something actually changed.
    # Bazarr re-runs this on its own schedule (wanted_search_frequency), so
    # skipping it on an unchanged rebuild costs nothing.
    # ---------------------------------------------------------------
    if [ "$new_stamp" != "$old_stamp" ]; then
      log "Settings changed - searching for missing subtitles."
      api -X POST -d taskid=wanted_search_missing_subtitles_movies "$BAZARR/api/system/tasks" >/dev/null || true
      api -X POST -d taskid=wanted_search_missing_subtitles_series "$BAZARR/api/system/tasks" >/dev/null || true
      printf '%s' "$new_stamp" > "$STAMP"
    else
      log "Settings unchanged - leaving the search schedule alone."
    fi

    log "Done."
  '';
in
{
  options.customConfig.homelab.arr.bazarr.provision = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Declaratively provision Bazarr's settings and English language profile
        over its REST API on every boot and rebuild. Bazarr rewrites both
        config.yaml and its SQLite database at runtime, so its state cannot be
        managed as a Nix-generated file; a converging oneshot is the closest
        equivalent.
      '';
    };

    credentialsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/opensubtitles-credentials";
      description = ''
        Environment file defining OPENSUBTITLES_USERNAME and
        OPENSUBTITLES_PASSWORD. When null, only the providers that need no
        account are enabled, which noticeably reduces the hit rate.
      '';
    };

    providers = mkOption {
      type = types.listOf types.str;
      default = [ "tvsubtitles" "yifysubtitles" ];
      description = ''
        Subtitle providers that require no credentials. opensubtitlescom is
        added automatically when credentialsFile is set.
      '';
    };

    backfill = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Assign the English profile to any movie or series Bazarr already knows
        about that has no profile yet.
      '';
    };
  };

  config = lib.mkIf (config.customConfig.homelab.arr.bazarr.enable && cfg.enable) {

    systemd.services.bazarr-provision = {
      description = "Provision Bazarr settings and English subtitle profile";
      after = [ "network-online.target" "bazarr.service" "radarr.service" "sonarr.service" ];
      wants = [ "network-online.target" ];
      requires = [ "bazarr.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = provisionScript;
      } // lib.optionalAttrs (cfg.credentialsFile != null) {
        EnvironmentFile = cfg.credentialsFile;
      };
    };

  };
}
