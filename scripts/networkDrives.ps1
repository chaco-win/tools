# networkDrives.ps1

# Fixed list of commonly used drives
$knownDrives = @{
    'O' = '\\capsov\shares\ecTDOffice'
    'Q' = '\\capsov\Shares\StabilitySystem'
    'S' = '\\capsov.local\Shares\SharedFiles'
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
        net use $driveLetter /delete /y | Out-Null

        try {
            New-PSDrive -Name $drive.Name -PSProvider FileSystem -Root $drivePath -Persist
            Write-Host "Drive $driveLetter re-mapped successfully to $drivePath"
        } catch {
            Write-Warning "Failed to re-map $driveLetter to $drivePath. Error: $_"
        }
    } else {
        Write-Host "Drive $driveLetter is still connected."
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
        New-PSDrive -Name $letter -PSProvider FileSystem -Root $path -Persist
        Write-Host "Drive $letter: mapped successfully to $path"
    } catch {
        Write-Warning "Failed to map drive $letter: to $path. Error: $_"
    }

    $addDrives = Read-Host "Do you want to add another drive? (Y/N)"
}
