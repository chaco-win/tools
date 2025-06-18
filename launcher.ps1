

# launcher.ps1 — Branch-Aware Dynamic Launcher with Elevation, Policy Bypass, and Looping Execution

# 0) Define the branch to use ("main" or "beta")
$branch = 'beta'  # Change this to 'main' for production

# 1) Bypass execution policy for this session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# 2) Self-elevation — ensure running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Relaunching as Administrator..." -ForegroundColor Yellow
    # Re-launch this launcher under admin privileges, pointing to same branch
    $launcherUrl = "https://raw.githubusercontent.com/chaco-win/tools/$branch/launcher.ps1"
    $cmd = "iex (irm '$launcherUrl')"
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy','Bypass',
        '-Command', $cmd
    ) -Wait
    exit
}

# 3) Main loop: fetch, list, execute, ask to repeat
$baseUrl = "https://raw.githubusercontent.com/chaco-win/tools/$branch/scripts/"
$apiUrl  = "https://api.github.com/repos/chaco-win/tools/contents/scripts?ref=$branch"

try {
    do {
        # Fetch and filter scripts in specified branch
        $files    = Invoke-RestMethod -Uri $apiUrl
        $ps1Files = $files | Where-Object { $_.name -like '*.ps1' }

        if ($ps1Files.Count -eq 0) {
            Write-Host "No PowerShell scripts found in 'scripts/' on branch '$branch'!" -ForegroundColor Red
            break
        }

        # Display options
        Write-Host "`nSelect a script to run from 'scripts/' on branch '$branch':" -ForegroundColor Cyan
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
        Write-Host "`nLaunching $chosenScript from branch '$branch'..." -ForegroundColor Green
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

