

# 3) Main loop: list, execute, ask to repeat
$baseUrl = "https://raw.githubusercontent.com/chaco-win/tools/main/scripts/"
$apiUrl  = "https://api.github.com/repos/chaco-win/tools/contents/scripts"

try {
    do {
        # Fetch and filter scripts
        $files    = Invoke-RestMethod -Uri $apiUrl
        $ps1Files = $files | Where-Object { $_.name -like '*.ps1' }

        if ($ps1Files.Count -eq 0) {
            Write-Host "No PowerShell scripts found in 'scripts/'!" -ForegroundColor Red
            break
        }

        # Display options
        Write-Host "`nSelect a script to run from 'scripts' folder:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $ps1Files.Count; $i++) {
            Write-Host "[$($i+1)] $($ps1Files[$i].name)"
        }

        # Read selection
        $selection = Read-Host "`nEnter the number of the script to run"
        if (-not ($selection -match '^[0-9]+$') -or $selection -lt 1 -or $selection -gt $ps1Files.Count) {
            Write-Warning "Invalid selection. Exiting loop."
            break
        }

        # Execute chosen script in new process
        $chosenScript = $ps1Files[$selection - 1].name
        $scriptUrl    = "$baseUrl$chosenScript"
        Write-Host "`nLaunching $chosenScript..." -ForegroundColor Green
        Start-Process powershell.exe -ArgumentList @(
            '-NoProfile',
            '-ExecutionPolicy','Bypass',
            '-Command', "iex (irm '$scriptUrl')"
        ) -Wait

        # Prompt to run again
        $answer = Read-Host "`n$chosenScript completed. Run another script? (y/n)"
    } while ($answer -match '^[Yy]')
}
catch {
    Write-Warning "Error fetching script list: $_"
}
