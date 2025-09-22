#!/usr/bin/env bash

set -euo pipefail

# --- Parameters ---
INPUT_FOLDER="$1"
TARGET_RES="$2"      # e.g., 1440p
TARGET_AUDIO="$3"    # e.g., 5.1
WHATIF="${4:-false}" # pass "true" for test mode

echo "Cleaning: $INPUT_FOLDER"
echo "Target: [$TARGET_RES $TARGET_AUDIO]"
echo

# Iterate first-level subdirectories
for dir in "$INPUT_FOLDER"/*/; do
    [ -d "$dir" ] || continue
    echo "Scanning folder: $dir"

    # Gather files recursively
    mapfile -t files < <(find "$dir" -type f)
    [ "${#files[@]}" -gt 0 ] || continue

    declare -A file_res
    declare -A file_audio
    declare -A file_block

    # Extract info from filenames
    for file in "${files[@]}"; do
        name="$(basename "$file")"
        block="$(echo "$name" | grep -oP '\[\K[^\]]+(?=\])' || true)" # text inside []
        res="$(echo "$block" | grep -oP '\d{3,4}p' || true)"
        audio="$(echo "$block" | grep -oP '\d\.\d' || true)"

        file_res["$file"]="$res"
        file_audio["$file"]="$audio"
        file_block["$file"]="$block"
    done

    # Check if target exists
    has_target=false
    for file in "${files[@]}"; do
        if [[ "${file_res[$file]}" == "$TARGET_RES" && "${file_audio[$file]}" == "$TARGET_AUDIO" ]]; then
            has_target=true
            break
        fi
    done

    if ! $has_target; then
        echo -e "\nSkipping $dir (no target version found, keeping everything)"
        continue
    fi

    # Process files
    echo -e "\nProcessing $dir"
    for file in "${files[@]}"; do
        res="${file_res[$file]}"
        audio="${file_audio[$file]}"
        block="${file_block[$file]}"
        name="$(basename "$file")"

        if [[ "$res" == "$TARGET_RES" && "$audio" == "$TARGET_AUDIO" ]]; then
            echo -e " KEEP   $name   (target match)"
        elif [[ -n "$block" ]]; then
            echo -e " DELETE $name   (other version: $block)"
            if [[ "$WHATIF" != "true" ]]; then
                rm -f "$file"
            fi
        else
            echo -e " KEEP   $name   (no block)"
        fi
    done
done

echo -e "\nDone."
