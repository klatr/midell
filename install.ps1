# ============================================================
#  Windows Fresh Install Setup Script
#  Run this after a clean Windows install to get everything set up.
#
#  HOW TO RUN:
#  1. Open PowerShell as Administrator
#  2. Run this command (all one line):
#     irm https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.ps1 | iex
#
#  Or if you've downloaded it:
#     Set-ExecutionPolicy Bypass -Scope Process -Force; .\install.ps1
# ============================================================

# --- CONFIGURATION: Edit this section to add/remove your apps ---
# Each entry is: "winget-app-id" = "Friendly display name"
# To find the ID for any app, run: winget search "app name"

$apps = @{
    # Browser
    "Zen-Team.Zen-Browser"       = "Zen Browser"

    # Communication & Social
    "Discord.Discord"            = "Discord"

    # Note: Spotify is installed separately below (can't install as admin via winget)
    # Note: Spicetify + Marketplace are installed separately below (needs special setup)

    # Gaming
    "Valve.Steam"                = "Steam"
    "Mojang.MinecraftLauncher"   = "Minecraft Launcher"
    "Overwolf.CurseForge"        = "CurseForge"

    # Privacy & Networking
    "Surfshark.Surfshark"        = "Surfshark VPN"
    "Tailscale.Tailscale"        = "Tailscale"

    # Windows Customization
    "RamenSoftware.Windhawk"     = "Windhawk"

    # Dev / Terminal Tools
    # Note: Fluent Terminal is UWP and is installed separately below to bypass admin limitations
    "Git.Git"                    = "Git"
    "Fastfetch-cli.Fastfetch"    = "Fastfetch"
    "sxyazi.yazi"                = "Yazi (terminal file manager)"

    # File Transfer & Network
    "WinSCP.WinSCP"              = "WinSCP"

    # Downloads & USB Tools
    "qBittorrent.qBittorrent"    = "qBittorrent"
    "Balena.Etcher"              = "balenaEtcher"

    # Dell XPS 16 9460 - Driver & BIOS updater
    # This replaces SupportAssist for a fresh install - keeps drivers/BIOS up to date
    "Dell.CommandUpdate.Universal" = "Dell Command | Update"
}

# ============================================================
# --- SCRIPT LOGIC BELOW - You don't need to edit this part ---
# ============================================================

function Write-Header($text) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
}

function Write-Step($text) {
    Write-Host "  --> $text" -ForegroundColor Yellow
}

function Write-Success($text) {
    Write-Host "  [OK] $text" -ForegroundColor Green
}

function Write-Skipped($text) {
    Write-Host "  [--] $text (already installed)" -ForegroundColor DarkGray
}

function Write-Fail($text) {
    Write-Host "  [!!] $text" -ForegroundColor Red
}

# Check if running as Administrator - required for most installs
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  ERROR: Please run this script as Administrator!" -ForegroundColor Red
    Write-Host "  Right-click PowerShell and choose 'Run as administrator'" -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Header "Windows Fresh Install Setup - Dell XPS 16 9460"
Write-Host "  This script will install your apps and configure Windows." -ForegroundColor White
Write-Host "  Sit back - this may take a few minutes!" -ForegroundColor White

# ---- STEP 1: Check Winget ----
Write-Header "Step 1: Checking Winget"
Write-Step "Looking for Winget..."

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Fail "Winget not found. Install 'App Installer' from the Microsoft Store first."
    exit 1
}

Write-Success "Winget is available"

# ---- STEP 2: Install Apps via Winget ----
Write-Header "Step 2: Installing Applications"

foreach ($appId in $apps.Keys) {
    $appName = $apps[$appId]
    Write-Step "Installing $appName..."

    try {
        # --accept-source-agreements  = auto-accept the winget license/terms (no pause)
        # --accept-package-agreements = auto-accept the app's own license (no pause)
        # --silent                    = install with no popups or progress windows
        # -e                          = exact match on the ID so nothing unexpected installs
        $result = winget install --id $appId -e --accept-source-agreements --accept-package-agreements --silent 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Success "$appName installed"
        } elseif ($result -match "already installed") {
            Write-Skipped $appName
        } else {
            Write-Fail "Failed to install $appName (exit code: $LASTEXITCODE) - skipping"
        }
    } catch {
        Write-Fail "Error installing $appName - skipping. ($_)"
    }
}

# ---- Spotify (must install as normal user, not admin) ----
# Spotify's installer hard-blocks admin installs.
Write-Step "Installing Spotify (direct from Spotify CDN)..."
try {
    $spotifyInstaller = "$env:TEMP\SpotifySetup.exe"
    Invoke-WebRequest -Uri "https://download.scdn.co/SpotifySetup.exe" -OutFile $spotifyInstaller

    # Get the actual logged-in user (not SYSTEM or admin) using explorer.exe owner
    $loggedInUser = (Get-WmiObject -Class Win32_Process -Filter "Name='explorer.exe'" |
        Invoke-WmiMethod -Name GetOwner).User | Select-Object -First 1

    if ($loggedInUser) {
        Start-Process "explorer.exe" -ArgumentList $spotifyInstaller -Wait
    } else {
        Start-Process -FilePath $spotifyInstaller -Wait
    }
    Remove-Item $spotifyInstaller -Force -ErrorAction SilentlyContinue
    Write-Success "Spotify installed"
} catch {
    Write-Fail "Failed to install Spotify - skipping. ($_)"
}

# ---- Fluent Terminal ----
# Fluent Terminal is a UWP app - winget fails under admin for UWP installs.
# We download the .msixbundle directly from GitHub releases and install it.
Write-Step "Installing Fluent Terminal..."
try {
    $installed = Get-AppxPackage -Name "FluentTerminal" -ErrorAction SilentlyContinue
    if ($installed) {
        Write-Skipped "Fluent Terminal"
    } else {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/felixse/FluentTerminal/releases/latest"
        $msixUrl = ($release.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1).browser_download_url
        
        if ($msixUrl) {
            $msixPath = "$env:TEMP\FluentTerminal.msixbundle"
            Write-Step "Downloading Fluent Terminal from GitHub..."
            Invoke-WebRequest -Uri $msixUrl -OutFile $msixPath
            Add-AppxPackage -Path $msixPath
            Remove-Item $msixPath -Force -ErrorAction SilentlyContinue
            Write-Success "Fluent Terminal installed"
        } else {
            Write-Fail "Could not find Fluent Terminal release - install manually from: https://github.com/felixse/FluentTerminal/releases"
        }
    }
} catch {
    Write-Fail "Error installing Fluent Terminal - install manually from: https://github.com/felixse/FluentTerminal/releases ($_)"
}

# ---- STEP 3: Spicetify + Marketplace + Theme + Extensions ----
Write-Header "Step 3: Installing Spicetify + Marketplace + Theme + Extensions"

# Get the actual logged-in username
$spicetifyUser = (Get-WmiObject Win32_Process -Filter "name='explorer.exe'" |
    Invoke-WmiMethod -Name GetOwner |
    Select-Object -First 1).User

Write-Step "Will run Spicetify as user: $spicetifyUser"

$spicetifyScript = "$env:TEMP\spicetify-setup.ps1"
@'
Set-ExecutionPolicy Bypass -Scope Process -Force

# Install Spicetify CLI
iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1 | iex

# Install Marketplace
iwr -useb https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.ps1 | iex

# Install Matte theme
$themesPath = "$env:APPDATA\spicetify\Themes"
if (-not (Test-Path $themesPath)) { New-Item -ItemType Directory -Path $themesPath | Out-Null }
git clone --depth=1 https://github.com/spicetify/spicetify-themes "$env:TEMP\spicetify-themes"
Copy-Item "$env:TEMP\spicetify-themes\*" $themesPath -Recurse -Force
Remove-Item "$env:TEMP\spicetify-themes" -Recurse -Force
spicetify config current_theme matte

# Install Full Screen extension
$extPath = "$env:APPDATA\spicetify\Extensions"
if (-not (Test-Path $extPath)) { New-Item -ItemType Directory -Path $extPath | Out-Null }
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/daksh2k/Spicetify-stuff/master/Wrappers/fullScreenWrapper.js" -OutFile "$extPath\fullScreenWrapper.js"
spicetify config extensions fullScreenWrapper.js

# Apply everything
spicetify backup apply
'@ | Set-Content -Path $spicetifyScript -Encoding UTF8

Write-Step "Running Spicetify setup as normal user (a new window will open)..."
$taskName = "SpicetifySetup_Temp"
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$spicetifyScript`""
$principal = New-ScheduledTaskPrincipal -UserId $spicetifyUser -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Step "Waiting for Spicetify setup to complete..."
do {
    Start-Sleep -Seconds 3
    $taskState = (Get-ScheduledTask -TaskName $taskName).State
} while ($taskState -eq "Running")

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
Remove-Item $spicetifyScript -Force -ErrorAction SilentlyContinue
Write-Success "Spicetify + Matte theme + Full Screen extension installed and applied!"

# ---- STEP 4: Windows Settings Tweaks ----
Write-Header "Step 4: Applying Windows Settings"

# Show file extensions
Write-Step "Showing file extensions in Explorer..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "HideFileExt" -Value 0
Write-Success "File extensions visible"

# Show hidden files
Write-Step "Showing hidden files..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "Hidden" -Value 1
Write-Success "Hidden files visible"

# Disable Aero Shake
Write-Step "Disabling Aero Shake..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "DisallowShaking" -Value 1
Write-Success "Aero Shake disabled"

# ---- Dark Mode ----
Write-Step "Enabling dark mode..."
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
    -Name "AppsUseLightTheme" -Value 0
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
    -Name "SystemUsesLightTheme" -Value 0
Write-Success "Dark mode enabled"

# ---- Natural Scrolling ----
Write-Step "Enabling natural scrolling..."
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\HID" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -eq "Device Parameters" } |
    ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "FlipFlopWheel" -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name "FlipFlopHScroll" -Value 1 -ErrorAction SilentlyContinue
    }
Write-Success "Natural scrolling enabled (takes effect after reboot)"

# ---- Taskbar: Auto-hide ----
Write-Step "Enabling taskbar auto-hide..."
$taskbarSettings = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" -Name "Settings").Settings
$taskbarSettings[8] = $taskbarSettings[8] -bor 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" `
    -Name "Settings" -Value $taskbarSettings
Write-Success "Taskbar auto-hide enabled"

# ---- Taskbar: Hide Search, Widgets, Task View ----
Write-Step "Cleaning up taskbar buttons..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Type DWord -ErrorAction SilentlyContinue

# Target subkey for Windows 11 widgets to safely adjust without permission exceptions
$taskbarMnPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarMn"
if (-not (Test-Path $taskbarMnPath)) { New-Item -Path $taskbarMnPath -Force | Out-Null }
Set-ItemProperty -Path $taskbarMnPath -Name "TaskbarDa" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Success "Search, Widgets, and Task View hidden from taskbar"

# ---- Start Menu: Remove pinned apps, disable Recommended ----
Write-Step "Cleaning up Start menu..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "Start_ShowRecentList" -Value 0 -Type DWord
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "Start_TrackProgs" -Value 0 -Type DWord
if (-not (Test-Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer")) {
    New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" `
    -Name "HideRecommendedSection" -Value 1 -Type DWord
$startLayoutDb = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
if (Test-Path $startLayoutDb) {
    Remove-Item "$startLayoutDb\start2.bin" -Force -ErrorAction SilentlyContinue
}
Write-Success "Start menu cleaned up"

# ---- Lock Screen: Disable hints and weather ----
Write-Step "Disabling lock screen hints and weather..."
$contentPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
Set-ItemProperty -Path $contentPath -Name "SubscribedContent-338387Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $contentPath -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $contentPath -Name "RotatingLockScreenEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $contentPath -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord
Write-Success "Lock screen hints and weather disabled"

# ---- Desktop: Hide all desktop icons ----
Write-Step "Hiding desktop icons..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "HideIcons" -Value 1 -Type DWord
Write-Success "Desktop icons hidden"

# ---- Taskbar: Pin apps ----
Write-Step "Pinning apps to taskbar..."
$taskbarScript = "$env:TEMP\taskbar-pin.ps1"
@'
$layoutXml = @"
<?xml version="1.0" encoding="utf-8"?>
<LayoutModificationTemplate
    xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification"
    xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout"
    xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout"
    xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout"
    Version="1">
  <CustomTaskbarLayoutCollection PinListPlacement="Replace">
    <defaultlayout:TaskbarLayout>
      <taskbar:TaskbarPinList>
        <taskbar:DesktopApp DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\Zen Browser.lnk"/>
        <taskbar:DesktopApp DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\Spotify.lnk"/>
        <taskbar:DesktopApp DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\Windhawk.lnk"/>
        <taskbar:DesktopApp DesktopApplicationLinkPath="%PROGRAMFILES%\Windhawk\windhawk.exe"/>
        <taskbar:DesktopApp DesktopApplicationLinkPath="%LOCALAPPDATA%\Programs\Fluent Terminal\FluentTerminal.exe"/>
        <taskbar:DesktopApp DesktopApplicationLinkPath="%PROGRAMFILES(X86)%\Steam\steam.exe"/>
      </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
  </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@

$layoutPath = "$env:TEMP\TaskbarLayout.xml"
$layoutXml | Set-Content -Path $layoutPath -Encoding UTF8
Import-StartLayout -LayoutPath $layoutPath -MountPath "$env:SystemDrive"
Remove-Item $layoutPath -Force -ErrorAction SilentlyContinue
'@ | Set-Content -Path $taskbarScript -Encoding UTF8

$taskNameTB = "TaskbarPin_Temp"
$actionTB = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$taskbarScript`""
$principalTB = New-ScheduledTaskPrincipal -UserId $spicetifyUser -LogonType Interactive -RunLevel Limited
$settingsTB = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName $taskNameTB -Action $actionTB -Principal $principalTB -Settings $settingsTB -Force | Out-Null
Start-ScheduledTask -TaskName $taskNameTB
Start-Sleep -Seconds 5
Unregister-ScheduledTask -TaskName $taskNameTB -Confirm:$false
Remove-Item $taskbarScript -Force -ErrorAction SilentlyContinue
Write-Success "Taskbar apps pinned (takes effect on next login)"

# ---- STEP 5: Zen Browser Extensions ----
Write-Header "Step 5: Configuring Zen Browser Extensions"
# Configuration handled via distribution policies in Step 7

# ---- STEP 6: Download Wallpapers & qBittorrent Theme ----
Write-Header "Step 6: Downloading Wallpapers & qBittorrent Theme"

# Dynamically query the logged-in user to derive exact folder structures bypassing Admin profile overrides
$realUser = (Get-WmiObject Win32_Process -Filter "name='explorer.exe'" | Invoke-WmiMethod -Name GetOwner | Select-Object -First 1).User
$realUserHome = "C:\Users\$realUser"

$wallpaperDir = "$realUserHome\Pictures\Wallpapers"
$qbDir = "$realUserHome\Documents\qBittorrent Theme"

if (-not (Test-Path $wallpaperDir)) { New-Item -ItemType Directory -Force -Path $wallpaperDir | Out-Null }
if (-not (Test-Path $qbDir)) { New-Item -ItemType Directory -Force -Path $qbDir | Out-Null }

Write-Step "Downloading wallpapers..."
$base = "https://raw.githubusercontent.com/klatr/midell/main"
$wallpapers = @(
    "at_the_coffeshop.png",
    "ign_car.png",
    "ign_outer_space.png",
    "ign_street-crossing.png",
    "ign_tokyo.jpg",
    "ign_unsplash2.png",
    "ign_unsplash49.png",
    "ign_unsplash8.png",
    "ign_waifu.png",
    "ign_wave.png",
    "nord twoer.png",
    "nord-balloons.png",
    "nord_scenary.png"
)

foreach ($file in $wallpapers) {
    $encodedFile = [Uri]::EscapeUriString($file)
    $url = "$base/wallpapers/$encodedFile"
    $dest = "$wallpaperDir\$file"
    Invoke-WebRequest -Uri $url -OutFile $dest
    Write-Success "Downloaded $file"
}

Write-Step "Downloading qBittorrent theme..."
Invoke-WebRequest -Uri "$base/qbittorrent%20theme/fluent-dark.qbtheme" -OutFile "$qbDir\fluent-dark.qbtheme"
Write-Success "Downloaded fluent-dark.qbtheme"

Write-Host ""
Write-Host "  Wallpapers saved to: $wallpaperDir" -ForegroundColor DarkGray
Write-Host "  qBittorrent theme saved to: $qbDir" -ForegroundColor DarkGray
Write-Host "  To apply the theme: qBittorrent -> View -> Theme File -> select fluent-dark.qbtheme" -ForegroundColor DarkGray
Write-Host ""

# ---- Set Wallpaper and Lock Screen as Slideshow ----
Write-Step "Setting wallpaper and lock screen to slideshow..."
$wallpaperScript = "$env:TEMP\wallpaper-setup.ps1"
@"
`$regPath = "HKCU:\Control Panel\Personalization\Desktop Slideshow"
if (-not (Test-Path `$regPath)) { New-Item -Path `$regPath -Force | Out-Null }
Set-ItemProperty -Path `$regPath -Name "Interval" -Value 1800000 -Type DWord
Set-ItemProperty -Path `$regPath -Name "Shuffle" -Value 1 -Type DWord

`$slideshowIni = "$env:APPDATA\Microsoft\Windows\Themes\slideshow.ini"
`$slideshowDir = Split-Path `$slideshowIni
if (-not (Test-Path `$slideshowDir)) { New-Item -Path `$slideshowDir -Force | Out-Null }
Set-Content -Path `$slideshowIni -Value "[Slideshow]`
ImagesRootPath=$wallpaperDir`
Interval=1800000`
Shuffle=1"

Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "22"
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper" -Value "0"

`$lockPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen"
if (-not (Test-Path `$lockPath)) { New-Item -Path `$lockPath -Force | Out-Null }
Set-ItemProperty -Path `$lockPath -Name "SlideshowEnabled" -Value 1 -Type DWord
Set-ItemProperty -Path `$lockPath -Name "SlideshowDirectoryPath" -Value "$wallpaperDir"

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
[Wallpaper]::SystemParametersInfo(0x0014, 0, `$null, 0x01 -bor 0x02) | Out-Null
"@ | Set-Content -Path $wallpaperScript -Encoding UTF8

$taskName2 = "WallpaperSetup_Temp"
$action2 = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$wallpaperScript`""
$principal2 = New-ScheduledTaskPrincipal -UserId $spicetifyUser -LogonType Interactive -RunLevel Limited
$settings2 = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName $taskName2 -Action $action2 -Principal $principal2 -Settings $settings2 -Force | Out-Null
Start-ScheduledTask -TaskName $taskName2
Start-Sleep -Seconds 5
Unregister-ScheduledTask -TaskName $taskName2 -Confirm:$false
Remove-Item $wallpaperScript -Force -ErrorAction SilentlyContinue
Write-Success "Wallpaper and lock screen set to slideshow from $wallpaperDir"

# ---- STEP 7: Download & Apply Nordzy Cursor Theme ----
Write-Header "Step 7: Installing Nordzy Cursor Theme"
$cursorDir = "C:\Windows\Cursors\Nordzy"
if (-not (Test-Path $cursorDir)) { New-Item -ItemType Directory -Force -Path $cursorDir | Out-Null }

Write-Step "Downloading cursor files..."
$cursors = @(
    "alt-select.cur",
    "busy.ani",
    "diagonal-resize-1.cur",
    "diagonal-resize-2.cur",
    "handwriting.cur",
    "help-select.cur",
    "horizontal-resize.cur",
    "link-select.cur",
    "move.cur",
    "normal-select.cur",
    "precision-select.cur",
    "text-select.cur",
    "unavailable.cur",
    "vertical-resize.cur",
    "working-in-background.ani"
)

foreach ($file in $cursors) {
    $encodedFile = [Uri]::EscapeUriString($file)
    Invoke-WebRequest -Uri "$base/Nordzy/$encodedFile" -OutFile "$cursorDir\$file"
    Write-Success "Downloaded $file"
}

Write-Step "Applying Nordzy cursor theme via registry..."
$regPath = "HKCU:\Control Panel\Cursors"
Set-ItemProperty -Path $regPath -Name "(Default)"          -Value "Nordzy"
Set-ItemProperty -Path $regPath -Name "Arrow"              -Value "$cursorDir\normal-select.cur"
Set-ItemProperty -Path $regPath -Name "Help"               -Value "$cursorDir\help-select.cur"
Set-ItemProperty -Path $regPath -Name "AppStarting"        -Value "$cursorDir\working-in-background.ani"
Set-ItemProperty -Path $regPath -Name "Wait"               -Value "$cursorDir\busy.ani"
Set-ItemProperty -Path $regPath -Name "Crosshair"          -Value "$cursorDir\precision-select.cur"
Set-ItemProperty -Path $regPath -Name "IBeam"              -Value "$cursorDir\text-select.cur"
Set-ItemProperty -Path $regPath -Name "NWPen"              -Value "$cursorDir\handwriting.cur"
Set-ItemProperty -Path $regPath -Name "No"                 -Value "$cursorDir\unavailable.cur"
Set-ItemProperty -Path $regPath -Name "SizeNS"             -Value "$cursorDir\vertical-resize.cur"
Set-ItemProperty -Path $regPath -Name "SizeWE"             -Value "$cursorDir\horizontal-resize.cur"
Set-ItemProperty -Path $regPath -Name "SizeNWSE"           -Value "$cursorDir\diagonal-resize-1.cur"
Set-ItemProperty -Path $regPath -Name "SizeNESW"           -Value "$cursorDir\diagonal-resize-2.cur"
Set-ItemProperty -Path $regPath -Name "SizeAll"            -Value "$cursorDir\move.cur"
Set-ItemProperty -Path $regPath -Name "UpArrow"            -Value "$cursorDir\alt-select.cur"
Set-ItemProperty -Path $regPath -Name "Hand"               -Value "$cursorDir\link-select.cur"

$code = @'
[DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, uint pvParam, uint fWinIni);
'@
Set-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name "CursorBaseSize" -Value 48 -Type DWord
$type = Add-Type -MemberDefinition $code -Name "NativeMethods" -Namespace "Win32" -PassThru
$type::SystemParametersInfo(0x0057, 0, 0, 0x01) | Out-Null
Write-Success "Nordzy cursor theme applied at size 48!"

# ---- ZEN BROWSER: Auto-install Extensions via policies.json ----
Write-Step "Creating policies.json for Zen Browser..."
$zenPoliciesDir = "C:\Program Files\Zen Browser\distribution"
if (-not (Test-Path $zenPoliciesDir)) { New-Item -ItemType Directory -Path $zenPoliciesDir | Out-Null }

$policiesJson = @'
{
  "policies": {
    "ExtensionSettings": {
      "uBlock0@raymondhill.net": {
        "installation_mode": "force_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
      },
      "addon@darkreader.org": {
        "installation_mode": "force_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi"
      },
      "sponsorBlocker@ajay.app": {
        "installation_mode": "force_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi"
      },
      "{446900e4-71c2-419f-a6a7-df9c091e268b}": {
        "installation_mode": "force_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi"
      }
    }
  }
}
'@
$policiesJson | Set-Content -Path "$zenPoliciesDir\policies.json" -Encoding UTF8
Write-Success "policies.json created - extensions will install on first Zen launch"

# ---- DONE ----
Write-Header "Setup Complete!"
Write-Host ""
Write-Host "  Everything is installed! A few notes:" -ForegroundColor White
Write-Host ""
Write-Host "  * Open 'Dell Command | Update' to install your XPS drivers + BIOS." -ForegroundColor Yellow
Write-Host "  * Spicetify is applied! Matte theme + Full Screen extension are installed." -ForegroundColor Yellow
Write-Host "  * In Spotify Marketplace, manually install: 'Spinning CD Cover Art' extension." -ForegroundColor Yellow
Write-Host "  * To add more apps: find their ID with  winget search 'appname'"
Write-Host "    then add a line to the apps section at the top of this script." -ForegroundColor Yellow
Write-Host ""

# ---- WINDHAWK CHECKLIST ----
Write-Header "Windhawk Mods To Install Manually"
Write-Host "  Open Windhawk and search for each of these:" -ForegroundColor White
Write-Host ""
$windhawkMods = @(
    "Better file sizes in Explorer details",
    "Disable Taskbar Thumbnails",
    "Hide Home, Gallery and OneDrive in Explorer",
    "Modernize Folder Picker Dialog",
    "Remove Context Menu Items",
    "Remove Taskbar Window Suffixes",
    "Start Menu Size",
    "Start Search Bing Redirector",
    "Taskbar Auto-Hide Instant Show",
    "Taskbar auto-hide when maximized",
    "Taskbar Dock Animation"
)
foreach ($mod in $windhawkMods) {
    Write-Host "  [ ] $mod" -ForegroundColor Magenta
    Write-Host ""
}
Write-Host "  [ ] Taskbar height and icon size" -ForegroundColor Magenta
Write-Host "      |-> Taskbar height (default 48)" -ForegroundColor DarkGray
Write-Host "      |-> Icon size (default 24)" -ForegroundColor DarkGray
Write-Host "      |-> Button width (default 44)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  [ ] Taskbar Thumbnail Size" -ForegroundColor Magenta
Write-Host ""
Write-Host "  [ ] Taskbar tray system icon tweaks" -ForegroundColor Magenta
Write-Host ""
Write-Host "  [ ] Translucent Windows" -ForegroundColor Magenta
Write-Host ""
Write-Host "  [ ] Windows 11 File Explorer Styler" -ForegroundColor Magenta
Write-Host ""
Write-Host "  [ ] Windows 11 Notification Center Styler" -ForegroundColor Magenta
Write-Host "      |-> Theme: TranslucentShell" -ForegroundColor DarkGray
Write-Host "      |-> Style constant: thumbnailImageSize=200" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  [ ] Windows 11 Start Menu Power Buttons" -ForegroundColor Magenta
Write-Host ""
Write-Host "  [ ] Windows 11 Start Menu Styler" -ForegroundColor Magenta
Write-Host ""
Write-Host "  [ ] Windows 11 Taskbar Styler" -ForegroundColor Magenta
Write-Host "      |-> Theme: WindowGlass" -ForegroundColor DarkGray
Write-Host '      |-> Style constant: Background=$Translucent' -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Tip: You can search by partial name in Windhawk's 'Explore' tab." -ForegroundColor DarkGray
Write-Host ""

# ---- ZEN MODS CHECKLIST ----
Write-Header "Zen Mods To Install Manually"
Write-Host "  Open Zen Browser -> Settings -> Mods and install these:" -ForegroundColor White
Write-Host ""
$zenMods = @(
    "Cleaned URL bar",
    "Disable Rounded Corners",
    "Disable Status Bar",
    "Ghost Tabs",
    "No Top Sites",
    "Sidebar Expand on Hover",
    "Zen Back Forward",
    "Zen Context Menu"
)
foreach ($zmod in $zenMods) {
    Write-Host "  [ ] $zmod" -ForegroundColor Cyan
    Write-Host ""
}
Write-Host "  Tip: Search by name in the Mods tab, or go to zen-browser.app/mods" -ForegroundColor DarkGray
Write-Host ""