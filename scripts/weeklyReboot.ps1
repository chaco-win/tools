$taskName = "Weekly_Update_Reboot"
$description = "Checks for and installs updates, then reboots every Sunday at 11:30 PM"
$logFolder = "C:\.Logs"
$logFile = "$logFolder\WeeklyUpdateLog.txt"

# Create the hidden log folder if it doesn't exist
if (!(Test-Path -Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
    Set-ItemProperty -Path $logFolder -Name Attributes -Value ([System.IO.FileAttributes]::Hidden)
}

# Create or append to the log file
if (Test-Path -Path $logFile) {
    Add-Content -Path $logFile -Value ("`n" + (Get-Date) + ": Script was run and log file already existed.")
} else {
    Set-Content -Path $logFile -Value ("Log file created by script on: " + (Get-Date))
}

# Inline PowerShell command the scheduled task will run
$inlineCommand = @"
Add-Content -Path '$logFile' -Value ('`n' + (Get-Date) + ': Starting Windows Update...')
Install-Module PSWindowsUpdate -Force -Scope CurrentUser
Import-Module PSWindowsUpdate
\$updateResults = Install-WindowsUpdate -AcceptAll -IgnoreReboot
if (\$updateResults) {
    Add-Content -Path '$logFile' -Value ('`n' + (Get-Date) + ': Updates installed:')
    foreach (\$update in \$updateResults) {
        Add-Content -Path '$logFile' -Value ('- ' + \$update.Title + ' (' + \$update.Result + ')')
    }
} else {
    Add-Content -Path '$logFile' -Value ('`n' + (Get-Date) + ': No updates were available.')
}
Add-Content -Path '$logFile' -Value ('`n' + (Get-Date) + ': Rebooting now...')
Restart-Computer -Force
"@

# Define the task action
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command `$`"$inlineCommand`$`""

# Define the weekly trigger (Sunday at 11:30 PM)
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 11:30PM

# Settings to allow wake from sleep and run on battery
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -WakeToRun

# Check for existing task
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Add-Content -Path $logFile -Value ("`n" + (Get-Date) + ": Task '$taskName' already exists.")
    Add-Content -Path $logFile -Value ("This task runs every Sunday at 11:30 PM. It installs all available Windows Updates, logs each one with result, and reboots the computer. The task wakes the PC if it's asleep.")
} else {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description $description -User "SYSTEM" -RunLevel Highest
    Add-Content -Path $logFile -Value ("`n" + (Get-Date) + ": Scheduled task '$taskName' created successfully.")
    Add-Content -Path $logFile -Value ("This task runs every Sunday at 11:30 PM. It installs all available Windows Updates, logs each one with result, and reboots the computer. The task wakes the PC if it's asleep.")
}

# Pause so you can see output during testing
Read-Host -Prompt "Press Enter to exit"
