#!/bin/bash
# transcode_varibel.sh
# Usage: ./transcode_varibel.sh -i /path/to/library -r 1440p -a 5.1

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
    echo "  $0 -i /mnt/movies -r 1440p -a 5.1"
    echo "  $0 -i /home/user/Movies -r 1080p -a 2.0"
    exit 0
}

# Default values
INPUT_DIR=""
RESOLUTION=""
AUDIO=""
while getopts "i:r:a:h" opt; do
    case $opt in
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

# Strip trailing "p" from resolution
TARGET_HEIGHT="${RESOLUTION%p}"

# Map audio layout to channels
case "$AUDIO" in
    "2.0") CHANNELS=2 ;;
    "5.1") CHANNELS=6 ;;
    "7.1") CHANNELS=8 ;;
    *) echo "Unsupported audio layout: $AUDIO"; exit 1 ;;
esac

echo "Input: $INPUT_DIR"
echo "Target resolution: ${TARGET_HEIGHT}p"
echo "Target audio: $AUDIO ($CHANNELS channels)"
echo

# Loop over MKV/MP4 files recursively
find "$INPUT_DIR" -type f \( -iname "*.mkv" -o -iname "*.mp4" \) | while read -r FILE; do
    DIR=$(dirname "$FILE")
    NAME=$(basename "$FILE")
    BASE="${NAME%.*}"

    # Skip if already transcoded
    if [[ "$BASE" =~ \[${TARGET_HEIGHT}p\ 8bit\ $AUDIO\] ]]; then
        echo "Already transcoded: $FILE"
        continue
    fi

    # Replace only the resolution/audio tag, preserve other brackets
    if [[ "$BASE" =~ \[[0-9]{3,4}p\ [0-9]\.[0-9]\](?!\[) ]]; then
        OUTNAME=$(echo "$BASE" | sed -E "s/\[[0-9]{3,4}p [0-9]\.[0-9]\](?!\[)/[${TARGET_HEIGHT}p 8bit $AUDIO]/")
    else
        OUTNAME="$BASE - [${TARGET_HEIGHT}p 8bit $AUDIO]"
    fi

    OUTPUT="$DIR/$OUTNAME.mkv"

    if [[ -f "$OUTPUT" ]]; then
        echo "Already exists, skipping: $OUTPUT"
        continue
    fi

    # Probe height
    HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height \
        -of csv=p=0 "$FILE" | tr -d '\r\n')

    if (( HEIGHT <= TARGET_HEIGHT )); then
        echo "Skipping (≤${TARGET_HEIGHT}p): $FILE"
        continue
    fi

    echo "Processing: $FILE → $OUTPUT"

    ffmpeg -hide_banner -stats -n -i "$FILE" -map 0 \
        -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -vf "scale=-2:$TARGET_HEIGHT" \
        -c:a aac -b:a 640k -ac $CHANNELS -c:s copy -map_metadata 0 -sn "$OUTPUT"

done
