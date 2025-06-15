# ------- START SCRIPT -------

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Prevent progress and error paging from causing script pauses
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

# Self-elevation — ensure running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Relaunching as Administrator..." -ForegroundColor Yellow
    $script = $MyInvocation.MyCommand.Definition
    $localTemp = Join-Path $env:TEMP ([IO.Path]::GetFileName($script))
    Copy-Item -Path $script -Destination $localTemp -Force
    Start-Process -FilePath "powershell.exe" -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$localTemp) -Verb RunAs -ErrorAction Stop
    exit
}

# --- LOGGING SETUP ---
$logFolder = 'C:\.Logs'
$logFile = "$logFolder\CleanupLog.txt"

if (!(Test-Path -Path $logFolder)) {
    try {
        $logDir = New-Item -ItemType Directory -Path $logFolder -Force
        $logDir.Attributes = 'Hidden'
        Write-Host "Created hidden log folder: $logFolder"
    } catch {
        Write-Host "ERROR: Could not create log folder: $logFolder"
        Write-Host $_.Exception.Message
        exit 1
    }
}

try {
    Add-Content -Path $logFile -Value ("Test log entry at: {0}" -f (Get-Date))
    Write-Host "Wrote test entry to: $logFile"
} catch {
    Write-Host "ERROR: Could not write to log file: $logFile"
    Write-Host $_.Exception.Message
    exit 1
}

# --- START CLEANUP ---
$startTime = Get-Date
Write-Host "`nCleanup started at: $startTime"
Add-Content -Path $logFile -Value ("Cleanup started at: {0}" -f $startTime)

$drive = "C:"
$startFree = (Get-PSDrive -Name ($drive.TrimEnd(":"))).Free
Write-Host "`nStarting free space on ${drive}: $([math]::Round(($startFree / 1GB), 2)) GB"
Add-Content -Path $logFile -Value ("Space before: {0} GB" -f ([math]::Round(($startFree / 1GB), 2)))

Write-Host "`n--- Starting Comprehensive Cleanup Script ---"

# Disable hibernation to delete hiberfil.sys
Write-Host "`nDisabling hibernation (deletes hiberfil.sys)..."
powercfg -h off

# Clean system-wide temp files
Write-Host "`nCleaning C:\Windows\Temp..."
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

# Clean Windows Update cache
Write-Host "`nCleaning C:\Windows\SoftwareDistribution\Download..."
Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

# Run DISM to clean WinSxS (non-interactive)
Write-Host "`nRunning WinSxS cleanup with DISM..."
Start-Process -FilePath "dism.exe" -ArgumentList "/Online","/Cleanup-Image","/StartComponentCleanup","/ResetBase" -NoNewWindow -Wait

# Clean per-user profiles
$excludedProfiles = @("Public", "Default", "Default User", "All Users")
$usersRoot = "C:\Users"
$profiles = Get-ChildItem -Path $usersRoot -Directory | Where-Object { $_.Name -notin $excludedProfiles }

$totalProfiles = $profiles.Count
$processed = 0

foreach ($profile in $profiles) {
    $processed++
    $percent = [math]::Round(($processed / $totalProfiles) * 100)
    Write-Progress -Activity "Cleaning Profiles" -Status "Cleaning $($profile.Name)" -PercentComplete $percent

    Write-Host "`nProcessing user profile: $($profile.Name)"

    # Temp
    $tempPath = Join-Path -Path $profile.FullName -ChildPath "AppData\Local\Temp"
    if (Test-Path -Path $tempPath) {
        Write-Host "  Cleaning temp folder..."
        try {
            Remove-Item -Path "$tempPath\*" -Recurse -Force -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Host "  Temp cleaned: $tempPath"
        } catch {
            Write-Host "  Skipped some files in: $tempPath (likely already gone)"
        }
    } else {
        Write-Host "  Temp folder not found."
    }

    # Microsoft AppData
    $microsoftFolderPath = Join-Path -Path $profile.FullName -ChildPath "AppData\Local\Microsoft"
    if (Test-Path -Path $microsoftFolderPath) {
        Write-Host "  Cleaning Microsoft AppData..."
        takeown /f "$microsoftFolderPath" /r /d y | Out-Null
        icacls "$microsoftFolderPath" /grant administrators:F /t | Out-Null
        try {
            Remove-Item -Path $microsoftFolderPath -Recurse -Force -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Host "  Microsoft AppData cleaned: $microsoftFolderPath"
        } catch {
            Write-Host "  Skipped some files in: $microsoftFolderPath (likely already gone)"
        }
    } else {
        Write-Host "  Microsoft folder not found."
    }
}

# Clear progress
Write-Progress -Activity "Cleaning Profiles" -Completed

# Final reporting
$endTime = Get-Date
$duration = $endTime - $startTime
$endFree = (Get-PSDrive -Name ($drive.TrimEnd(":"))).Free
$spaceFreed = $endFree - $startFree

Write-Host "`nCleanup completed at: $endTime"
Write-Host "Total duration: $($duration.ToString())"
Write-Host "`nEnding free space on ${drive}: $([math]::Round(($endFree / 1GB), 2)) GB"
Write-Host "Total space reclaimed: $([math]::Round(($spaceFreed / 1GB), 2)) GB"

Add-Content -Path $logFile -Value ("Space after: {0} GB" -f ([math]::Round(($endFree / 1GB), 2)))
Add-Content -Path $logFile -Value ("Total reclaimed: {0} GB" -f ([math]::Round(($spaceFreed / 1GB), 2)))
Add-Content -Path $logFile -Value ("Cleanup completed at: {0}" -f $endTime)
Add-Content -Path $logFile -Value ("Total duration: {0}" -f $duration)
Add-Content -Path $logFile -Value ("---`n")

Write-Host "`nCleanup log saved to: $logFile"

# ------- END SCRIPT -------
