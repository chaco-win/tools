# FullSystemCleanup.ps1

#Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Relaunching as Administrator..." -ForegroundColor Yellow
    $script = $MyInvocation.MyCommand.Definition
    $localTemp = Join-Path $env:TEMP ([IO.Path]::GetFileName($script))
    Copy-Item -Path $script -Destination $localTemp -Force
    Start-Process -FilePath "powershell.exe" -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$localTemp) -Verb RunAs -ErrorAction Stop
    exit
}


# Prepare logging directory and start transcript

# Prepare log & scanLogs folders
$logDir     = 'C:\.Logs'
$scanLogDir = Join-Path $logDir 'scanLogs'
if (-not (Test-Path $scanLogDir)) {
    New-Item -ItemType Directory -Path $scanLogDir -Force | Out-Null
}

# Start logging to a file (not a folder) in scanLogs
$timestamp = Get-Date -Format 'MM-dd-yy_HH-mm-ss'
$logFile   = Join-Path $scanLogDir "${timestamp}.txt"
Start-Transcript -Path $logFile

# --------- PART 1: Disable Adobe-related Scheduled Tasks ---------
$keywords = @("Adobe", "Creative Cloud")
$tasks = Get-ScheduledTask
$matchedTasks = $tasks | Where-Object {
    $match = $false
    foreach ($keyword in $keywords) {
        if ($_.TaskName -like "*$keyword*" -or $_.TaskPath -like "*$keyword*") {
            $match = $true
            break
        }
    }
    return $match
}
foreach ($task in $matchedTasks) {
    try {
        Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath
        Write-Host "Disabled: $($task.TaskPath)$($task.TaskName)"
    } catch {
        Write-Warning "Failed to disable: $($task.TaskPath)$($task.TaskName)"
    }
}

# --------- PART 2: Disable WavesSysSvc Service ---------
$waveService = "WavesSysSvc"
if (Get-Service -Name $waveService -ErrorAction SilentlyContinue) {
    Stop-Service -Name $waveService -Force
    Set-Service -Name $waveService -StartupType Disabled
    Write-Host "Service '$waveService' has been stopped and disabled."
} else {
    Write-Host "Service '$waveService' not found."
}

# --------- PART 3: Set Specific Services to Manual Startup ---------
$services = @( 'DiagTrack', 'dmwappushservice', 'WMPNetworkSvc', 'Fax', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc', 'XboxLiveAuthManager', 'XboxLiveGameSave', 'MapsBroker', 'PrintWorkflowUserSvc', 'RetailDemo', 'SharedAccess', 'WSearch', 'W32Time', 'WerSvc', 'PcaSvc' )
foreach ($service in $services) {
    try {
        Write-Host "Setting $service to Manual..." -ForegroundColor Yellow
        Set-Service -Name $service -StartupType Manual
    } catch {
        Write-Host "Failed to set $service. It might not exist on this system." -ForegroundColor Red
    }
}

# Disable IPv6 if enabled
Write-Host "`nChecking if IPv6 is Disabled..." -ForegroundColor Yellow
$ipv6Bindings = Get-NetAdapterBinding -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
$enabledBindings = $ipv6Bindings | Where-Object Enabled
if ($enabledBindings.Count -gt 0) {
    Write-Host "Found $($enabledBindings.Count) adapter(s) with IPv6 enabled. Disabling now..." -ForegroundColor Green
    Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6
    Write-Host "IPv6 bindings have been disabled." -ForegroundColor Green
} else {
    Write-Host "IPv6 was already disabled prior to running this script." -ForegroundColor White
}

# --------- PART 4: Checking for Any Available Updates ---------
Write-Host "`n=== Checking for Any Available Updates (excluding drivers) ===" -ForegroundColor Cyan
# Ensure PSWindowsUpdate is installed
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "PSWindowsUpdate module not found. Installing..." -ForegroundColor Yellow
    Try {
        Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -Confirm:$false | Out-Null
        Write-Host "PSWindowsUpdate installed successfully." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to install PSWindowsUpdate: $_" -ForegroundColor Red
        return
    }
}
# Import PSWindowsUpdate
Try {
    Import-Module PSWindowsUpdate -ErrorAction Stop
} Catch {
    Write-Host "Unable to import PSWindowsUpdate. Skipping update check." -ForegroundColor Red
    return
}
# Fetch all available updates, excluding driver updates
$allUpdates = Get-WindowsUpdate -AcceptAll -IgnoreReboot -NotCategory "Drivers" -ErrorAction SilentlyContinue
if ($allUpdates -and $allUpdates.Count -gt 0) {
    Write-Host "Installing all available updates (excluding drivers)..." -ForegroundColor Cyan
    foreach ($u in $allUpdates) {
        Write-Host "Installing: $($u.Title)" -ForegroundColor Yellow
        Try {
            Install-WindowsUpdate -KBArticleID $u.KBArticleIDs -AcceptAll -IgnoreReboot -Confirm:$false | Out-Null
        } Catch {
            Write-Warning "Failed to install update $($u.KBArticleIDs): $_"
        }
    }
    Write-Host "All updates installed (excluding drivers). No reboot yet." -ForegroundColor Green
} else {
    Write-Host "No updates found (excluding drivers)." -ForegroundColor Green
}

# --------- PART 5: Offline Files cache usage ---------
Write-Host "`nChecking Offline Files cache usage..." -ForegroundColor Cyan
try {
    $regPathCache = 'HKLM:\SYSTEM\CurrentControlSet\Services\CSC\Parameters'
    $currentValue = (Get-ItemProperty -Path $regPathCache -Name 'CacheSizePercent' -ErrorAction SilentlyContinue).CacheSizePercent
    Write-Host "Current cache percent: $currentValue%" -ForegroundColor Yellow
    if ($currentValue -ne 40) {
        Write-Host "Setting Offline Files cache limit to 40% of disk..." -ForegroundColor Yellow
        New-ItemProperty -Path $regPathCache -Name 'CacheSizePercent' -Value 40 -PropertyType DWord -Force | Out-Null
        Write-Host "Offline Files cache limit set to 40%." -ForegroundColor Green
    } else {
        Write-Host "Offline Files cache limit is already 40%." -ForegroundColor Green
    }
} catch {
    Write-Host "Error configuring Offline Files cache limit: $_" -ForegroundColor Red
}

# --------- PART 6: Click-to-Run service ---------
Write-Host "`nSetting Click-to-Run Service to Manual..." -ForegroundColor Cyan
$serviceName = 'ClickToRunSvc'
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "Current service status: $($service.Status)" -ForegroundColor Yellow
    Set-Service -Name $serviceName -StartupType Manual
    if ($service.Status -ne 'Stopped') { Stop-Service -Name $serviceName -Force }
    Write-Host "Service '$serviceName' set to Manual and stopped." -ForegroundColor Green
} else {
    Write-Host "Service '$serviceName' not found." -ForegroundColor Gray
}

# --------- PART 7: Disable Windows Copilot at Startup ---------
Write-Host "`nDisabling Windows Copilot at Startup..." -ForegroundColor Cyan
$regPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
New-ItemProperty -Path $regPath -Name 'TurnOffWindowsCopilot' -Value 1 -PropertyType DWord -Force | Out-Null
Write-Host "Windows Copilot disabled via registry." -ForegroundColor Green

# --------- PART 8: Scheduling Memory Test and Forced Reboot at 1 AM ---------
Write-Host "Scheduling memory test and forced reboot for 1:00 AM tonight..." -ForegroundColor Cyan
$taskName = "MemoryTestAndRebootAt1AM"
$runTime  = (Get-Date).Date.AddDays(1).AddHours(1)  # 1 AM tomorrow
# Remove existing task if present
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}
# Create actions: memory test then reboot
$action1 = New-ScheduledTaskAction -Execute 'mdsched.exe'  -Argument '/auto'
$action2 = New-ScheduledTaskAction -Execute 'shutdown.exe' -Argument '/r /f /t 0'
# Create trigger
$trigger = New-ScheduledTaskTrigger -Once -At $runTime
# Register task with both actions in one line
Register-ScheduledTask -TaskName $taskName -Action @($action1, $action2) -Trigger $trigger -Description "Run memory test then reboot at 1 AM" -User "SYSTEM" -RunLevel Highest -Force
Write-Host "Scheduled memory test and forced reboot at 1:00 AM tonight." -ForegroundColor Green

# --------- PART 9: System Scans ---------
Write-Host "`n=== System Scans ===" -ForegroundColor Cyan
# CHKDSK online scan
Write-Host "Running CHKDSK online scan..." -ForegroundColor Yellow
$summary = chkdsk C: /scan 2>&1 | Select-Object -Last 15
$summary | ForEach-Object { Write-Host $_ }
if ($summary -match 'error occurred') {
    Write-Host "CHKDSK reported an error occurred. Scheduling repair at next boot..." -ForegroundColor Red
    cmd.exe /c "echo Y | chkdsk C: /F /R /X" | Out-Null
    Write-Host "Repair scheduled." -ForegroundColor Green
}

# SFC and DISM scans
Write-Host "`nSFC - First Scan" -ForegroundColor Yellow
sfc /scannow
Write-Host "`nDISM Health Restore" -ForegroundColor Yellow
$proc = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online","/Cleanup-Image","/RestoreHealth" -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0) { Write-Host "DISM failed with exit code $($proc.ExitCode)." -ForegroundColor Red } else { Write-Host "DISM completed successfully." -ForegroundColor Green }
Write-Host "`nSFC - Second Scan" -ForegroundColor Yellow
sfc /scannow

# --------- PART 10: Restore Point ---------
try {
    Write-Host "Enabling System Restore on C:..."
    Enable-ComputerRestore -Drive "C:\"
    Start-Sleep -Seconds 2
    Write-Host "Setting ShadowStorage size to 10%..."
    vssadmin Resize ShadowStorage /For=C: /On=C: /MaxSize=10%
    Write-Host "Creating Post-script restore point..."
    Checkpoint-Computer -Description "Post-script Restore Point" -RestorePointType "MODIFY_SETTINGS"
    Write-Host "Restore point created." -ForegroundColor Green
} catch {
    Write-Warning "Something went wrong: $_"
}

# --------- FINAL: Exit Prompt ---------
Write-Host "`n========================================" -ForegroundColor Blue
Write-Host "===== Script Complete ====="            -ForegroundColor Blue
Write-Host "========================================`n" -ForegroundColor Blue

# Wait for user input before exiting
Read-Host -Prompt "Press Enter to close this window"

# Stop transcript
Stop-Transcript
