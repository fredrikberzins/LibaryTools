MoviesDir="/path/to/Library"

find "$MoviesDir" -type f \( -iname "*.mkv" -o -iname "*.mp4" \) | while read -r file; do
    dir=$(dirname "$file")
    name=$(basename "$file")
    base="${name%.*}"

    if [[ "$base" =~ \[1440p\ 8bit\ 2\.0\]$ ]]; then
        continue
    fi

    if [[ "$base" =~ \[[0-9]{3,4}p.*\]$ ]]; then
        outName="${base/\[[0-9]\{3,4\}p.*\]/[1440p 8bit 2.0]}"
    else
        outName="$base - [1440p 8bit 2.0]"
    fi
    output="$dir/$outName.mp4"

    if [[ -f "$output" ]]; then
        echo "Already exists, skipping: $output"
        continue
    fi

    height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height \
             -of csv=p=0 "$file" | tr -d '\r\n')

    if (( height <= 1440 )); then
        echo "Skipping (<=1440p): $file"
        continue
    fi

    echo "Processing: $file"

    ffmpeg -hide_banner -stats -n -i "$file" -map 0 \
        -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -vf "scale=-2:1440" \
        -c:a aac -b:a 640k -ac 2 -c:s mov_text -sn "$output"
done
