param(
    [string]$i,  # Input directory
    [string]$r,  # Resolution (e.g. 720p, 1080p, 1440p)
    [string]$a,  # Target audio (2.0, 5.1, 7.1)
    [switch]$h   # Help
)

function Show-Help {
    Write-Host -ForegroundColor Green "Movie Transcoder Script"
    Write-Host
    Write-Host -ForegroundColor Green "Usage: .\transcode_auto.ps1 -i <input_dir> -r <resolution> -a <audio>"
    Write-Host
    Write-Host -ForegroundColor Green "Options:"
    Write-Host -ForegroundColor Green "  -i   Path to movie library"
    Write-Host -ForegroundColor Green "  -r   Target resolution (e.g. 720p, 1080p, 1440p)"
    Write-Host -ForegroundColor Green "  -a   Target audio layout (2.0, 5.1, 7.1)"
    Write-Host -ForegroundColor Green "  -h   Show this help message"
    Write-Host
    Write-Host -ForegroundColor Green "Examples:"
    Write-Host -ForegroundColor Green "  .\transcode_auto.ps1 -i \\NAS\Movies -r 1440p -a 5.1"
    exit
}

if ($h -or -not $i -or -not $r -or -not $a) { Show-Help }

# Strip trailing "p" from resolution
$TargetHeight = $r.TrimEnd("p")

# Map target audio
switch ($a) {
    "2.0" { $TargetChannels = 2 }
    "5.1" { $TargetChannels = 6 }
    "7.1" { $TargetChannels = 8 }
    default { Write-Host -ForegroundColor Red "Unsupported audio layout: $a"; exit 1 }
}

Write-Host "Input: $i" -ForegroundColor Yellow
Write-Host "Target resolution: ${TargetHeight}p" -ForegroundColor Green
Write-Host "Target audio: $a ($TargetChannels channels)" -ForegroundColor Green
Write-Host

Get-ChildItem -Path $i -Recurse -Include *.mkv, *.mp4 -File | Where-Object { $_.DirectoryName -notmatch '\\\.temp($|\\)' } | ForEach-Object {
    $file = $_.FullName
    $dir = $_.DirectoryName
    $name = $_.BaseName

    # Prepare temp folder
    $TempDir = Join-Path $dir ".temp"
    if (-not (Test-Path $TempDir)) {
        New-Item -ItemType Directory -Path $TempDir -ErrorAction SilentlyContinue | Out-Null
    }

    # Initialize variables
    $height = 0
    $bitrate = 0
    $bitrateKbps = 0
    $filesizeBytes = 0
    $durationSec = 0.0

    # Probe video height
    $heightStr = & ffprobe -v error -select_streams v:0 -show_entries stream=height `
        -of default=noprint_wrappers=1:nokey=1 "$file"

    if (-not [int]::TryParse($heightStr.Trim(), [ref]$height)) {
        Write-Host "Failed to parse height for $file" -ForegroundColor Red
        return
    }

    # Attempt to probe bitrate
    $probeBitrate = & ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate `
        -of default=noprint_wrappers=1:nokey=1 "$file"

    # Fallback if probe fails
    if (-not [int]::TryParse($probeBitrate.Trim(), [ref]$bitrate) -or $bitrate -eq 0) {
        Write-Host "Bitrate probe failed, will fallback" -ForegroundColor Yellow
        # Ensure we have the raw path string
        $rawFile = [System.IO.Path]::GetFullPath($file)

        # Get file info safely
        try {
            $fileInfo = Get-Item -LiteralPath $rawFile
            $filesizeBytes = $fileInfo.Length
        } catch {
            Write-Host "Failed to get file size for $file" -ForegroundColor Red
            $filesizeBytes = 0
        }

        # Duration from ffprobe
        $durationStr = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file"
        [double]::TryParse($durationStr.Trim(), [ref]$durationSec) | Out-Null

        # Fallback bitrate
        if ($bitrate -eq 0 -and $filesizeBytes -gt 0 -and $durationSec -gt 0) {
            $bitrate = [int](($filesizeBytes * 8) / $durationSec)  # bits/sec
        }
    } else {
        $filesizeBytes = (Get-Item $file).Length
        $durationStr = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file"
        [double]::TryParse($durationStr.Trim(), [ref]$durationSec) | Out-Null
    }

    $probeAudio = & ffprobe -v error -select_streams a:0 -show_entries stream=channels -of csv=p=0 "$file"
    $audioChannels = [int]$probeAudio.Trim()

    # Determine output channels (cannot exceed source)
    $outChannels = [Math]::Min($audioChannels, $TargetChannels)

    # Determine output bitrate (max 15 Mbps)
    $targetBitrate = [Math]::Min($bitrate, 15MB) # 15 Mbps cap

    # Map audio layout
    switch ($a) {
        "2.0" { $Channels = 2; $audioTag = "2.0" }
        "5.1" { $Channels = 6; $audioTag = "5.1" }
        "7.1" { $Channels = 8; $audioTag = "7.1" }
        default {
            Write-Host -ForegroundColor Red "Unsupported audio layout: $a"
            exit 1
        }
    }

    # Then use $audioTag in the filename
    if ($name -match "\[([0-9]{3,4}p\s?)?([0-9]{1,2}bit\s?)?([0-9]\.[0-9])?\]") {
        $outName = $name -replace "\[([0-9]{3,4}p\s?)?([0-9]{1,2}bit\s?)?([0-9]\.[0-9])?\]", "[${TargetHeight}p 8bit $audioTag]"
    } else {
        $outName = "$name - [${TargetHeight}p 8bit $audioTag]"
    }


    $tempOutput = Join-Path $TempDir "$outName.mkv"
    $finalOutput = Join-Path $dir "$outName.mkv"

    if (Test-Path $finalOutput) {
        Write-Host "Skipping, Already exists: $finalOutput" -ForegroundColor Yellow
        return
    }

    if ($height -le $TargetHeight) {
        Write-Host "Skipping (<=${TargetHeight}p): $file" -ForegroundColor Yellow
        return
    }

    Write-Host "Processing: $file --> $tempOutput" -ForegroundColor Green

    $bufsize = 2 * $targetBitrate

    # Transcode with HEVC
    & ffmpeg -v warning -stats -y -i "$file" `
        -map 0 `
        -c:v hevc_nvenc -preset slow -rc:v vbr -b:v $targetBitrate -maxrate $targetBitrate -bufsize $bufsize `
        -pix_fmt yuv420p -vf "scale=-2:$TargetHeight" `
        -c:a aac -ac $outChannels -b:a 640k `
        -c:s copy -map_metadata 0 -sn "$tempOutput"
    
    Write-Host "Transcoding Done" -ForegroundColor Green
    Write-Host "Checking for: '$tempOutput'"
    # Move temp file to final location
    if (Test-Path $tempOutput) {
        Move-Item -Path $tempOutput -Destination $finalOutput
        Write-Host "Moved and Finished: $finalOutput" -ForegroundColor Green
    } else {
        Write-Host "Move failed: $file" -ForegroundColor Red
        Get-ChildItem -Path (Split-Path $tempOutput) | Select-Object Name, Length
    }
}
