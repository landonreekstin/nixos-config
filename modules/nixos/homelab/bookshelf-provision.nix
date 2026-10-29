# ~/nixos-config/modules/nixos/homelab/bookshelf-provision.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.bookshelf.provision;
  bookshelfCfg = config.customConfig.homelab.bookshelf;
  rgCfg = config.customConfig.homelab.rreadingGlasses;

  bookshelfUrl = "http://127.0.0.1:8787";
  configXml = "/var/lib/bookshelf/config.xml";

  # Same shape as lidarr-provision.nix; Bookshelf speaks Readarr's /api/v1.
  provisionScript = pkgs.writeShellScript "bookshelf-provision" ''
    set -euo pipefail

    curl=${pkgs.curl}/bin/curl
    jq=${lib.getExe pkgs.jq}
    sed=${pkgs.gnused}/bin/sed

    BOOKSHELF="${bookshelfUrl}"
    CONFIG="${configXml}"
    ROOT="${bookshelfCfg.libraryPath}"
    DLNAME="${cfg.downloadClientName}"
    CATEGORY="${cfg.downloadCategory}"
    PROFILE="${cfg.qualityProfile}"
    METADATA="http://127.0.0.1:${toString rgCfg.port}"

    log() { echo "[bookshelf-provision] $*" >&2; }

    # ---------------------------------------------------------------
    # Step 1: wait for Bookshelf. A container's first start is slow (the
    # linuxserver init chowns /config, then the app migrates its DB), and the
    # API key only appears in config.xml once that bootstrap is done.
    # ---------------------------------------------------------------
    for _ in $(seq 1 90); do
      if $curl -sf "$BOOKSHELF/ping" >/dev/null 2>&1; then break; fi
      sleep 2
    done
    if ! $curl -sf "$BOOKSHELF/ping" >/dev/null 2>&1; then
      log "ERROR: Bookshelf did not become reachable at $BOOKSHELF"
      exit 1
    fi

    KEY=$($sed -n 's:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p' "$CONFIG")
    if [ -z "$KEY" ]; then
      log "ERROR: could not read <ApiKey> from $CONFIG"
      exit 1
    fi

    # Same helper as lidarr-provision.nix: surface the response body on errors.
    api() {
      local body code
      body=$($curl -s -w '\n%{http_code}' \
        -H "X-Api-Key: $KEY" -H "Content-Type: application/json" "$@") || return 1
      code=''${body##*$'\n'}
      body=''${body%$'\n'*}
      if [ "$code" -ge 400 ]; then
        log "ERROR: HTTP $code from Bookshelf; args: $*"
        log "ERROR: response: $body"
        return 1
      fi
      printf '%s' "$body"
    }

    # ---------------------------------------------------------------
    # Step 2: root folder. Converges structurally like Lidarr's: read, then
    # POST only what is missing.
    # ---------------------------------------------------------------
    if api "$BOOKSHELF/api/v1/rootfolder" \
         | $jq -e --arg p "$ROOT" 'any(.[]; .path == $p)' >/dev/null; then
      log "Root folder $ROOT already present."
    else
      # Readarr-family apps seed an "eBook" and a "Spoken" quality profile.
      # Books added under this root default to the audiobook one; fall back to
      # the first profile if it was renamed.
      QP=$(api "$BOOKSHELF/api/v1/qualityprofile" \
        | $jq -r --arg n "$PROFILE" '(map(select(.name == $n)) + .)[0].id')
      MP=$(api "$BOOKSHELF/api/v1/metadataprofile" | $jq -r '.[0].id // 1')
      log "Adding root folder $ROOT (qualityProfile=$QP metadataProfile=$MP)..."
      api -X POST -d "$($jq -n \
          --arg p "$ROOT" --argjson qp "$QP" --argjson mp "$MP" \
          '{ name: "Audiobooks", path: $p,
             defaultQualityProfileId: $qp, defaultMetadataProfileId: $mp,
             defaultMonitorOption: "all", defaultNewItemMonitorOption: "all",
             defaultTags: [], isCalibreLibrary: false }')" \
        "$BOOKSHELF/api/v1/rootfolder" >/dev/null
    fi

    # ---------------------------------------------------------------
    # Step 3: Transmission download client, built from the schema so a field
    # rename in an upgrade cannot leave it half-configured. The category field
    # really is called musicCategory: Readarr was forked from Lidarr and never
    # renamed it.
    # ---------------------------------------------------------------
    if api "$BOOKSHELF/api/v1/downloadclient" \
         | $jq -e --arg n "$DLNAME" 'any(.[]; .name == $n)' >/dev/null; then
      log "Download client $DLNAME already present."
    else
      log "Adding Transmission download client $DLNAME (category $CATEGORY)..."
      payload=$(api "$BOOKSHELF/api/v1/downloadclient/schema" | $jq \
        --arg n "$DLNAME" --arg cat "$CATEGORY" '
          (.[] | select(.implementation == "Transmission"))
          | .name = $n
          | .enable = true
          | .priority = 1
          | .fields = (.fields | map(
              if   .name == "host"          then .value = "127.0.0.1"
              elif .name == "port"          then .value = 9091
              elif .name == "useSsl"        then .value = false
              elif .name == "musicCategory" then .value = $cat
              else . end))')
      api -X POST -d "$payload" "$BOOKSHELF/api/v1/downloadclient" >/dev/null
    fi

    ${lib.optionalString rgCfg.enable ''
    # ---------------------------------------------------------------
    # Step 4: metadata source. The image ships pointed at the shared
    # hardcover.bookinfo.pro, which times out on every search under load;
    # rreading-glasses.nix runs a private copy. This setting is otherwise only
    # reachable at /settings/development, a page the UI does not link to.
    # ---------------------------------------------------------------
    dev=$(api "$BOOKSHELF/api/v1/config/development")
    if [ "$($jq -r '.metadataSource' <<<"$dev")" = "$METADATA" ]; then
      log "Metadata source already $METADATA."
    else
      log "Pointing metadata source at $METADATA..."
      api -X PUT -d "$($jq --arg m "$METADATA" '.metadataSource = $m' <<<"$dev")" \
        "$BOOKSHELF/api/v1/config/development" >/dev/null
    fi
    ''}

    log "Done."
  '';
in
{
  options.customConfig.homelab.bookshelf.provision = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Declaratively converge Bookshelf's audiobook root folder, Transmission
        download client and (with rreadingGlasses enabled) metadata source over
        its REST API on every boot and rebuild, the same way
        lidarr-provision.nix does for Lidarr.
      '';
    };

    qualityProfile = mkOption {
      type = types.str;
      default = "Spoken";
      description = "Quality profile new books under the root folder default to. Spoken is the seeded audiobook profile.";
    };

    downloadClientName = mkOption {
      type = types.str;
      default = "Transmission";
      description = "Name of the Transmission client as it appears in Bookshelf. Also the key this module converges on.";
    };

    downloadCategory = mkOption {
      type = types.str;
      default = "bookshelf";
      description = ''
        Transmission category for audiobook grabs, filed under
        <download-dir>/<category>/ like lidarr/ and gamarr/.
      '';
    };
  };

  config = lib.mkIf (bookshelfCfg.enable && cfg.enable) {

    systemd.services.bookshelf-provision = {
      description = "Provision Bookshelf root folder and download client";
      after = [ "network-online.target" "docker-bookshelf.service" "transmission.service" ];
      wants = [ "network-online.target" ];
      requires = [ "docker-bookshelf.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = provisionScript;
      };
    };

  };
}
