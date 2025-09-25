param(
    [string]$i,  # Input directory
    [string]$r,  # Resolution (e.g. 720p, 1080p, 1440p)
    [string]$a,  # Audio (2.0, 5.1, 7.1)
    [switch]$h   # Help
)

function Show-Help {
    Write-Host -ForegroundColor Green "Movie Transcoder Script"
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green "Usage: .\transcode_varibel.ps1 -i <input_dir> -r <resolution> -a <audio>"
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green "Options:"
    Write-Host -ForegroundColor Green "  -i   Path to movie library"
    Write-Host -ForegroundColor Green "  -r   Target resolution (e.g. 720p, 1080p, 1440p)"
    Write-Host -ForegroundColor Green "  -a   Target audio layout (2.0, 5.1, 7.1)"
    Write-Host -ForegroundColor Green "  -h   Show this help message"
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green "Examples:"
    Write-Host -ForegroundColor Green "  .\transcode_varibel.ps1 -i \\192.168.1.220\film_nas\movies -r 1440p -a 5.1"
    Write-Host -ForegroundColor Green "  .\transcode_varibel.ps1 -i D:\Movies -r 1080p -a 2.0"
    exit
}

if ($h -or -not $i -or -not $r -or -not $a) {
    Show-Help
}

# Strip trailing "p" from resolution
$TargetHeight = $r.TrimEnd("p")

# Map audio layout
switch ($a) {
    "2.0" { $Channels = 2 }
    "5.1" { $Channels = 6 }
    "7.1" { $Channels = 8 }
    default {
        Write-Host -ForegroundColor Red "Unsupported audio layout: $a"
        exit 1
    }
}

Write-Host "Input: $i" -ForegroundColor Yellow
Write-Host "Target resolution: ${TargetHeight}p" -ForegroundColor Green
Write-Host "Target audio: $a ($Channels channels)" -ForegroundColor Green
Write-Host

Get-ChildItem -Path $i -Recurse -Include *.mkv, *.mp4 | ForEach-Object {
    $file = $_.FullName
    $dir = $_.DirectoryName
    $name = $_.BaseName

    # Skip if already transcoded
    if ($name -match "\[${TargetHeight}p 8bit $a\]") {
        Write-Host "Already transcoded: $file" -ForegroundColor Yellow
        return
    }

    # Replace only the resolution/audio tag, leave other brackets intact
    if ($name -match "\[([0-9]{3,4}p\s?)?([0-9]{1,2}bit\s?)?([0-9]\.[0-9])?\]") {
        $outName = $name -replace "\[([0-9]{3,4}p\s?)?([0-9]{1,2}bit\s?)?([0-9]\.[0-9])?\]", "[${TargetHeight}p 8bit $a]"
    } else {
        $outName = "$name - [${TargetHeight}p 8bit $a]"
    }

    $output = Join-Path $dir "$outName.mkv"

    if (Test-Path $output) {
        Write-Host "Skipping, Already exists: $output"  -ForegroundColor Yellow
        return
    }

    # Probe height
    $height = (& ffprobe -v error -select_streams v:0 -show_entries stream=height `
        -of csv=p=0 "$file").Trim()

    if ([int]$height -le [int]$TargetHeight) {
        Write-Host "Skipping (<=${TargetHeight}p): $file"  -ForegroundColor Yellow
        return
    }

    Write-Host "Processing: $file --> $output" -ForegroundColor Green

    & ffmpeg -v warning -stats -y -i "$file" `
        -map 0 -c:v hevc_nvenc -preset slow `
        -pix_fmt yuv420p -vf "scale=-2:$TargetHeight" `
        -c:a aac -b:a 640k -ac $Channels `
        -c:s copy -map_metadata 0 -sn "$output"
}
