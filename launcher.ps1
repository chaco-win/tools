# launcher.ps1 — Updated with Self-Elevation & Policy Bypass

# 1) Bypass execution policy for this session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# 2) Self-elevation — ensure running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Relaunching as Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy','Bypass',
        '-Command',
        "irm 'https://raw.githubusercontent.com/chaco-win/tools/main/launcher.ps1'|iex"
    ) -ErrorAction Stop
    exit
}

# 3) Dynamic script discovery & execution
$baseUrl = "https://raw.githubusercontent.com/chaco-win/tools/main/"
$apiUrl  = "https://api.github.com/repos/chaco-win/tools/contents/"

try {
    # Fetch directory listing
    $files = Invoke-RestMethod -Uri $apiUrl

    # Filter only PowerShell scripts
    $ps1Files = $files | Where-Object { $_.name -like "*.ps1" }
    if ($ps1Files.Count -eq 0) {
        Write-Host "No PowerShell scripts found!" -ForegroundColor Red
        exit
    }

    # Prompt user for selection
    Write-Host "`nSelect a script to run:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $ps1Files.Count; $i++) {
        Write-Host "[$($i+1)] $($ps1Files[$i].name)"
    }

    $selection = Read-Host "`nEnter the number of the script to run"
    if (-not ($selection -match '^[0-9]+$') -or $selection -lt 1 -or $selection -gt $ps1Files.Count) {
        Write-Warning "Invalid selection. Exiting."
        exit
    }

    # Download and execute the chosen script
    $chosenScript = $ps1Files[$selection - 1].name
    $scriptUrl    = "$baseUrl$chosenScript"

    Write-Host "`nRunning $chosenScript from GitHub..." -ForegroundColor Green
    Invoke-Expression (Invoke-RestMethod -Uri $scriptUrl)
}
catch {
    Write-Warning "Error: $_"
}
