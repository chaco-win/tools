# launcher.ps1 — Dynamic Launcher with Elevation, Policy Bypass, and External Execution

# 1) Bypass execution policy for this session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# 2) Self-elevation — ensure running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Relaunching as Administrator..." -ForegroundColor Yellow
    # Re-launch this launcher under admin privileges
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy','Bypass',
        '-Command', "iex (irm 'https://raw.githubusercontent.com/chaco-win/tools/main/launcher.ps1')"
    ) -Wait
    exit
}

# 3) Dynamic script discovery & user selection from /scripts folder
$baseUrl = "https://raw.githubusercontent.com/chaco-win/tools/main/scripts/"
$apiUrl  = "https://api.github.com/repos/chaco-win/tools/contents/scripts"

try {
    $files = Invoke-RestMethod -Uri $apiUrl
    $ps1Files = $files | Where-Object { $_.name -like '*.ps1' }

    if ($ps1Files.Count -eq 0) {
        Write-Host "No PowerShell scripts found in 'scripts/'!" -ForegroundColor Red
        exit
    }

    Write-Host "`nSelect a script to run from 'scripts/' folder:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $ps1Files.Count; $i++) {
        Write-Host "[$($i+1)] $($ps1Files[$i].name)"
    }

    $selection = Read-Host "`nEnter the number of the script to run"
    if (-not ($selection -match '^[0-9]+$') -or $selection -lt 1 -or $selection -gt $ps1Files.Count) {
        Write-Warning "Invalid selection. Exiting."
        exit
    }

    $chosenScript = $ps1Files[$selection - 1].name
    $scriptUrl    = "$baseUrl$chosenScript"

    Write-Host "`nLaunching $chosenScript in a separate PowerShell process..." -ForegroundColor Green

    # Run the selected script in its own process so launcher stays open
    Start-Process powershell.exe -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy','Bypass',
        '-Command', "iex (irm '$scriptUrl')"
    ) -Wait

    Write-Host "`n$chosenScript completed. Press Enter to exit launcher." -ForegroundColor Cyan
    Read-Host | Out-Null
}
catch {
    Write-Warning "Error fetching script list: $_"
}
