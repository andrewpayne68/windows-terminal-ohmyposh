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
$FontName  = 'IosevkaTerm NFM'   # the family name inside the .ttf; Terminal needs this exact name
$ThemeFile = 'jandedobbeleer.omp.json'
$ColorScheme = 'CGA'   # set as the default color scheme for all profiles
# CGA is built into newer Windows Terminal versions, but not the older Terminal on a clean
# Windows 11 install. Its colors (copied from Terminal's defaults.json) are added to
# settings.json when missing, so the scheme exists on every Terminal version.
$ColorSchemeColors = [ordered]@{
    name = 'CGA'; foreground = '#AAAAAA'; background = '#000000'; cursorColor = '#00AA00'; selectionBackground = '#FFFFFF'
    black = '#000000'; red = '#AA0000'; green = '#00AA00'; yellow = '#AA5500'; blue = '#0000AA'; purple = '#AA00AA'; cyan = '#00AAAA'; white = '#AAAAAA'
    brightBlack = '#555555'; brightRed = '#FF5555'; brightGreen = '#55FF55'; brightYellow = '#FFFF55'; brightBlue = '#5555FF'; brightPurple = '#FF55FF'; brightCyan = '#55FFFF'; brightWhite = '#FFFFFF'
}
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

# Windows Server: winget installs Oh My Posh as a packaged (MSIX) app, and on Server every run
# of its app alias flashes an empty "App Installer" window - three times each time a prompt
# starts. So on Server, use the standalone oh-my-posh.exe from the GitHub release instead,
# checked against the release's checksums.txt, in your user folder.
$PoshDir = Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\bin'
$PoshExe = Join-Path $PoshDir 'oh-my-posh.exe'
function Install-OhMyPoshStandalone {
    $cpu = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    $arch = if ($cpu -eq 'ARM64') { 'arm64' } else { 'amd64' }
    $rel = Invoke-RestMethod -UseBasicParsing 'https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/releases/latest'
    $latest = ([string]$rel.tag_name).TrimStart('v')
    if (Test-Path $PoshExe) {
        $have = ([string](& $PoshExe version 2>$null)).Trim()
        if ($have -eq $latest) { Write-Ok "Oh My Posh $have is already installed (standalone)"; return }
    }
    $name = "posh-windows-$arch.exe"
    $exeUrl = ($rel.assets | Where-Object name -eq $name).browser_download_url
    $sumUrl = ($rel.assets | Where-Object name -eq 'checksums.txt').browser_download_url
    if (-not $exeUrl -or -not $sumUrl) { throw "The Oh My Posh release is missing $name or checksums.txt." }
    $tmp = Join-Path $env:TEMP "$name.download"
    Invoke-WebRequest -UseBasicParsing -Uri $exeUrl -OutFile $tmp
    $sums = [Text.Encoding]::UTF8.GetString((Invoke-WebRequest -UseBasicParsing -Uri $sumUrl).RawContentStream.ToArray())
    $want = ($sums -split "`r?`n" | Where-Object { $_ -match "^\s*([0-9a-fA-F]{64})\s+\*?$([regex]::Escape($name))\s*$" } | ForEach-Object { $Matches[1] } | Select-Object -First 1)
    if (-not $want -or (Get-FileHash $tmp -Algorithm SHA256).Hash -ne $want) {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        throw "The downloaded $name didn't match the release's checksum, so it wasn't installed."
    }
    New-Item -ItemType Directory -Force $PoshDir | Out-Null
    # A running prompt may hold the old exe open: move it aside rather than overwrite it.
    if (Test-Path $PoshExe) {
        $old = "$PoshExe.old"
        Remove-Item $old -Force -ErrorAction SilentlyContinue
        Move-Item $PoshExe $old -Force
    }
    Move-Item $tmp $PoshExe -Force
    Unblock-File $PoshExe -ErrorAction SilentlyContinue
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not (($userPath -split ';') -contains $PoshDir)) {
        [Environment]::SetEnvironmentVariable('Path', (@($PoshDir) + @($userPath -split ';' | Where-Object { $_ })) -join ';', 'User')
    }
    Update-SessionPath
    Write-Ok "Oh My Posh $latest installed (standalone, $PoshExe)"
}

function Set-JsonProp($obj, $name, $value) {
    if ($obj.PSObject.Properties[$name]) { $obj.$name = $value }
    else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

# Edits a Windows Terminal settings.json: font, color scheme, default profile, start folder,
# copy on select and -nologo. Returns $false if the file can't be read as JSON.
function Update-TerminalSettings($path, $fontName, $colorScheme, $schemeColors) {
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
    if ($colorScheme) {
        # Add the scheme's colors unless settings.json already defines a scheme with that name.
        if ($schemeColors) {
            $schemes = @()
            if ($json.PSObject.Properties['schemes'] -and $null -ne $json.schemes) { $schemes = @($json.schemes) }
            if (-not ($schemes | Where-Object { $_.PSObject.Properties['name'] -and $_.name -eq $colorScheme })) {
                Set-JsonProp $json 'schemes' (@($schemes) + [pscustomobject]$schemeColors)
            }
        }
        Set-JsonProp $defaults 'colorScheme' $colorScheme
    }

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
$isServer = (Get-CimInstance Win32_OperatingSystem).ProductType -ne 1
if ($isServer) {
    Install-OhMyPoshStandalone
    # Remove the packaged copy, if winget put one here earlier, so nothing calls it any more.
    try {
        $pkg = Get-AppxPackage -Name 'ohmyposh.cli' -ErrorAction Stop
        if ($pkg) { $pkg | Remove-AppxPackage -ErrorAction Stop; Write-Ok 'Removed the packaged Oh My Posh (it flashed App Installer windows on Server)' }
    } catch {
        Write-Note "Couldn't remove the packaged Oh My Posh: $($_.Exception.Message). Your profile uses the standalone one anyway."
    }
} else {
    Install-WingetPackage 'JanDeDobbeleer.OhMyPosh' 'oh-my-posh'
}

# 2. Nerd Font: for all users when run as admin (as the wu menu does), otherwise just for you.
# The file and its registry entry are each checked on their own, so a half-finished earlier
# install gets repaired, and running apps are told about the font straight away.
Write-Step "Installing the $FontName font"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    $fontDest  = Join-Path $env:WINDIR "Fonts\$FontFile"
    $fontKey   = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $fontValue = $FontFile                     # machine fonts are registered by file name
    $fontScope = 'for all users'
} else {
    $fontDest  = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts\$FontFile"
    $fontKey   = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $fontValue = $fontDest                     # per-user fonts are registered by full path
    $fontScope = 'for you'
}
$hadFile = Test-Path $fontDest
if (-not $hadFile) {
    New-Item -ItemType Directory -Force (Split-Path $fontDest) | Out-Null
    Get-RepoFile $FontFile $fontDest
}
if (-not (Test-Path $fontKey)) { New-Item $fontKey -Force | Out-Null }
$entries = (Get-ItemProperty $fontKey).PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' }
$hadEntry = [bool]($entries | Where-Object { (Split-Path ([string]$_.Value) -Leaf) -eq $FontFile })
if (-not $hadEntry) {
    New-ItemProperty -Path $fontKey -Name "$FontName (TrueType)" -Value $fontValue -PropertyType String -Force | Out-Null
}
# Load the font into this session and tell running apps the font list changed.
if (-not ('WtompFonts' -as [type])) {
    Add-Type -Namespace '' -Name WtompFonts -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResourceW(string file);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessageTimeoutW(IntPtr hWnd, uint msg, UIntPtr wParam, IntPtr lParam, uint flags, uint timeout, out UIntPtr result);
'@
}
$null = [WtompFonts]::AddFontResourceW($fontDest)
$r = [UIntPtr]::Zero
$null = [WtompFonts]::SendMessageTimeoutW([IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$r)   # WM_FONTCHANGE to all windows
if ($hadFile -and $hadEntry) { Write-Ok "Font is already installed ($fontScope)" }
elseif ($hadFile) { Write-Ok "Font file was there but not registered with Windows: registered it ($fontScope)" }
else { Write-Ok "Font installed ($fontScope)" }

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
$initLine   = if ($isServer) {
    # Full path to the standalone exe, so the packaged app alias is never used on Server.
    '& "$env:LOCALAPPDATA\Programs\oh-my-posh\bin\oh-my-posh.exe" init pwsh --config "$HOME\jandedobbeleer.omp.json" | Invoke-Expression'
} else {
    'oh-my-posh init pwsh --config "$HOME\jandedobbeleer.omp.json" | Invoke-Expression'
}
New-Item -ItemType Directory -Force $psDir | Out-Null
if (Test-Path $profile7) {
    $existing = Get-Content $profile7 -Raw
    if ($existing -match [regex]::Escape($initLine)) {
        Write-Ok 'Profile already set up'
    } else {
        Backup-File $profile7
        # Replace any older oh-my-posh line, keep everything else.
        $kept = ($existing -split "`r?`n" | Where-Object { $_ -notmatch '^\s*(&\s*)?["'']?[^"'']*oh-my-posh(\.exe)?["'']?\s+init\b' }) -join "`r`n"
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
$wtStoreSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$wtAllSettings = @(
    $wtStoreSettings,
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$hasTerminal = [bool](Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -ErrorAction SilentlyContinue)
if (-not $hasTerminal) {
    Install-WingetPackage 'Microsoft.WindowsTerminal' 'wt'
    $hasTerminal = [bool](Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -ErrorAction SilentlyContinue)
}

# A Terminal that has never been opened has no settings file yet: open it
# briefly so it writes one, then close only the window this script opened.
if ($hasTerminal -and -not ($wtAllSettings | Where-Object { Test-Path $_ })) {
    Write-Note 'First run of Windows Terminal: opening it briefly to create its settings'
    $launched = Get-Date
    Start-Process 'wt.exe' -WindowStyle Minimized
    for ($i = 0; $i -lt 30 -and -not (Test-Path $wtStoreSettings); $i++) { Start-Sleep -Milliseconds 500 }
    Start-Sleep -Seconds 1
    Get-Process WindowsTerminal -ErrorAction SilentlyContinue |
        Where-Object { $_.StartTime -ge $launched } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

$wtPaths = $wtAllSettings | Where-Object { Test-Path $_ }
if (-not $wtPaths) {
    Write-Note 'No Windows Terminal settings found. Open Windows Terminal once, close it, and run this again.'
} else {
    foreach ($wt in $wtPaths) {
        Backup-File $wt
        if (Update-TerminalSettings $wt $FontName $ColorScheme $ColorSchemeColors) {
            Write-Ok "Updated $wt (font $FontName, color scheme $ColorScheme)"
        } else {
            Write-Note "Couldn't read $wt, so it's unchanged. Set the font to '$FontName' and the color scheme to '$ColorScheme' in Terminal settings by hand."
        }
    }
}

# Make Windows Terminal the default terminal app, so PowerShell and anything
# else that opens a console (admin windows included) opens in Terminal.
if ($hasTerminal) {
    $startup = 'HKCU:\Console\%%Startup'
    if (-not (Test-Path $startup)) { New-Item $startup -Force | Out-Null }
    Set-ItemProperty $startup -Name DelegationConsole  -Value '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}'
    Set-ItemProperty $startup -Name DelegationTerminal -Value '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}'
    Write-Ok 'Windows Terminal is now the default terminal app'
} else {
    Write-Note 'Windows Terminal is not installed, so the default terminal app is unchanged.'
}

Write-Host "`nDone. Close any other PowerShell or Terminal windows: they started before the install." -ForegroundColor Magenta
if (-not ($hadFile -and $hadEntry) -and (Get-Process WindowsTerminal -ErrorAction SilentlyContinue)) {
    Write-Host "If Terminal says it can't find '$FontName', close every Terminal window (this one too)" -ForegroundColor Yellow
    Write-Host 'and open Terminal again: all its windows share one process, which reads the font list when it starts.' -ForegroundColor Yellow
    Write-Host "If it still can't find the font, restart Windows." -ForegroundColor Yellow
}
if ($hasTerminal) {
    Write-Host 'Opening a fresh Windows Terminal with the new look...' -ForegroundColor Magenta
    Start-Process 'wt.exe'
}
