# networkDrives.ps1

# Fixed list of commonly used drives
$knownDrives = @{
    'O' = '\\capsov\shares\ecTDOffice'
    'Q' = '\\capsov\Shares\StabilitySystem'
    'S' = '\\capsov.local\Shares\SharedFiles'
}

# Create log directory and log file
$logDir = 'C:\.Logs'
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory | Out-Null
}
$logFile = "$logDir\drive_mapping.log"

Function Log-Message($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp`t$message" | Out-File -FilePath $logFile -Append
}

# Get currently mapped drives
$currentDrives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -like '\\*' }
$currentDriveLetters = $currentDrives.Name

# Check existing mapped drives for connectivity
foreach ($drive in $currentDrives) {
    $driveLetter = $drive.Name + ":"
    $drivePath = $drive.Root

    if (-not (Test-Path $driveLetter)) {
        Write-Host "Drive $driveLetter is disconnected. Removing and re-mapping."
        Log-Message "Drive $driveLetter is disconnected. Removing."
        net use $driveLetter /delete /y | Out-Null

        try {
            net use $driveLetter $drivePath /persistent:yes | Out-Null
            Write-Host "Drive $driveLetter re-mapped successfully to $drivePath"
            Log-Message "Drive $driveLetter re-mapped successfully to $drivePath"
        } catch {
            Write-Warning "Failed to re-map $driveLetter to $drivePath. Error: $_"
            Log-Message "ERROR: Failed to re-map $driveLetter to $drivePath. $_"
        }
    } else {
        Write-Host "Drive $driveLetter is still connected."
        Log-Message "Drive $driveLetter is still connected."
    }
}

# Prompt to add known or custom drives after disconnected drives are handled
$addDrives = Read-Host "Do you want to add a network drive? (Y/N)"

while ($addDrives -eq 'Y') {
    Write-Host "Available predefined drives to add:"
    foreach ($key in $knownDrives.Keys) {
        Write-Host " - Drive $key:`t$($knownDrives[$key])"
    }

    $letter = Read-Host "Enter the drive letter you want to add (from above or new)"
    if ($knownDrives.ContainsKey($letter)) {
        $path = $knownDrives[$letter]
    } else {
        $path = Read-Host "Enter network path for drive letter $letter (e.g., \\server\share)"
    }

    try {
        if (-not (Get-PSDrive -Name $letter -ErrorAction SilentlyContinue)) {
            net use $letter $path /persistent:yes | Out-Null
            Write-Host "Drive $letter: mapped successfully to $path"
            Log-Message "Drive $letter: mapped successfully to $path"
        } else {
            Write-Warning "Drive $letter already exists."
            Log-Message "WARNING: Drive $letter already exists."
        }
    } catch {
        Write-Warning "Failed to map drive $letter: to $path. Error: $_"
        Log-Message "ERROR: Failed to map drive $letter: to $path. $_"
    }

    $addDrives = Read-Host "Do you want to add another drive? (Y/N)"
}

# Prevent window from closing immediately
Read-Host -Prompt "Press Enter to exit"
