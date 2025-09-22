param (
    [string]$i,  # Input directory
    [string]$r,  # Resolution (e.g. 720p, 1080p, 1440p)
    [string]$a,  # Audio (2.0, 5.1, 7.1)
    [switch]$d,  # Dry run mode
    [switch]$h   # Help
)

function Show-Help {
    Write-Host -ForegroundColor Green "Movie Removal Script"
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green "Usage: .\remove_pretranscoded.ps1 -i <input_dir> -r <resolution> -a <audio>"
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green "Options:"
    Write-Host -ForegroundColor Green "  -i   Path to movie library"
    Write-Host -ForegroundColor Green "  -r   Target resolution (e.g. 720p, 1080p, 1440p)"
    Write-Host -ForegroundColor Green "  -a   Target audio layout (2.0, 5.1, 7.1)"
    Write-Host -ForegroundColor Green "  -d   Dry run to se waht will be deleted"
    Write-Host -ForegroundColor Green "  -h   Show this help message"
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green "Examples:"
    Write-Host -ForegroundColor Green "  .\remove_pretranscoded.ps1 -i \\192.168.1.220\film_nas\movies -r 1440p -a 5.1"
    Write-Host -ForegroundColor Green "  .\remove_pretranscoded.ps1 -i D:\Movies -r 1080p -a 2.0 -d"
    exit
}

if ($h -or -not $i -or -not $r -or -not $a) {
    Show-Help
}

Write-Host "Cleaning: $i" -ForegroundColor Yellow
Write-Host "Target: [$r $a]" -ForegroundColor Green
Write-Host 

# Only first-level subdirectories
$movieDirs = Get-ChildItem -LiteralPath $i -Directory | ForEach-Object { $_.FullName }

foreach ($dir in $movieDirs) {
    # Get all files in this folder and subfolders
    $files = Get-ChildItem -LiteralPath $dir -File -Recurse -ErrorAction SilentlyContinue
    if (-not $files) { continue }

    $fileInfo = @()

    foreach ($file in $files) {

        $name = $file.Name
        $block = $null
        $res = $null
        $audio = $null

        if ($name -match '\[(?:\d{3,4}p\s*)?(?:\d{1,2}bit\s*)?(?:\d\.\d)?\]') {
            $block = $Matches[0]
            $resMatch = [regex]::Match($block, '\d{3,4}p')
            $audioMatch = [regex]::Match($block, '\d\.\d')

            if ($resMatch.Success) { $res = $resMatch.Value }
            if ($audioMatch.Success) { $audio = $audioMatch.Value }
        }

        $fileInfo += [PSCustomObject]@{
            File  = $file
            Name  = $name
            Res   = $res
            Audio = $audio
            Block = $block
        }
    }

    # Check if target exists
    $hasTarget = $fileInfo | Where-Object { $_.Res -eq $r -and $_.Audio -eq $a }
    if (-not $hasTarget) {
        Write-Host "`nSkipping $dir (no target version found, keeping everything)" -ForegroundColor Yellow
        continue
    }

    Write-Host "`nProcessing $dir" -ForegroundColor Cyan
    foreach ($f in $fileInfo) {
        if ($f.Res -eq $r -and $f.Audio -eq $a) {
            Write-Host " KEEP   $($f.Name)   (target match)" -ForegroundColor Green
        }
        elseif ($f.Block) {
            Write-Host " DELETE $($f.Name)   (other version: $($f.Block))" -ForegroundColor Red
            if (-not $d) {
                #Remove-Item -LiteralPath $f.File.FullName -Force
                continue
            }
        }
        else {
            Write-Host " KEEP   $($f.Name)   (no block)" -ForegroundColor Yellow
        }
    }
}

Write-Host "`nDone."
