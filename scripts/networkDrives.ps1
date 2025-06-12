# networkDrives.ps1

# Fixed list of commonly used drives
$knownDrives = @{
    'O' = '\\capsov\shares\ecTDOffice'
    'Q' = '\\capsov\Shares\StabilitySystem'
    'S' = '\\capsov.local\Shares\SharedFiles'
}

# Ensure error list is clear
$error.Clear()

# Create log directory and log file
$logDir = 'C:\.Logs'
if (-not (Test-Path $logDir)) {
    try {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    } catch {
        Write-Host "Failed to create log directory at $logDir."
        Read-Host -Prompt "Press Enter to exit"
        exit
    }
}
$logFile = "$logDir\drive_mapping.log"

Function Log-Message($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp`t$message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# Log session start
Log-Message "--- New Script Run ---"

# Get currently mapped drives
$currentDrives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -like '\\*' }
$currentDriveLetters = $currentDrives.Name

# Check existing mapped drives for connectivity
Write-Host "`n--- Drive Status Report ---"
foreach ($drive in $currentDrives) {
    $driveLetter = $drive.Name + ":"
    $drivePath = $drive.Root

    if (-not (Test-Path $driveLetter)) {
        Write-Host "Drive $driveLetter is disconnected. Removing and re-mapping."
        Log-Message "Drive $driveLetter is disconnected. Removing."
        net use $driveLetter /delete /y | Out-Null

        $exitCode = (Start-Process -FilePath "net" -ArgumentList "use $driveLetter $drivePath /persistent:yes" -NoNewWindow -Wait -PassThru).ExitCode

        if ($exitCode -eq 0) {
            Write-Host "Drive $driveLetter re-mapped successfully to $drivePath"
            Log-Message "Drive $driveLetter re-mapped successfully to $drivePath"
        } else {
            Write-Warning "Failed to re-map $driveLetter to $drivePath. ExitCode: $exitCode"
            Log-Message "ERROR: Failed to re-map $driveLetter to $drivePath. ExitCode: $exitCode"
        }
    } else {
        Write-Host "Drive $driveLetter is connected to $drivePath."
        Log-Message "Drive $driveLetter is connected to $drivePath."
    }
}

# Prompt to add known or custom drives after disconnected drives are handled
$addDrives = Read-Host "Do you want to add a network drive? (Y/N)"

while ($addDrives -eq 'Y') {
    Write-Host "Available predefined drives to add:"
    foreach ($key in $knownDrives.Keys) {
        Write-Host " - Drive ${key}:`t$($knownDrives[$key])"
    }

    $letter = Read-Host "Enter the drive letter you want to add (from above or new)"
    if ($knownDrives.ContainsKey($letter)) {
        $path = $knownDrives[$letter]
    } else {
        $path = Read-Host "Enter network path for drive letter $letter (e.g., \\server\share)"
    }

    # Remove and re-map if it already exists
    if (Get-PSDrive -Name $letter -ErrorAction SilentlyContinue) {
        Write-Host "Drive ${letter}: already exists. Removing and re-mapping."
        Log-Message "Drive ${letter}: already exists. Removing."
        net use ${letter}: /delete /y | Out-Null
    }

    $exitCode = (Start-Process -FilePath "net" -ArgumentList "use ${letter}: $path /persistent:yes" -NoNewWindow -Wait -PassThru).ExitCode

    if ($exitCode -eq 0) {
        Write-Host "Drive ${letter}: mapped successfully to $path"
        Log-Message "Drive ${letter}: mapped successfully to $path"
    } else {
        Write-Warning "Failed to map drive ${letter}: to $path. ExitCode: $exitCode"
        Log-Message "ERROR: Failed to map drive ${letter}: to $path. ExitCode: $exitCode"
    }

    $addDrives = Read-Host "Do you want to add another drive? (Y/N)"
}

Write-Host "`n--- Drive Mapping Complete ---"

# Summary output
if ($error.Count -gt 0) {
    Write-Host "`nOne or more PowerShell errors occurred (see log for net use errors):"
    $error | ForEach-Object { Write-Host " - $_" }
} else {
    Write-Host "`nAll operations completed successfully."
}
Read-Host -Prompt "Press Enter to close"
