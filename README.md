Introduction
------------

This Repo will enable and guide you through the installation the fabulous Oh-My-Posh! on Windows Terminal, courtesy of [Jan De Dobbeleer](https://github.com/JanDeDobbeleer/oh-my-posh), on Windows Server 2022, Windows 10 LTSC, Windows Server 2025 and Windows 11. All files needed have been included, even the Iosevka Term Nerd Font Mono Regular Nerd TrueType Font used (Courtesy of [Nerd Fonts](https://www.nerdfonts.com/font-downloads))

Note: I could not get this to work in Server 2019, despite successfully installing WinGet, the Terminal was a no-go.

<br />


<img width="1262" height="837" alt="screenshot" src="https://github.com/user-attachments/assets/7805987c-182a-4b6b-b193-ac5d9e8eb96c" />

<br />

Quick install (one line)
========================

Paste this into any PowerShell window (the built-in Windows PowerShell is fine):

    irm https://raw.githubusercontent.com/andrewpayne68/windows-terminal-ohmyposh/main/install.ps1 | iex

It installs PowerShell 7, Oh My Posh, the IosevkaTerm Nerd Font and the prompt theme, writes your PowerShell profile (even if OneDrive has moved your Documents folder), sets the execution policy to RemoteSigned, and sets up Windows Terminal: the font, the CGA color scheme as the default for all profiles, PowerShell 7 as the default profile starting in your user folder, copy on select, no logo, and Windows Terminal as the default terminal app. Anything it changes is backed up first (`*.bak-<date>`), and it's safe to run again.

On Windows Server it installs Oh My Posh as the standalone `oh-my-posh.exe` from the GitHub release (checked against its `checksums.txt`) in `%LOCALAPPDATA%\Programs\oh-my-posh\bin`, instead of the packaged (MSIX) version winget installs: on Server every run of the packaged version flashes an empty App Installer window, several times each time Terminal opens. Run the installer again to update it.

Then close every Windows Terminal window and open it again. If you've never opened Windows Terminal on that machine, open and close it once first, then run the line again.

On Windows Server 2022, install WinGet first (below), then run the line above. The manual steps below are still here if you'd rather do it by hand.

<br />

Manual install
==============

For Windows 11 and Server 2025, scroll down to Installing PowerShell 7

<br />

Install WinGet via PowerShell (if needed, i.e. on Windows Server 2022)
-----------------------------

    Write-Host "Installing WinGet PowerShell module from PSGallery..."
    Install-PackageProvider -Name NuGet -Force | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
    Write-Host "Using Repair-WinGetPackageManager cmdlet to bootstrap WinGet..."
    Repair-WinGetPackageManager -AllUsers
    winget source reset --force
    winget source update
    winget -v
    Write-Host "Completed - press Enter to continue"

    
<br />

Fix Source Error on WinGet option 1
-----------------------------

    winget source reset --force
    winget source update
    Write-Host "Completed - press Enter to continue"
<br />

Fix Source Error on WinGet option 2
-----------------------------

    Add-AppxPackage -Path '.\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
    winget -v
    Write-Host "Completed - press Enter to continue"
<br />

Fix Source Error on WinGet option for server 2022
-----------------------------

    $r=Invoke-RestMethod 'https://api.github.com/repos/microsoft/winget-cli/releases/latest' -Headers @{'User-Agent'='PowerShell'}; $b=$r.assets|?{$_.name -match 'Microsoft\.DesktopAppInstaller.*\.msixbundle'}|select -First 1; $d=$r.assets|?{$_.name -match 'DesktopAppInstaller_Dependencies.*\.zip'}|select -First 1; $l=$r.assets|?{$_.name -match 'License.*\.xml'}|select -First 1; if(-not $b -or -not $d -or -not $l){Write-Error 'Missing required assets';exit 1}; Invoke-WebRequest $b.browser_download_url -OutFile $b.name;Invoke-WebRequest $d.browser_download_url -OutFile $d.name;Invoke-WebRequest $l.browser_download_url -OutFile $l.name;Expand-Archive -Path $d.name -DestinationPath .\Dependencies -Force;Get-ChildItem .\Dependencies -Recurse -File | ?{$_.Extension -match '\.msixbundle$|\.msix$|\.appx$'} | % { Write-Information "Installing $($_.FullName)"; Add-AppxPackage $_.FullName }; Add-AppxProvisionedPackage -Online -PackagePath .\$($b.name) -LicensePath .\$($l.name) -Verbose
    Write-Host "Completed - press Enter to continue"


<br />

Install Windows Terminal (if needed)
-----------------------------

    winget install --id Microsoft.WindowsTerminal -e

<br />
<br />
<br />

Windows 11 and Server 2025 start here:
=
<br />

Install PowerShell 7
-----------------------------

    winget install Microsoft.PowerShell

or, in case of "Failed when searching source: msstore" error:

    winget install Microsoft.Powershell --source winget

<br />

Install JanDeDobbeleer's OhMyPosh for Windows Terminal
-----------------------------------------------------

    winget install JanDeDobbeleer.OhMyPosh

or, in case of "Failed when searching source: msstore" error:

    winget install JanDeDobbeleer.OhMyPosh --source winget

<br />

Install Nerd Font
-----------------

Install `IosevkaTermNerdFontMono-Regular.ttf` Nerd Font (included in repo files)


<br />

Files
------

Copy `jandedobbeleer.omp.json` to home dir (~)  or C:\USERS\USERNAME

Copy `Microsoft.PowerShell_profile.ps1` and `powershell.config.json` to the $profile path (C:\USERS\USERNAME\DOCUMENTS\POWERSHELL\


<br />

Open Terminal Settings
-------------

 - Profiles:
    - Set Defaults - PowerShell, Starting directory to $USERPROFILE% , Appearance set Font to IosevkaTerm NFM and Color scheme to CGA ,
- Startup:
    - set PowerShell, Default Terminal Application
- Interaction
    - set Automatically Copy Selection to clipboard to On

Restart Terminal to reload PATH and apply new settings.

<br />

Set Execution Policy for Current User
------------------------------------

    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser

<br />

Find Path for Terminal Profile
-----------------------------

    echo $profile 

<br />

Debug OhMyPosh!
---------------

    oh-my-posh debug


<br />
<br />

Troubleshooting
----------------    

1. IMPORTANT - Check that the `Microsoft.PowerShell_profile.ps1` file in $profile is 'unblocked' same as the two files under Documents/PowerShell are unblocked too - as Windows always blocks files downloaded from the Internet.
2. In case of CONFIG ERROR - make sure the `jandedobbeleer.omp.json` file is present in your `C:\users\ [username]` folder
3. Check that the folder under Documents is named `PowerShell` (tip - I copy paste WindowsPowerShell folder if there and then rename copied folder to PowerShell) and copy both `Microsoft.PowerShell_profile.ps1` and `powershell.config.json` files inside
4. Make sure you have run `Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser` whilst in the `PowerShell` area of Terminal (configured in Settings as Startup Profile)
5. Try opening the PowerShell 7 application itself (in Admin mode) via the Start Menu and run the `Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser` command again.
6. Make sure the jandedobbeleer.omp.json is in your user folder (c:\users\username)

More help here:
https://github.com/JanDeDobbeleer/oh-my-posh/discussions/3412

<br />

Cleaner Startup:
---------------

You can add 'pwsh.exe -nologo' to the Settings of Terminal (Command Line to launch PowerShell pwsh.exe)

<br />

<img width="1240" height="817" alt="Screenshot2026-06-12161942" src="https://github.com/user-attachments/assets/7d0ae71d-d85a-42d1-914d-436cb5128cb3" />


Special Thanks
--

Special thanks to the excellent guide by [Scott Hanselman](https://www.hanselman.com/blog/my-ultimate-powershell-prompt-with-oh-my-posh-and-the-windows-terminal) which inspired me to create this guide.

<br />
<br />
<br />

Before:
--

<img width="1477" height="761" alt="Screenshot 2026-06-12 165332" src="https://github.com/user-attachments/assets/2a89ce0b-9bdc-49c6-9146-4feb04265fbc" />

<br />
<br />
<br />

After:
--

<img width="1262" height="837" alt="screenshot" src="https://github.com/user-attachments/assets/7805987c-182a-4b6b-b193-ac5d9e8eb96c" />






