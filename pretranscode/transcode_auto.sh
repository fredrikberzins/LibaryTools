#!/usr/bin/env bash

show_help() {
    echo "Movie Transcoder Script"
    echo
    echo "Usage: $0 -i <input_dir> -r <resolution> -a <audio>"
    echo
    echo "Options:"
    echo "  -i   Path to movie library"
    echo "  -r   Target resolution (e.g. 720p, 1080p, 1440p)"
    echo "  -a   Target audio layout (2.0, 5.1, 7.1)"
    echo "  -h   Show this help message"
    echo
    echo "Examples:"
    echo "  $0 -i /mnt/NAS/Movies -r 1440p -a 5.1"
    exit 0
}

while getopts "i:r:a:h" opt; do
    case "$opt" in
        i) INPUT_DIR="$OPTARG" ;;
        r) RESOLUTION="$OPTARG" ;;
        a) AUDIO="$OPTARG" ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

if [[ -z "$INPUT_DIR" || -z "$RESOLUTION" || -z "$AUDIO" ]]; then
    show_help
fi

TARGET_HEIGHT="${RESOLUTION%p}"

case "$AUDIO" in
    2.0) TARGET_CHANNELS=2 ;;
    5.1) TARGET_CHANNELS=6 ;;
    7.1) TARGET_CHANNELS=8 ;;
    *) echo "Unsupported audio layout: $AUDIO"; exit 1 ;;
esac

echo "Input: $INPUT_DIR"
echo "Target resolution: ${TARGET_HEIGHT}p"
echo "Target audio: $AUDIO (${TARGET_CHANNELS} channels)"
echo

# Find files, excluding .temp folders
find "$INPUT_DIR" -type f \( -iname "*.mkv" -o -iname "*.mp4" \) ! -path "*/.temp/*" | sort | while read -r file; do
    dir=$(dirname "$file")
    name=$(basename "$file")
    base="${name%.*}"

    tempdir="$dir/.temp"
    mkdir -p "$tempdir"

    # Probe video height
    height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$file")
    height="${height//[!0-9]/}"
    [[ -z "$height" ]] && height=0

    if (( height <= TARGET_HEIGHT )); then
        echo "Skipping (height < target ${TARGET_HEIGHT}p): $file"
        continue
    fi

    # Probe bitrate
    bitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of csv=p=0 "$file")
    bitrate="${bitrate//[!0-9]/}"
    [[ -z "$bitrate" ]] && bitrate=0

    # Probe duration
    duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$file")
    duration="${duration//[^0-9.]}"  
    [[ -z "$duration" ]] && duration=0

    # Fallback bitrate
    if (( bitrate == 0 && duration != 0 )); then
        filesize=$(stat -c%s "$file")
        bitrate=$(( (filesize * 8) / ${duration%.*} ))
    fi
    (( bitrate == 0 )) && bitrate=$((15 * 1000 * 1000))  # fallback 15 Mbps

    # Cap at 15 Mbps
    max_bitrate=$((15 * 1000 * 1000))
    (( bitrate > max_bitrate )) && bitrate=$max_bitrate
    target_bitrate=$bitrate
    bufsize=$((2 * target_bitrate))

    # Probe audio channels
    audio_channels=$(ffprobe -v error -select_streams a:0 -show_entries stream=channels -of csv=p=0 "$file")
    audio_channels="${audio_channels//[!0-9]/}"  
    [[ -z "$audio_channels" ]] && audio_channels=2

    # Output channels = min(source, target)
    if (( audio_channels < TARGET_CHANNELS )); then
        out_channels=$audio_channels
    else
        out_channels=$TARGET_CHANNELS
    fi

    # Map TARGET_CHANNELS back to layout string for naming
    case "$TARGET_CHANNELS" in
        2) TARGET_AUDIO_LAYOUT="2.0" ;;
        6) TARGET_AUDIO_LAYOUT="5.1" ;;
        8) TARGET_AUDIO_LAYOUT="7.1" ;;
    esac

    # Replace technical block [<res>p ...]
    TECH_BLOCK_REGEX="\[[0-9]{3,4}p[[:space:]]*[0-9.]*\]"

    if [[ "$base" =~ $TECH_BLOCK_REGEX ]]; then
        # Replace all matches with new target block: [<TARGET_HEIGHT>p 8bit <AUDIO>]
        out_name=$(echo "$base" | sed -E "s/\[[0-9]{3,4}p[[:space:]]*[0-9.]*\]/[${TARGET_HEIGHT}p 8bit $AUDIO]/g")
        echo "DEBUG: regex matched"
    else
        # No technical block, append it
        out_name="${base} - [${TARGET_HEIGHT}p 8bit $AUDIO]"
        echo "DEBUG: regex did NOT match, appending block"
    fi

    temp_output="$tempdir/$out_name.mkv"
    final_output="$dir/$out_name.mkv"

    echo "DEBUG: base='$base'"
    echo "DEBUG: temp_output='$temp_output'"
    echo "DEBUG: final_output='$final_output'"
    
    if [[ -f "$final_output" ]]; then
        echo "Skipping, already exists: $final_output"
        continue
    fi

    echo "Processing: $file --> $temp_output"

    # Choose audio codec
    if (( audio_channels >= out_channels )); then
        audio_codec="copy"
    else
        audio_codec="aac"
    fi

    # Transcode with libx265 (CPU)
    ffmpeg -v warning -stats -y -i "$file" \
        -map 0 \
        -c:v libx265 -preset slow -x265-params "crf=23" -b:v "$target_bitrate" -maxrate "$target_bitrate" -bufsize "$bufsize" \
        -vf "scale=-2:$TARGET_HEIGHT" -pix_fmt yuv420p \
        -c:a "$audio_codec" -ac "$out_channels" -b:a 640k \
        -c:s copy -map_metadata 0 -sn \
        "$temp_output"

    # Move temp file to final location, overwrite if exists
    if [[ -f "$temp_output" ]]; then
        mv -f "$temp_output" "$final_output"
        echo "Finished: $final_output"
    else
        echo "Transcoding failed: $file"
    fi
done
