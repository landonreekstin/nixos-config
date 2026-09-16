# ~/nixos-config/modules/nixos/homelab/lidarr-provision.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.arr.lidarr.provision;
  mediaCfg = config.customConfig.homelab.mediaSetup;

  lidarrUrl = "http://127.0.0.1:8686";
  configXml = "/var/lib/lidarr/.config/Lidarr/config.xml";

  provisionScript = pkgs.writeShellScript "lidarr-provision" ''
    set -euo pipefail

    curl=${pkgs.curl}/bin/curl
    jq=${lib.getExe pkgs.jq}
    sed=${pkgs.gnused}/bin/sed

    LIDARR="${lidarrUrl}"
    CONFIG="${configXml}"
    ROOT="${cfg.rootFolder}"
    DLNAME="${cfg.downloadClientName}"
    CATEGORY="${cfg.downloadCategory}"

    log() { echo "[lidarr-provision] $*" >&2; }

    # ---------------------------------------------------------------
    # Step 1: wait for Lidarr. /ping is unauthenticated on every servarr app,
    # which matters because the API key we need is only written to config.xml
    # once Lidarr has finished its first-run bootstrap.
    # ---------------------------------------------------------------
    for _ in $(seq 1 60); do
      if $curl -sf "$LIDARR/ping" >/dev/null 2>&1; then break; fi
      sleep 2
    done
    if ! $curl -sf "$LIDARR/ping" >/dev/null 2>&1; then
      log "ERROR: Lidarr did not become reachable at $LIDARR"
      exit 1
    fi

    KEY=$($sed -n 's:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p' "$CONFIG")
    if [ -z "$KEY" ]; then
      log "ERROR: could not read <ApiKey> from $CONFIG"
      exit 1
    fi

    # curl -f collapses every HTTP error into exit 22, which tells you nothing.
    # Capture the body and print it so a rejected payload is debuggable from the
    # journal alone. (Same helper as bazarr-provision.nix.)
    api() {
      local body code
      body=$($curl -s -w '\n%{http_code}' \
        -H "X-Api-Key: $KEY" -H "Content-Type: application/json" "$@") || return 1
      code=''${body##*$'\n'}
      body=''${body%$'\n'*}
      if [ "$code" -ge 400 ]; then
        log "ERROR: HTTP $code from Lidarr; args: $*"
        log "ERROR: response: $body"
        return 1
      fi
      printf '%s' "$body"
    }

    # ---------------------------------------------------------------
    # Step 2: root folder.
    #
    # Unlike bazarr-provision this needs no stamp file: both steps below read
    # current state first and only POST what is missing, so convergence is
    # structural. The flip side is that deleting either from Lidarr's UI is not
    # durable - the next boot or rebuild puts it back.
    # ---------------------------------------------------------------
    if api "$LIDARR/api/v1/rootfolder" \
         | $jq -e --arg p "$ROOT" 'any(.[]; .path == $p)' >/dev/null; then
      log "Root folder $ROOT already present."
    else
      # Lidarr requires a default quality/metadata profile on a root folder, and
      # the ids of the ones it seeds on first run are not guaranteed to be 1.
      QP=$(api "$LIDARR/api/v1/qualityprofile"  | $jq -r '.[0].id // 1')
      MP=$(api "$LIDARR/api/v1/metadataprofile" | $jq -r '.[0].id // 1')
      log "Adding root folder $ROOT (qualityProfile=$QP metadataProfile=$MP)..."
      api -X POST -d "$($jq -n \
          --arg p "$ROOT" --argjson qp "$QP" --argjson mp "$MP" \
          '{ name: "Music", path: $p,
             defaultQualityProfileId: $qp, defaultMetadataProfileId: $mp,
             defaultMonitorOption: "all", defaultNewItemMonitorOption: "all",
             defaultTags: [] }')" \
        "$LIDARR/api/v1/rootfolder" >/dev/null
    fi

    # ---------------------------------------------------------------
    # Step 3: Transmission download client.
    #
    # Built from GET /downloadclient/schema rather than a hand-written field
    # list, so a Lidarr upgrade that renames or adds a field cannot silently
    # produce a half-configured client.
    #
    # Note there is deliberately no download client for slskd: soularr moves
    # finished albums into Lidarr's download dir itself and then fires a
    # DownloadedAlbumsScan command, bypassing the download-client machinery
    # entirely. See homelab/soularr.nix.
    # ---------------------------------------------------------------
    if api "$LIDARR/api/v1/downloadclient" \
         | $jq -e --arg n "$DLNAME" 'any(.[]; .name == $n)' >/dev/null; then
      log "Download client $DLNAME already present."
    else
      log "Adding Transmission download client $DLNAME (category $CATEGORY)..."
      payload=$(api "$LIDARR/api/v1/downloadclient/schema" | $jq \
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
      api -X POST -d "$payload" "$LIDARR/api/v1/downloadclient" >/dev/null
    fi

    ${lib.optionalString cfg.organizeLibrary ''
    # ---------------------------------------------------------------
    # Step 4: turn on track renaming.
    #
    # Lidarr ships renameTracks=false, which means it drops every imported file
    # straight into the artist folder and ignores standardTrackFormat - so a
    # second album by the same artist lands next to the first, and two albums
    # with a track of the same name collide. The formats it ships already
    # describe album subfolders; only this boolean gates them.
    #
    # This matters less for playback than it looks, because Navidrome and
    # Jellyfin both group by tags rather than paths, but it keeps the library
    # organised the same way Radarr/Sonarr organise theirs.
    # ---------------------------------------------------------------
    naming=$(api "$LIDARR/api/v1/config/naming")
    if [ "$($jq -r '.renameTracks' <<<"$naming")" = "true" ]; then
      log "Track renaming already enabled."
    else
      log "Enabling track renaming so albums get their own folders..."
      api -X PUT -d "$($jq '.renameTracks = true' <<<"$naming")" \
        "$LIDARR/api/v1/config/naming" >/dev/null
    fi
    ''}

    log "Done."
  '';
in
{
  options.customConfig.homelab.arr.lidarr.provision = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Declaratively converge Lidarr's music root folder and Transmission
        download client over its REST API on every boot and rebuild. Lidarr
        keeps this state in a SQLite database it rewrites at runtime, so - as
        with Bazarr - a converging oneshot is the closest thing to declarative
        config available.
      '';
    };

    rootFolder = mkOption {
      type = types.str;
      default = "${mediaCfg.storagePath}/media/music";
      defaultText = literalExpression ''"''${config.customConfig.homelab.mediaSetup.storagePath}/media/music"'';
      description = "Music library root folder. Created by media-setup.nix.";
    };

    downloadClientName = mkOption {
      type = types.str;
      default = "Transmission";
      description = "Name of the Transmission client as it appears in Lidarr. Also the key this module converges on.";
    };

    organizeLibrary = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable Lidarr's track renaming, so imports are filed as
        Artist/Album (Year)/... instead of being dumped flat into the artist
        folder. Lidarr defaults this off; the album-folder formats it ships are
        inert until it is on.
      '';
    };

    downloadCategory = mkOption {
      type = types.str;
      default = "lidarr";
      description = ''
        Transmission category for music grabs. Transmission files these under
        <download-dir>/<category>/, mirroring the existing radarr/ and
        tv-sonarr/ directories.
      '';
    };
  };

  config = lib.mkIf (config.customConfig.homelab.arr.lidarr.enable && cfg.enable) {

    systemd.services.lidarr-provision = {
      description = "Provision Lidarr root folder and download client";
      after = [ "network-online.target" "lidarr.service" "transmission.service" ];
      wants = [ "network-online.target" ];
      requires = [ "lidarr.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = provisionScript;
      };
    };

  };
}
