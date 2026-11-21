<#
  Power Up the Windows Terminal: one-step installer.

  Installs PowerShell 7, Oh My Posh, the IosevkaTerm Nerd Font and the
  jandedobbeleer prompt, writes your PowerShell profile, and sets up
  Windows Terminal. Safe to run again: it backs up anything it changes.

  Run from any PowerShell window (Windows PowerShell 5.1 is fine):

    irm https://raw.githubusercontent.com/andrewpayne68/windows-terminal-ohmyposh/main/install.ps1 | iex

  Or from a clone of the repo:  .\install.ps1
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$RepoRaw   = 'https://raw.githubusercontent.com/andrewpayne68/windows-terminal-ohmyposh/main'
$FontFile  = 'IosevkaTermNerdFontMono-Regular.ttf'
$FontName  = 'IosevkaTerm Nerd Font Mono'
$ThemeFile = 'jandedobbeleer.omp.json'
$Stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
$LocalRepo = if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot $ThemeFile))) { $PSScriptRoot } else { $null }

function Write-Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "    $text" -ForegroundColor Green }
function Write-Note($text) { Write-Host "    $text" -ForegroundColor Yellow }

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Get-RepoFile($name, $dest) {
    if ($LocalRepo) {
        Copy-Item (Join-Path $LocalRepo $name) $dest -Force
    } else {
        Invoke-WebRequest -UseBasicParsing -Uri "$RepoRaw/$name" -OutFile $dest
    }
    Unblock-File $dest -ErrorAction SilentlyContinue
}

function Backup-File($path) {
    if (Test-Path $path) {
        $backup = "$path.bak-$Stamp"
        Copy-Item $path $backup -Force
        Write-Note "Backed up $path"
    }
}

function Install-WingetPackage($id, $exe) {
    Update-SessionPath
    if (Get-Command $exe -ErrorAction SilentlyContinue) {
        Write-Ok "$id is already installed"
        return
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "WinGet isn't available. See the README's WinGet section (Windows Server 2022), then run this again."
    }
    & winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
    Update-SessionPath
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) {
        throw "$id didn't install. Try: winget source reset --force (as admin), then run this again."
    }
    Write-Ok "$id installed"
}

function Set-JsonProp($obj, $name, $value) {
    if ($obj.PSObject.Properties[$name]) { $obj.$name = $value }
    else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

# Edits a Windows Terminal settings.json: font, default profile, start folder,
# copy on select and -nologo. Returns $false if the file can't be read as JSON.
function Update-TerminalSettings($path, $fontName) {
    $raw = Get-Content $path -Raw -Encoding UTF8
    try {
        $json = $raw | ConvertFrom-Json
    } catch {
        # Windows Terminal allows // comment lines; drop whole-line comments and retry.
        $stripped = ($raw -split "`r?`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
        try { $json = $stripped | ConvertFrom-Json } catch { return $false }
    }

    Set-JsonProp $json 'copyOnSelect' $true

    if (-not $json.PSObject.Properties['profiles']) { Set-JsonProp $json 'profiles' ([pscustomobject]@{}) }
    $profiles = $json.profiles
    if ($profiles -is [array]) {
        $profiles = [pscustomobject]@{ defaults = [pscustomobject]@{}; list = $profiles }
        $json.profiles = $profiles
    }
    if (-not $profiles.PSObject.Properties['defaults'] -or $null -eq $profiles.defaults) { Set-JsonProp $profiles 'defaults' ([pscustomobject]@{}) }
    $defaults = $profiles.defaults
    if (-not $defaults.PSObject.Properties['font'] -or $null -eq $defaults.font) { Set-JsonProp $defaults 'font' ([pscustomobject]@{}) }
    Set-JsonProp $defaults.font 'face' $fontName

    $pwshGuid = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
    if (-not $profiles.PSObject.Properties['list'] -or $null -eq $profiles.list) { Set-JsonProp $profiles 'list' @() }
    $pwsh = @($profiles.list) | Where-Object {
        $_.PSObject.Properties['source'] -and $_.source -eq 'Windows.Terminal.PowershellCore'
    } | Select-Object -First 1
    if (-not $pwsh) {
        $pwsh = @($profiles.list) | Where-Object { $_.PSObject.Properties['guid'] -and $_.guid -eq $pwshGuid } | Select-Object -First 1
    }
    if (-not $pwsh) {
        $pwsh = [pscustomobject]@{ guid = $pwshGuid; name = 'PowerShell'; source = 'Windows.Terminal.PowershellCore' }
        $profiles.list = @($profiles.list) + $pwsh
    }
    Set-JsonProp $pwsh 'hidden' $false
    Set-JsonProp $pwsh 'startingDirectory' '%USERPROFILE%'
    Set-JsonProp $pwsh 'commandline' 'pwsh.exe -nologo'
    Set-JsonProp $json 'defaultProfile' $pwsh.guid

    $out = $json | ConvertTo-Json -Depth 64
    [IO.File]::WriteAllText($path, $out, (New-Object Text.UTF8Encoding $false))
    return $true
}

# Lets the script be dot-sourced for testing without installing anything.
if ($env:WTOMP_NO_RUN -eq '1') { return }

Write-Host 'Power Up the Windows Terminal' -ForegroundColor Magenta

# 1. PowerShell 7 and Oh My Posh
Write-Step 'Installing PowerShell 7'
Install-WingetPackage 'Microsoft.PowerShell' 'pwsh'

Write-Step 'Installing Oh My Posh'
Install-WingetPackage 'JanDeDobbeleer.OhMyPosh' 'oh-my-posh'

# 2. Nerd Font, for the current user (no admin needed)
Write-Step "Installing the $FontName font"
$userFonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fontDest  = Join-Path $userFonts $FontFile
$fontKey   = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$systemHas = Test-Path (Join-Path $env:WINDIR "Fonts\$FontFile")
if ($systemHas -or (Test-Path $fontDest)) {
    Write-Ok 'Font is already installed'
} else {
    New-Item -ItemType Directory -Force $userFonts | Out-Null
    Get-RepoFile $FontFile $fontDest
    if (-not (Test-Path $fontKey)) { New-Item $fontKey -Force | Out-Null }
    New-ItemProperty -Path $fontKey -Name "$FontName Regular (TrueType)" -Value $fontDest -PropertyType String -Force | Out-Null
    Write-Ok 'Font installed'
}

# 3. Prompt theme in your home folder
Write-Step 'Installing the prompt theme'
$themeDest = Join-Path $HOME $ThemeFile
$themeTmp  = Join-Path $env:TEMP "$ThemeFile.$Stamp"
Get-RepoFile $ThemeFile $themeTmp
if ((Test-Path $themeDest) -and ((Get-FileHash $themeDest).Hash -ne (Get-FileHash $themeTmp).Hash)) {
    Backup-File $themeDest
}
Move-Item $themeTmp $themeDest -Force
Unblock-File $themeDest -ErrorAction SilentlyContinue
Write-Ok "Theme at $themeDest"

# 4. PowerShell 7 profile (wherever Documents really is, OneDrive included)
Write-Step 'Writing your PowerShell profile'
$docs       = [Environment]::GetFolderPath('MyDocuments')
$psDir      = Join-Path $docs 'PowerShell'
$profile7   = Join-Path $psDir 'Microsoft.PowerShell_profile.ps1'
$initLine   = 'oh-my-posh init pwsh --config "$HOME\jandedobbeleer.omp.json" | Invoke-Expression'
New-Item -ItemType Directory -Force $psDir | Out-Null
if (Test-Path $profile7) {
    $existing = Get-Content $profile7 -Raw
    if ($existing -match [regex]::Escape($initLine)) {
        Write-Ok 'Profile already set up'
    } else {
        Backup-File $profile7
        # Replace any older oh-my-posh line, keep everything else.
        $kept = ($existing -split "`r?`n" | Where-Object { $_ -notmatch '^\s*oh-my-posh\b' }) -join "`r`n"
        Set-Content -Path $profile7 -Value ($kept.TrimEnd() + "`r`n" + $initLine).TrimStart() -Encoding UTF8
        Write-Ok "Profile updated: $profile7"
    }
} else {
    Set-Content -Path $profile7 -Value $initLine -Encoding UTF8
    Write-Ok "Profile created: $profile7"
}
Unblock-File $profile7 -ErrorAction SilentlyContinue

# 5. Execution policy: RemoteSigned lets your own profile run, and still checks downloaded scripts
Write-Step 'Allowing your profile to run'
# PowerShell 7 keeps its own policy, so set it there too.
$pwshExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if ($pwshExe) {
    $p = Start-Process $pwshExe -ArgumentList '-NoLogo', '-NoProfile', '-Command', 'Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force' -Wait -PassThru -WindowStyle Hidden
    if ($p.ExitCode -eq 0) { Write-Ok 'PowerShell 7: RemoteSigned for you' }
    else { Write-Note 'PowerShell 7: couldn''t set the execution policy (a group policy may control it)' }
}
try {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
    Write-Ok 'This PowerShell: RemoteSigned for you'
} catch {
    # A more specific scope (such as -Scope Process from irm | iex) can override; the setting still saved.
    Write-Note "This PowerShell: $($_.Exception.Message)"
}

# 6. Windows Terminal settings
Write-Step 'Setting up Windows Terminal'
$wtPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
) | Where-Object { Test-Path $_ }
if (-not $wtPaths) {
    Write-Note 'No Windows Terminal settings found yet. Open Windows Terminal once, close it, and run this again.'
} else {
    foreach ($wt in $wtPaths) {
        Backup-File $wt
        if (Update-TerminalSettings $wt $FontName) {
            Write-Ok "Updated $wt"
        } else {
            Write-Note "Couldn't read $wt, so it's unchanged. Set the font to '$FontName' in Terminal settings by hand."
        }
    }
}

# Make Windows Terminal the default terminal app (Windows 11).
if (Test-Path "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe") {
    $startup = 'HKCU:\Console\%%Startup'
    if (-not (Test-Path $startup)) { New-Item $startup -Force | Out-Null }
    Set-ItemProperty $startup -Name DelegationConsole  -Value '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}'
    Set-ItemProperty $startup -Name DelegationTerminal -Value '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}'
    Write-Ok 'Windows Terminal is the default terminal app'
}

Write-Host "`nDone. Close every Windows Terminal window and open it again." -ForegroundColor Magenta
