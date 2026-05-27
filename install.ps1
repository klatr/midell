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
    "felixse.FluentTerminal"     = "Fluent Terminal"
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
# The trick: find the currently logged-in non-admin username, then use
# Start-Process with -Credential to run the installer as that user instead.
Write-Step "Installing Spotify (direct from Spotify CDN)..."
try {
    $spotifyInstaller = "$env:TEMP\SpotifySetup.exe"
    Invoke-WebRequest -Uri "https://download.scdn.co/SpotifySetup.exe" -OutFile $spotifyInstaller

    # Get the actual logged-in user (not SYSTEM or admin) using explorer.exe owner
    # explorer.exe always runs as the logged-in user, so querying its owner gives us the right username
    $loggedInUser = (Get-WmiObject -Class Win32_Process -Filter "Name='explorer.exe'" |
        Invoke-WmiMethod -Name GetOwner).User | Select-Object -First 1

    if ($loggedInUser) {
        # Start-Process -Verb RunAsUser drops admin privileges and runs as the normal user
        # We use explorer.exe to launch it on behalf of the logged-in user
        Start-Process "explorer.exe" -ArgumentList $spotifyInstaller -Wait
    } else {
        # Fallback: just run it directly and let Windows handle it
        Start-Process -FilePath $spotifyInstaller -Wait
    }
    Remove-Item $spotifyInstaller -Force -ErrorAction SilentlyContinue
    Write-Success "Spotify installed"
} catch {
    Write-Fail "Failed to install Spotify - skipping. ($_)"
}

# ---- Fluent Terminal ----
# Fluent Terminal is a UWP app - winget fails under admin for UWP installs.
# We download the .msixbundle directly from GitHub releases and install it
# using Add-AppxPackage which works for UWP apps without needing the Store.
Write-Step "Installing Fluent Terminal..."
try {
    # First check if already installed
    $installed = Get-AppxPackage -Name "FluentTerminal" -ErrorAction SilentlyContinue
    if ($installed) {
        Write-Skipped "Fluent Terminal"
    } else {
        # Get the latest release download URL from GitHub API
        # Invoke-RestMethod fetches JSON from the GitHub API and PowerShell parses it automatically
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/felixse/FluentTerminal/releases/latest"
        $msixUrl = ($release.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1).browser_download_url
        
        if ($msixUrl) {
            $msixPath = "$env:TEMP\FluentTerminal.msixbundle"
            Write-Step "Downloading Fluent Terminal from GitHub..."
            Invoke-WebRequest -Uri $msixUrl -OutFile $msixPath
            # Add-AppxPackage installs UWP/MSIX apps - works fine under admin
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
# Spicetify must NOT run as admin. We build one big script, save it to a temp file,
# then run it as the normal logged-in user via scheduled task - the only reliable
# way to fully drop admin privileges from within an admin PowerShell session.
Write-Header "Step 3: Installing Spicetify + Marketplace + Theme + Extensions"

# Get the actual logged-in username (explorer.exe always runs as the real user)
$spicetifyUser = (Get-WmiObject Win32_Process -Filter "name='explorer.exe'" |
    Invoke-WmiMethod -Name GetOwner |
    Select-Object -First 1).User

Write-Step "Will run Spicetify as user: $spicetifyUser"

# Write the full Spicetify setup to a temp script file.
# This runs as the normal user: installs CLI, Marketplace, Matte theme,
# Full Screen extension, then applies everything.
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
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/daksh2k/Spicetify-stuff/master/Wrappers/fullScreenWrapper.js" -OutFile "$extPathullScreenWrapper.js"
spicetify config extensions fullScreenWrapper.js

# Apply everything
spicetify backup apply
'@ | Set-Content -Path $spicetifyScript -Encoding UTF8

Write-Step "Running Spicetify setup as normal user (a new window will open)..."
# Register a one-time scheduled task that runs as the logged-in user (not SYSTEM, not admin)
# This is the most reliable way to truly drop admin privileges on Windows.
# The task runs immediately, we wait for it, then delete it.
$taskName = "SpicetifySetup_Temp"
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$spicetifyScript`""
$principal = New-ScheduledTaskPrincipal -UserId $spicetifyUser -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

# Wait for the task to finish (check every 3 seconds)
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

# Show file extensions (e.g. "photo.jpg" instead of just "photo")
# This edits the Windows Registry - the database where Windows stores settings.
# HKCU = "Current User's settings", which is safe to change without affecting other users.
Write-Step "Showing file extensions in Explorer..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "HideFileExt" -Value 0
Write-Success "File extensions visible"

# Show hidden files in Explorer
Write-Step "Showing hidden files..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "Hidden" -Value 1
Write-Success "Hidden files visible"

# Disable "shake window to minimize everything" - easy to trigger by accident
Write-Step "Disabling Aero Shake..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "DisallowShaking" -Value 1
Write-Success "Aero Shake disabled"

# ---- Dark Mode ----
# AppsUseLightTheme = 0 means apps use dark mode
# SystemUsesLightTheme = 0 means the system shell (taskbar, Start, etc) uses dark mode
Write-Step "Enabling dark mode..."
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
    -Name "AppsUseLightTheme" -Value 0
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
    -Name "SystemUsesLightTheme" -Value 0
Write-Success "Dark mode enabled"

# ---- Natural Scrolling (reverse scroll direction) ----
# Windows stores scroll direction per-device in the registry under each mouse/touchpad's hardware ID.
# FlipFlopWheel = 1 reverses the scroll direction (natural/Mac-style scrolling)
# We find every pointing device and flip them all.
Write-Step "Enabling natural scrolling..."
$mouseDevices = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\HID\*\*\Device Parameters" `
    -ErrorAction SilentlyContinue
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\HID" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -eq "Device Parameters" } |
    ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "FlipFlopWheel" -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name "FlipFlopHScroll" -Value 1 -ErrorAction SilentlyContinue
    }
Write-Success "Natural scrolling enabled (takes effect after reboot)"

# ---- Taskbar: Auto-hide ----
# The taskbar settings are stored as a binary blob in the registry.
# Bit 3 of the first byte controls auto-hide: 0x03 = auto-hide on, 0x02 = off
Write-Step "Enabling taskbar auto-hide..."
$taskbarSettings = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" -Name "Settings").Settings
$taskbarSettings[8] = $taskbarSettings[8] -bor 1   # -bor = bitwise OR, sets the auto-hide bit
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" `
    -Name "Settings" -Value $taskbarSettings
Write-Success "Taskbar auto-hide enabled"

# ---- Taskbar: Hide Search, Widgets, Task View ----
# SearchboxTaskbarMode: 0 = hidden, 1 = icon only, 2 = search box
# ShowTaskViewButton: 0 = hidden
# TaskbarDa: 0 = hide widgets button
Write-Step "Cleaning up taskbar buttons..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" `
    -Name "SearchboxTaskbarMode" -Value 0 -Type DWord
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "ShowTaskViewButton" -Value 0 -Type DWord
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "TaskbarDa" -Value 0 -Type DWord
Write-Success "Search, Widgets, and Task View hidden from taskbar"

# ---- Start Menu: Remove pinned apps, disable Recommended ----
# Start_ShowRecentList = 0 hides recent files in Start
# Start_TrackProgs = 0 disables most used / recommended apps tracking
# VisibilityFlags on the CloudStore key removes all pinned app tiles
Write-Step "Cleaning up Start menu..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "Start_ShowRecentList" -Value 0 -Type DWord
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "Start_TrackProgs" -Value 0 -Type DWord
# Disable the Recommended section in Start menu
if (-not (Test-Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer")) {
    New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" `
    -Name "HideRecommendedSection" -Value 1 -Type DWord
# Remove all pinned apps from Start by clearing the layout database
$startLayoutDb = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
if (Test-Path $startLayoutDb) {
    Remove-Item "$startLayoutDb\start2.bin" -Force -ErrorAction SilentlyContinue
}
Write-Success "Start menu cleaned up"

# ---- Lock Screen: Disable hints and weather ----
# SubscribedContent-338387Enabled = 0 disables lock screen tips/hints
# SubscribedContent-338388Enabled = 0 disables lock screen weather/spotlight facts
Write-Step "Disabling lock screen hints and weather..."
$contentPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
Set-ItemProperty -Path $contentPath -Name "SubscribedContent-338387Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $contentPath -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $contentPath -Name "RotatingLockScreenEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $contentPath -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord
Write-Success "Lock screen hints and weather disabled"

# ---- Desktop: Hide all desktop icons ----
# HideIcons = 1 hides everything on the desktop (icons still exist, just not shown)
Write-Step "Hiding desktop icons..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "HideIcons" -Value 1 -Type DWord
Write-Success "Desktop icons hidden"

# ---- Taskbar: Pin apps ----
# Windows 11 doesn't have a simple command to pin apps to the taskbar.
# The trick is to modify the taskbar layout XML file that Windows reads on login.
# We write a layout file and import it, then delete it so it doesn't lock the taskbar.
Write-Step "Pinning apps to taskbar..."

# Each app needs its AppUserModelID - the unique ID Windows uses to identify apps internally.
# For regular .exe apps this is usually "Publisher.AppName".
# For Store/UWP apps it includes the package family name.
$taskbarScript = "$env:TEMP	askbar-pin.ps1"
@'
# Pin apps via Start layout XML import
# The layout file tells Windows exactly what to show on the taskbar.
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

# Import-StartLayout applies the layout. It takes effect on next login.
Import-StartLayout -LayoutPath $layoutPath -MountPath "$env:SystemDrive"
Remove-Item $layoutPath -Force -ErrorAction SilentlyContinue
'@ | Set-Content -Path $taskbarScript -Encoding UTF8

# Run as normal user via scheduled task
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

# ---- Wallpaper + Lock Screen: Slideshow from Wallpapers folder ----
# We set this AFTER the wallpapers have been downloaded in Step 6.
# Done via a scheduled task so it runs in user context (required for personalization API).
# The actual wallpaper slideshow is set in Step 6 after the folder is populated.

# ---- STEP 5: Zen Browser Extensions ----
Write-Header "Step 5: Configuring Zen Browser Extensions"

# ---- STEP 6: Download Wallpapers & qBittorrent Theme ----
Write-Header "Step 6: Downloading Wallpapers & qBittorrent Theme"

# $HOME is a built-in PowerShell variable that points to C:\Users\YOUR_USERNAME
# -Force means "create the folder even if it already exists, don't throw an error"
$wallpaperDir = "$HOME\Pictures\Wallpapers"
$qbDir = "$HOME\Documents\qBittorrent Theme"

New-Item -ItemType Directory -Force -Path $wallpaperDir | Out-Null
New-Item -ItemType Directory -Force -Path $qbDir | Out-Null

Write-Step "Downloading wallpapers..."

# Base URL for all raw files in your GitHub repo
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
    # [Uri]::EscapeUriString handles spaces in filenames like "nord twoer.png"
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
# Wallpaper personalization must run in user context, so we use a scheduled task again.
# The script uses the Windows.System.UserProfile.LockScreen API for the lock screen,
# and the SystemParametersInfo API + registry for the desktop slideshow.
Write-Step "Setting wallpaper and lock screen to slideshow..."
$wallpaperScript = "$env:TEMP\wallpaper-setup.ps1"
$wallpaperDirEscaped = $wallpaperDir -replace "\\", "\\"
@"
# Set desktop wallpaper as slideshow
`$regPath = "HKCU:\Control Panel\Personalization\Desktop Slideshow"
if (-not (Test-Path `$regPath)) { New-Item -Path `$regPath -Force | Out-Null }
# Interval = how often wallpaper changes (in milliseconds). 1800000 = 30 minutes
Set-ItemProperty -Path `$regPath -Name "Interval" -Value 1800000 -Type DWord
Set-ItemProperty -Path `$regPath -Name "Shuffle" -Value 1 -Type DWord

# Tell Windows to use the Wallpapers folder as the slideshow source
`$slideshowIni = "$env:APPDATA\Microsoft\Windows\Themes\slideshow.ini"
`$slideshowDir = Split-Path `$slideshowIni
if (-not (Test-Path `$slideshowDir)) { New-Item -Path `$slideshowDir -Force | Out-Null }
Set-Content -Path `$slideshowIni -Value "[Slideshow]`nImagesRootPath=$wallpaperDir`nInterval=1800000`nShuffle=1"

# Apply via registry - WallpaperStyle 22 = Slideshow
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "22"
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper" -Value "0"

# Set lock screen slideshow via registry
`$lockPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen"
if (-not (Test-Path `$lockPath)) { New-Item -Path `$lockPath -Force | Out-Null }
Set-ItemProperty -Path `$lockPath -Name "SlideshowEnabled" -Value 1 -Type DWord
Set-ItemProperty -Path `$lockPath -Name "SlideshowDirectoryPath" -Value "$wallpaperDir"

# Notify Windows to refresh the desktop
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

# Cursors live in C:\Windows\Cursors - this is where Windows looks for them
$cursorDir = "C:\Windows\Cursors\Nordzy"
New-Item -ItemType Directory -Force -Path $cursorDir | Out-Null

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

# HKCU:\Control Panel\Cursors is where Windows stores the active cursor scheme.
# Each entry maps a cursor role to a file path.
# We set every role to the matching Nordzy file.
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

# This Windows API call tells the system to reload cursors immediately
# without needing a reboot. SystemParametersInfo with SPI_SETCURSORS (0x0057)
# flushes the cursor cache and applies the new ones live.
$code = @'
[DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, uint pvParam, uint fWinIni);
'@
# Set cursor size - default is 32, we bump it to 48 (1.5x) so it's more visible
# CursorBaseSize is stored in the registry under Control Panel\Cursors
Set-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name "CursorBaseSize" -Value 48 -Type DWord

$type = Add-Type -MemberDefinition $code -Name "NativeMethods" -Namespace "Win32" -PassThru
$type::SystemParametersInfo(0x0057, 0, 0, 0x01) | Out-Null

Write-Success "Nordzy cursor theme applied at size 48!"

# ---- ZEN BROWSER: Auto-install Extensions via policies.json ----
# policies.json is a Firefox/Zen feature that silently installs extensions
# on first launch. We create the file in Zen's install directory.
# The extensions listed here will appear automatically when you open Zen.
Write-Step "Creating policies.json for Zen Browser..."
# Note: This runs after checklists print - Zen must already be installed from Step 2

# This is the folder Zen Browser installs to (confirmed from Zen's own GitHub)
$zenPoliciesDir = "C:\Program Files\Zen Browser\distribution"

# Test-Path checks if a folder exists. If not, New-Item creates it.
if (-not (Test-Path $zenPoliciesDir)) {
    New-Item -ItemType Directory -Path $zenPoliciesDir | Out-Null
}

# This is the policies.json content. Each URL points to a Firefox extension.
# "force_installed" means Zen installs it automatically and it shows up ready to use.
# "installation_mode" = "normal_installed" would install it but let you remove it.
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

# Set-Content writes the JSON string to the file
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
Write-Host "  * To add more apps: find their ID with  winget search 'appname'" -ForegroundColor Yellow
Write-Host "    then add a line to the apps section at the top of this script." -ForegroundColor Yellow
Write-Host ""

# ---- WINDHAWK CHECKLIST ----
# This just prints a reminder list - Windhawk mods can't be scripted,
# so you install these manually inside the Windhawk app after it opens.
Write-Header "Windhawk Mods To Install Manually"
Write-Host "  Open Windhawk and search for each of these:" -ForegroundColor White
Write-Host ""

Write-Host "  [ ] Better file sizes in Explorer details" -ForegroundColor Magenta
Write-Host ""

Write-Host "  [ ] Disable Taskbar Thumbnails" -ForegroundColor Magenta
Write-Host ""

Write-Host "  [ ] Hide Home, Gallery and OneDrive in Explorer" -ForegroundColor Magenta
Write-Host ""

Write-Host "  [ ] Modernize Folder Picker Dialog" -ForegroundColor Magenta
Write-Host ""

Write-Host "  [ ] Remove Context Menu Items" -ForegroundColor Magenta
Write-Host ""

Write-Host "  [ ] Remove Taskbar Window Suffixes" -ForegroundColor Magenta
Write-Host ""

Write-Host "  [ ] Start Menu Size" -ForegroundColor Magenta
Write-Host ""

Write-Host "  [ ] Start Search Bing Redirector" -ForegroundColor Magenta
Write-Host ""

Write-Host "  [ ] Taskbar Auto-Hide Instant Show" -ForegroundColor Magenta
Write-Host ""

Write-Host "  [ ] Taskbar auto-hide when maximized" -ForegroundColor Magenta
Write-Host ""

Write-Host "  [ ] Taskbar Dock Animation" -ForegroundColor Magenta
Write-Host ""

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

Write-Host "  [ ] Cleaned URL bar" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [ ] Disable Rounded Corners" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [ ] Disable Status Bar" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [ ] Ghost Tabs" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [ ] No Top Sites" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [ ] Sidebar Expand on Hover" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [ ] Zen Back Forward" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [ ] Zen Context Menu" -ForegroundColor Cyan
Write-Host ""

Write-Host "  Tip: Search by name in the Mods tab, or go to zen-browser.app/mods" -ForegroundColor DarkGray
Write-Host ""

