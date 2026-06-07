# ~/nixos-config/modules/home-manager/gaming/default.nix
{ lib, pkgs, config, customConfig, ... }:

{
  config = lib.mkIf customConfig.profiles.gaming.enable {

    # Fix for SWBF2 (App 1237950): EA Background Service (BGS) has a bug where it fails
    # to write HKLM\SOFTWARE\Origin\ClientPath, which PACE/SecuROM DRM requires for
    # license validation. Without it the game exits 0xffffffff before reaching the menu.
    # BGS creates [Software\\Wow6432Node\\Origin] but never populates it, and never
    # creates [Software\\Origin] (64-bit) at all.
    home.activation.swbf2EaAppRegistryFix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      PROTON_PREFIX="$HOME/.local/share/Steam/steamapps/compatdata/1237950"
      WINE_C="$PROTON_PREFIX/pfx/drive_c"
      SYSREG="$PROTON_PREFIX/pfx/system.reg"
      MACHINE_INI="$WINE_C/ProgramData/EA Desktop/machine.ini"

      if [ -f "$SYSREG" ]; then

        # Idempotency: skip if [Software\\Origin] (64-bit) already has ClientPath set
        _in_sec=0
        _has_client=0
        while IFS= read -r _ln; do
          case "$_ln" in
            \[Software\\\\Origin\]*) _in_sec=1 ;;
            \[*) [ "$_in_sec" = 1 ] && break; _in_sec=0 ;;
            '"ClientPath"'*) [ "$_in_sec" = 1 ] && { _has_client=1; break; } ;;
          esac
        done < "$SYSREG"

        if [ "$_has_client" = 1 ]; then
          echo "swbf2-fix: Origin\\ClientPath already set, skipping"
        else
          LEGACY_CLI=$(find "$WINE_C/Program Files/Electronic Arts/EA Desktop" \
            -name "OriginLegacyCLI.exe" 2>/dev/null | sort -V | tail -1)

          if [ -z "$LEGACY_CLI" ]; then
            echo "swbf2-fix: OriginLegacyCLI.exe not found, skipping"
          else
            # Convert Unix path to Windows registry path (double-backslash separators)
            _rel=''${LEGACY_CLI#$WINE_C/}
            WIN_PATH="C:\\\\$(echo "$_rel" | sed 's|/|\\\\|g')"
            _dir=$(dirname "$LEGACY_CLI")
            _reld=''${_dir#$WINE_C/}
            WIN_DIR="C:\\\\$(echo "$_reld" | sed 's|/|\\\\|g')"
            VERSION=$(echo "$LEGACY_CLI" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            [ -z "$VERSION" ] && VERSION="13.720.0.6233"
            NOW=$(date +%s)
            FT=$(printf '%x' $(( (NOW + 11644473600) * 10000000 )))

            # Insert [Software\\Origin] (64-bit) before [Software\\Registered Applications]
            awk -v ts="$NOW" -v ft="$FT" -v cp="$WIN_PATH" -v id="$WIN_DIR" -v ver="$VERSION" '
              /^\[Software\\\\Registered Applications\]/ && !ins {
                print "[Software\\\\Origin] " ts
                print "#time=" ft
                print "\"ClientPath\"=\"" cp "\""
                print "\"InstallDir\"=\"" id "\""
                print "\"Version\"=\"" ver "\""
                print ""
                ins=1
              }
              { print }
            ' "$SYSREG" > "$SYSREG.tmp" && mv "$SYSREG.tmp" "$SYSREG"

            # Handle [Software\\Wow6432Node\\Origin] (32-bit):
            # BGS creates this section but never populates it.
            # If it exists with no ClientPath, inject values after #time= line.
            # If it doesn't exist, insert the full section before [Software\\Wow6432Node\\Policies].
            if grep -q '^\[Software\\\\Wow6432Node\\\\Origin\]' "$SYSREG"; then
              awk -v ft="$FT" -v cp="$WIN_PATH" -v id="$WIN_DIR" -v ver="$VERSION" '
                /^\[Software\\\\Wow6432Node\\\\Origin\]/ { in_sec=1 }
                /^\[/ && !/^\[Software\\\\Wow6432Node\\\\Origin\]/ { in_sec=0 }
                in_sec && /^#time=/ && !done {
                  print "#time=" ft
                  print "\"ClientPath\"=\"" cp "\""
                  print "\"InstallDir\"=\"" id "\""
                  print "\"Version\"=\"" ver "\""
                  done=1; next
                }
                { print }
              ' "$SYSREG" > "$SYSREG.tmp" && mv "$SYSREG.tmp" "$SYSREG"
            else
              awk -v ts="$NOW" -v ft="$FT" -v cp="$WIN_PATH" -v id="$WIN_DIR" -v ver="$VERSION" '
                /^\[Software\\\\Wow6432Node\\\\Policies\]/ && !ins {
                  print "[Software\\\\Wow6432Node\\\\Origin] " ts
                  print "#time=" ft
                  print "\"ClientPath\"=\"" cp "\""
                  print "\"InstallDir\"=\"" id "\""
                  print "\"Version\"=\"" ver "\""
                  print ""
                  ins=1
                }
                { print }
              ' "$SYSREG" > "$SYSREG.tmp" && mv "$SYSREG.tmp" "$SYSREG"
            fi

            echo "swbf2-fix: applied Origin\\ClientPath = $WIN_PATH"
          fi
        fi

        # Reset stuck machine.updatepending=1 (corrupted update state blocks BGS operations)
        if [ -f "$MACHINE_INI" ] && grep -q 'machine\.updatepending=1' "$MACHINE_INI"; then
          sed -i 's/machine\.updatepending=1/machine.updatepending=0/' "$MACHINE_INI"
          echo "swbf2-fix: reset machine.updatepending to 0"
        fi

      fi
    '';

  };
}
