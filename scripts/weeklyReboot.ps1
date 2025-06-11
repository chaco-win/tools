$taskName = "Weekly_Update_Reboot"
$description = "Checks for and installs updates, then reboots every Sunday at 11:30 PM"
$logFolder = "C:\AITS\Logs"
$logFile = "$logFolder\WeeklyUpdateLog.txt"

# Create the log folder if it doesn't exist
if (!(Test-Path -Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force
}

# Create or append to the log file
if (Test-Path -Path $logFile) {
    Add-Content -Path $logFile -Value ("`n" + (Get-Date) + ": Script was run and log file already existed.")
} else {
    Set-Content -Path $logFile -Value ("Log file created by script on: " + (Get-Date))
}

# Create the action
$actionCommand = @"
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

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command `$`"$actionCommand`$`""

# Create the trigger
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 11:30PM

# Create settings to wake the computer
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -WakeToRun

# Remove existing task if it exists
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Add-Content -Path $logFile -Value ("`n" + (Get-Date) + ": Existing scheduled task removed.")
}

# Register the new task
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description $description -User "SYSTEM" -RunLevel Highest
Add-Content -Path $logFile -Value ("`n" + (Get-Date) + ": Scheduled task created successfully.")
