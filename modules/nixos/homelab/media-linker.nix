# ~/nixos-config/modules/nixos/homelab/media-linker.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.mediaLinker;
  mediaCfg = config.customConfig.homelab.mediaSetup;

  mediaBase = "${mediaCfg.storagePath}/media";
  usersBase = "${mediaBase}/users";

  # Build the user mapping as a JSON array for the script
  userMappingJson = builtins.toJSON (map (u: {
    name = u.name;
    jellyseerrId = u.jellyseerrId;
  }) cfg.mediaUsers);

  syncScript = pkgs.writeShellScript "media-linker" ''
    set -euo pipefail

    JELLYSEERR_URL="http://localhost:5055"
    RADARR_URL="http://localhost:7878"
    SONARR_URL="http://localhost:8989"
    MEDIA_BASE="${mediaBase}"
    USERS_BASE="${usersBase}"
    USER_MAPPING='${userMappingJson}'

    log() { echo "[media-linker] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

    # Check required environment variables
    for var in JELLYSEERR_API_KEY RADARR_API_KEY SONARR_API_KEY; do
      if [ -z "''${!var:-}" ]; then
        log "ERROR: $var is not set. Check $ENVFILE"
        exit 1
      fi
    done

    jq=${lib.getExe pkgs.jq}
    curl="${pkgs.curl}/bin/curl"

    api() {
      local url="$1" key="$2"
      $curl -sf -H "X-Api-Key: $key" "$url"
    }

    # ---------------------------------------------------------------
    # Step 1: Build lookup tables from Radarr and Sonarr
    # ---------------------------------------------------------------
    log "Fetching Radarr movie list..."
    radarr_movies=$(api "$RADARR_URL/api/v3/movie" "$RADARR_API_KEY")

    log "Fetching Sonarr series list..."
    sonarr_series=$(api "$SONARR_URL/api/v3/series" "$SONARR_API_KEY")

    # Build tmdbId -> path maps as JSON objects for fast lookup
    radarr_lookup=$(echo "$radarr_movies" | $jq -c '
      [ .[] | select(.path != null and .hasFile == true) | {key: (.tmdbId | tostring), value: .path} ]
      | from_entries
    ')

    sonarr_lookup=$(echo "$sonarr_series" | $jq -c '
      [ .[] | select(.path != null) | {key: (.tvdbId | tostring), value: .path} ]
      | from_entries
    ')

    # ---------------------------------------------------------------
    # Step 2: Hardlink helper function
    # ---------------------------------------------------------------
    hardlink_tree() {
      local src="$1" dst="$2"

      if [ ! -d "$src" ]; then
        return
      fi

      # Find all files in source and create hardlinks in destination
      find "$src" -type f | while IFS= read -r file; do
        relative="''${file#$src/}"
        dst_file="$dst/$relative"
        dst_dir=$(dirname "$dst_file")

        if [ ! -f "$dst_file" ]; then
          mkdir -p "$dst_dir"
          ln "$file" "$dst_file" 2>/dev/null || true
        fi
      done
    }

    # ---------------------------------------------------------------
    # Step 3: Process each configured media user
    # ---------------------------------------------------------------
    num_users=$(echo "$USER_MAPPING" | $jq 'length')

    for i in $(seq 0 $((num_users - 1))); do
      user_name=$(echo "$USER_MAPPING" | $jq -r ".[$i].name")
      user_id=$(echo "$USER_MAPPING" | $jq -r ".[$i].jellyseerrId")
      user_movies_dir="$USERS_BASE/$user_name/movies"
      user_tv_dir="$USERS_BASE/$user_name/tv"

      log "Processing user: $user_name (Jellyseerr ID: $user_id)"

      # Track which directories should exist for this user
      expected_movies=()
      expected_tv=()

      # Fetch all available requests for this user (paginated)
      page=0
      page_size=50
      total=999

      while [ $((page * page_size)) -lt "$total" ]; do
        skip=$((page * page_size))
        response=$(api "$JELLYSEERR_URL/api/v1/request?filter=available&take=$page_size&skip=$skip&requestedBy=$user_id" "$JELLYSEERR_API_KEY")

        total=$(echo "$response" | $jq '.pageInfo.results // 0')
        results=$(echo "$response" | $jq -c '.results // []')
        num_results=$(echo "$results" | $jq 'length')

        for j in $(seq 0 $((num_results - 1))); do
          request=$(echo "$results" | $jq -c ".[$j]")
          media_type=$(echo "$request" | $jq -r '.type')
          media_status=$(echo "$request" | $jq -r '.media.status')

          # Only process fully available media (status 5 = available)
          if [ "$media_status" != "5" ]; then
            continue
          fi

          if [ "$media_type" = "movie" ]; then
            tmdb_id=$(echo "$request" | $jq -r '.media.tmdbId')
            master_path=$(echo "$radarr_lookup" | $jq -r --arg id "$tmdb_id" '.[$id] // empty')

            if [ -n "$master_path" ] && [ -d "$master_path" ]; then
              dir_name=$(basename "$master_path")
              expected_movies+=("$dir_name")
              hardlink_tree "$master_path" "$user_movies_dir/$dir_name"
            fi

          elif [ "$media_type" = "tv" ]; then
            tvdb_id=$(echo "$request" | $jq -r '.media.tvdbId')
            master_path=""

            # Try tvdbId lookup first
            if [ -n "$tvdb_id" ] && [ "$tvdb_id" != "null" ]; then
              master_path=$(echo "$sonarr_lookup" | $jq -r --arg id "$tvdb_id" '.[$id] // empty')
            fi

            # Fallback: search Sonarr by tmdbId if tvdbId didn't match
            if [ -z "$master_path" ]; then
              tmdb_id=$(echo "$request" | $jq -r '.media.tmdbId')
              master_path=$(echo "$sonarr_series" | $jq -r --arg id "$tmdb_id" '
                [ .[] | select(.tmdbId == ($id | tonumber)) | .path ] | first // empty
              ')
            fi

            if [ -n "$master_path" ] && [ -d "$master_path" ]; then
              dir_name=$(basename "$master_path")
              expected_tv+=("$dir_name")
              hardlink_tree "$master_path" "$user_tv_dir/$dir_name"
            fi
          fi
        done

        page=$((page + 1))
      done

      # ---------------------------------------------------------------
      # Step 4: Clean up orphaned directories for this user
      # ---------------------------------------------------------------
      # Remove movie dirs that are no longer in the user's requests
      if [ -d "$user_movies_dir" ]; then
        for dir in "$user_movies_dir"/*/; do
          [ -d "$dir" ] || continue
          dir_name=$(basename "$dir")
          found=0
          for expected in "''${expected_movies[@]+"''${expected_movies[@]}"}"; do
            if [ "$expected" = "$dir_name" ]; then
              found=1
              break
            fi
          done
          if [ "$found" -eq 0 ]; then
            log "Removing orphaned movie dir for $user_name: $dir_name"
            rm -rf "$dir"
          fi
        done
      fi

      # Remove TV dirs that are no longer in the user's requests
      if [ -d "$user_tv_dir" ]; then
        for dir in "$user_tv_dir"/*/; do
          [ -d "$dir" ] || continue
          dir_name=$(basename "$dir")
          found=0
          for expected in "''${expected_tv[@]+"''${expected_tv[@]}"}"; do
            if [ "$expected" = "$dir_name" ]; then
              found=1
              break
            fi
          done
          if [ "$found" -eq 0 ]; then
            log "Removing orphaned TV dir for $user_name: $dir_name"
            rm -rf "$dir"
          fi
        done
      fi

      log "Finished processing $user_name: ''${#expected_movies[@]} movies, ''${#expected_tv[@]} shows"
    done

    log "Sync complete."
  '';
in
{
  config = lib.mkIf cfg.enable {

    systemd.services.media-linker = {
      description = "Sync per-user Jellyfin libraries via hardlinks";
      after = [ "network.target" "jellyseerr.service" "radarr.service" "sonarr.service" ];
      wants = [ "network.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = syncScript;
        EnvironmentFile = cfg.envFile;
      };
    };

    systemd.timers.media-linker = {
      description = "Timer for media-linker per-user library sync";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.interval;
        Persistent = true;
      };
    };

  };
}
