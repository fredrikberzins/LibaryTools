$MoviesDir = "Path\to\Libary"

Get-ChildItem -Path $MoviesDir -Recurse -Include *.mkv, *.mp4 | ForEach-Object {

    $file = $_.FullName
    $dir = $_.DirectoryName
    $name = $_.BaseName

    if ($name -match "\[1080p 8bit 2\.0\]$") { return }

    if ($name -match "\[\d{3,4}p.*?\]$") {
        $outName = $name -replace "\[\d{3,4}p.*?\]$", "[1080p 8bit 2.0]"
    } else {
        $outName = "$name - [1080p 8bit 2.0]"
    }
    $output = Join-Path $dir "$outName.mp4"

    if (Test-Path $output) {
        Write-Host "Already exists, skipping: $output"
        return
    }

    $heightStr = (& ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$file").Trim()
    $height = [int]$heightStr

    if ($height -le 1080) {
        Write-Host "Skipping (<=1080p): $file"
        return
    }

    Write-Host "Processing: $file"

    & ffmpeg -hide_banner -stats -n -i "$file" -map 0 `
        -c:v h264_nvenc -preset p7 -pix_fmt yuv420p -vf "scale=-2:1080" `
        -c:a aac -b:a 640k -ac 2 -c:s mov_text -sn "$output"
}
