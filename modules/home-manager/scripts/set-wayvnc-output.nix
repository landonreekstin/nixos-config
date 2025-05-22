# ~/nixos-config/modules/home-manager/scripts/set-wayvnc-output.nix
{ pkgs, lib, config, ... }:

let
    setWayvncOutputScript = pkgs.writeShellScriptBin "set-wayvnc-output" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail # Exit on error, undefined variable, or pipe failure

        GREP_CMD="${pkgs.gnugrep}/bin/grep"
        AWK_CMD="${pkgs.gawk}/bin/awk"

        if ! command -v wayvncctl &> /dev/null; then
            echo "Error: wayvncctl command not found. Ensure 'wayvnc' package is in 'home.packages' and the wayvnc service is running." >&2
            exit 1
        fi

        if [ "$#" -ne 1 ]; then
            echo "Usage: $0 \"<target_monitor_description>\""
            echo "Error: Target monitor description argument is missing." >&2
            exit 1
        fi

        TARGET_DESCRIPTION="$1"
        MAX_RETRIES=15 # Increased retries slightly for very early startup
        RETRY_DELAY=3  # Seconds to wait between retries

        echo "Attempting to set wayvnc output to monitor with description: '$TARGET_DESCRIPTION'" >&2

        for i in $(seq 1 $MAX_RETRIES); do
            echo "Attempt $i/$MAX_RETRIES to query wayvnc outputs..." >&2
            
            RAW_OUTPUT_TEXT=""
            WAYVNCCTL_EXIT_CODE=0

            # Safely attempt to run wayvncctl and capture its output (stdout & stderr) and exit status
            # This structure is more robust with 'set -e'
            if ! OUTPUT_AND_ERROR_FROM_WAYVNCCTL=$(wayvncctl output-list 2>&1); then
            WAYVNCCTL_EXIT_CODE=$? # Capture the actual exit code on failure
            RAW_OUTPUT_TEXT="$OUTPUT_AND_ERROR_FROM_WAYVNCCTL" # Store combined output/error
            echo "Error: 'wayvncctl output-list' command failed with exit code $WAYVNCCTL_EXIT_CODE." >&2
            echo "Output/Error from wayvncctl during this attempt: $RAW_OUTPUT_TEXT" >&2
            else
            WAYVNCCTL_EXIT_CODE=0 # Command succeeded
            RAW_OUTPUT_TEXT="$OUTPUT_AND_ERROR_FROM_WAYVNCCTL" # Store combined output
            fi

            if [ $WAYVNCCTL_EXIT_CODE -ne 0 ]; then
            # This block is now specifically for when the wayvncctl command itself fails
            if [ $i -lt $MAX_RETRIES ]; then
                echo "Retrying in $RETRY_DELAY seconds because wayvncctl command failed (e.g., socket not ready)..." >&2
                sleep $RETRY_DELAY
                continue
            else
                echo "Max retries reached. 'wayvncctl output-list' command consistently failed. Aborting." >&2
                exit 1
            fi
            fi

            # If command succeeded (WAYVNCCTL_EXIT_CODE == 0) but output is empty
            # (This might indicate wayvnc is running but has no monitors listed yet, or an unexpected successful but empty output)
            if [ -z "$RAW_OUTPUT_TEXT" ]; then
            echo "Warning: 'wayvncctl output-list' command succeeded but returned no output." >&2
            if [ $i -lt $MAX_RETRIES ]; then
                echo "Retrying in $RETRY_DELAY seconds..." >&2
                sleep $RETRY_DELAY
                continue
            else
                echo "Max retries reached. 'wayvncctl output-list' consistently returned no output. Aborting." >&2
                exit 1
            fi
            fi

            # DEBUG: Log the raw text (which might now include errors from wayvncctl if it failed but somehow exited 0)
            echo "DEBUG: Raw output/error text from wayvncctl output-list attempt:" >&2
            echo "$RAW_OUTPUT_TEXT" >&2

            # Proceed with parsing if we got here (meaning WAYVNCCTL_EXIT_CODE was 0 and RAW_OUTPUT_TEXT is not empty)
            MATCHING_LINE=$(echo "$RAW_OUTPUT_TEXT" | $GREP_CMD -F "$TARGET_DESCRIPTION" || true) # Add '|| true' if grep should not abort on no match with set -e

            if [ -n "$MATCHING_LINE" ]; then
            TARGET_SHORT_NAME=$(echo "$MATCHING_LINE" | $AWK_CMD '{sub(/:$/, "", $1); print $1}')

            if [ -n "$TARGET_SHORT_NAME" ]; then
                echo "Found monitor: Description='$TARGET_DESCRIPTION', Matched Line='$MATCHING_LINE', Extracted Short Name='$TARGET_SHORT_NAME'" >&2
                echo "Attempting: wayvncctl output-set \"$TARGET_SHORT_NAME\"" >&2
                # Before calling output-set, ensure wayvncctl is still responsive, as a sanity check or if it also needs retries.
                # For now, assuming if output-list worked, output-set has a good chance.
                if wayvncctl output-set "$TARGET_SHORT_NAME"; then
                echo "Successfully set wayvnc output to '$TARGET_SHORT_NAME'." >&2
                exit 0 # Success!
                else
                SET_EXIT_CODE=$?
                echo "Error: 'wayvncctl output-set \"$TARGET_SHORT_NAME\"' failed with exit code $SET_EXIT_CODE." >&2
                # Fall through to retry logic (the main loop will retry)
                fi
            else
                echo "Warning: Could not extract short name from matching line: '$MATCHING_LINE'" >&2
            fi
            else
            echo "Warning: Monitor with description '$TARGET_DESCRIPTION' not found in wayvncctl output this attempt." >&2
            # RAW_OUTPUT_TEXT already printed in DEBUG, so no need to repeat unless for specific "not found" context
            fi

            if [ $i -lt $MAX_RETRIES ]; then
            echo "Retrying entire process (e.g. monitor not found yet, or set failed) in $RETRY_DELAY seconds..." >&2
            sleep $RETRY_DELAY
            fi
        done

        echo "Error: Failed to set wayvnc output to monitor with description '$TARGET_DESCRIPTION' after $MAX_RETRIES attempts." >&2
        exit 1
        '';
in
{
    # Expose the script path for other modules to use, if needed, though direct
    # inclusion in home.packages is usually sufficient for PATH.
    # config.custom.scripts.setWayvncOutput = setWayvncOutputScript; # Optional if you want to reference it by a config option

    home.packages = [
        setWayvncOutputScript # Makes the script available in PATH
        pkgs.wayvnc        
        pkgs.gawk
        pkgs.gnugrep
    ];
}