# launcher.ps1 (Auto-discover version for chaco-win/tools repo)

$baseUrl = "https://raw.githubusercontent.com/chaco-win/tools/main/"
$apiUrl = "https://api.github.com/repos/chaco-win/tools/contents/"

try {
    # Fetch file list from GitHub API
    $files = Invoke-RestMethod -Uri $apiUrl

    # Filter only .ps1 files
    $ps1Files = $files | Where-Object { $_.name -like "*.ps1" }

    if ($ps1Files.Count -eq 0) {
        Write-Host "No PowerShell scripts found!" -ForegroundColor Red
        exit
    }

    # Display script options
    Write-Host "`nSelect a script to run:" -ForegroundColor Cyan
    for ($i=0; $i -lt $ps1Files.Count; $i++) {
        Write-Host "[$($i+1)] $($ps1Files[$i].name)"
    }

    # Get user choice
    $selection = Read-Host "`nEnter the number of the script to run"
    if (-not ($selection -match '^\d+$') -or $selection -lt 1 -or $selection -gt $ps1Files.Count) {
        Write-Warning "Invalid selection. Exiting."
        exit
    }

    $chosenScript = $ps1Files[$selection - 1].name
    $scriptUrl = "$baseUrl$chosenScript"

    Write-Host "`nRunning $chosenScript from GitHub..." -ForegroundColor Green
    Invoke-Expression (Invoke-RestMethod -Uri $scriptUrl)
} catch {
    Write-Warning "Error: $_"
}
