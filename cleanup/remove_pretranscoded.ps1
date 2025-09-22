param (
    [Parameter(Mandatory=$true)]
    [string]$i,                # Input folder

    [Parameter(Mandatory=$true)]
    [string]$r,                # Resolution to keep (ex: 1440p)

    [Parameter(Mandatory=$true)]
    [string]$a,                # Audio channels to keep (ex: 5.1)

    [switch]$WhatIf            # Test mode
)

Write-Host "Cleaning: $i"
Write-Host "Target: [$r $a]"
Write-Host ""

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
            if (-not $WhatIf) {
                Remove-Item -LiteralPath $f.File.FullName -Force
            }
        }
        else {
            Write-Host " KEEP   $($f.Name)   (no block)" -ForegroundColor Yellow
        }
    }
}

Write-Host "`nDone."
