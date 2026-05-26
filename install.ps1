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

    # Music
    "Spotify.Spotify"            = "Spotify"
    # Note: Spicetify + Marketplace are installed separately below (needs special setup)

    # Gaming
    "Valve.Steam"                = "Steam"

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
        Write-Fail "Failed to install $appName (exit code: $LASTEXITCODE)"
    }
}

# ---- STEP 3: Spicetify + Marketplace + Theme + Extensions ----
# Spicetify is a tool that lets you theme and mod Spotify.
# It needs to run as YOUR user (not admin), and Marketplace needs a second command after.
Write-Header "Step 3: Installing Spicetify + Marketplace + Theme + Extensions"
Write-Step "Installing Spicetify CLI..."

# iwr = Invoke-WebRequest, downloads the install script from the internet
# iex = Invoke-Expression, runs whatever was downloaded
# This is the official install method from spicetify.app
iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1 | iex

Write-Step "Installing Spicetify Marketplace..."
# This installs the in-app store for Spicetify themes and extensions
iwr -useb https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.ps1 | iex

Write-Success "Spicetify + Marketplace installed"

# -- Apply Matte theme --
# First we clone the official spicetify themes repo so the Matte theme files exist locally.
# git clone = downloads a copy of the repo from GitHub to your PC
# "$(spicetify -c | Split-Path)\Themes\" is the folder Spicetify looks in for themes
Write-Step "Installing Matte theme..."
$themesPath = "$(spicetify -c | Split-Path)\Themes"
if (-not (Test-Path $themesPath)) {
    New-Item -ItemType Directory -Path $themesPath | Out-Null
}
git clone --depth=1 https://github.com/spicetify/spicetify-themes "$env:TEMP\spicetify-themes"
Copy-Item "$env:TEMP\spicetify-themes\*" $themesPath -Recurse -Force
Remove-Item "$env:TEMP\spicetify-themes" -Recurse -Force

# spicetify config current_theme = tells Spicetify which theme folder to use
spicetify config current_theme matte
Write-Success "Matte theme set"

# -- Install Full Screen extension (by daksh2k) --
# Extensions are .js files Spicetify injects into Spotify.
# We download the Wrapper version which auto-updates itself from GitHub.
Write-Step "Installing Full Screen extension..."
$extensionsPath = "$(spicetify -c | Split-Path)\Extensions"
if (-not (Test-Path $extensionsPath)) {
    New-Item -ItemType Directory -Path $extensionsPath | Out-Null
}
# Invoke-WebRequest downloads the file, -OutFile saves it to the extensions folder
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/daksh2k/Spicetify-stuff/master/Extensions/full-screen/fullScreenWrapper.js" `
    -OutFile "$extensionsPath\fullScreenWrapper.js"

# spicetify config extensions = registers the .js file so Spicetify loads it on startup
spicetify config extensions fullScreenWrapper.js
Write-Success "Full Screen extension installed"

# -- Apply everything --
# spicetify backup = saves a clean copy of Spotify before modifying it (required first time)
# spicetify apply  = patches Spotify with the theme and all extensions
Write-Step "Applying Spicetify (backup + apply)..."
spicetify backup apply
Write-Success "Spicetify applied - Spotify is now themed!"

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

# ---- DONE ----
Write-Header "Setup Complete!"
Write-Host ""
Write-Host "  Everything is installed! A few notes:" -ForegroundColor White
Write-Host ""
Write-Host "  * Open 'Dell Command | Update' to install your XPS drivers + BIOS." -ForegroundColor Yellow
Write-Host "  * Spicetify is applied! Matte theme + Full Screen extension are installed.
  * In Spotify Marketplace, manually install: "Spinning CD Cover Art" extension." -ForegroundColor Yellow
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
Write-Host "  [ ] Disable Taskbar Thumbnails" -ForegroundColor Magenta
Write-Host "  [ ] Hide Home, Gallery and OneDrive in Explorer" -ForegroundColor Magenta
Write-Host "  [ ] Logon, Logoff and Shutdown Sounds Restored" -ForegroundColor Magenta
Write-Host "  [ ] Modernize Folder Picker Dialog" -ForegroundColor Magenta
Write-Host "  [ ] Remove Context Menu Items" -ForegroundColor Magenta
Write-Host "  [ ] Remove Taskbar Window Suffixes" -ForegroundColor Magenta
Write-Host "  [ ] Start Menu Size" -ForegroundColor Magenta
Write-Host "  [ ] Start Search Bing Redirector" -ForegroundColor Magenta
Write-Host "  [ ] Taskbar Auto-Hide Instant Show" -ForegroundColor Magenta
Write-Host "  [ ] Taskbar auto-hide when maximized" -ForegroundColor Magenta
Write-Host "  [ ] Taskbar Dock Animation" -ForegroundColor Magenta
Write-Host "  [ ] Taskbar height and icon size" -ForegroundColor Magenta
Write-Host "  [ ] Taskbar Thumbnail Size" -ForegroundColor Magenta
Write-Host "  [ ] Taskbar tray system icon tweaks" -ForegroundColor Magenta
Write-Host "  [ ] Translucent Windows" -ForegroundColor Magenta
Write-Host "  [ ] Windows 11 File Explorer Styler" -ForegroundColor Magenta
Write-Host "  [ ] Windows 11 Notification Center Styler" -ForegroundColor Magenta
Write-Host "  [ ] Windows 11 Start Menu Power Buttons" -ForegroundColor Magenta
Write-Host "  [ ] Windows 11 Start Menu Styler" -ForegroundColor Magenta
Write-Host "  [ ] Windows 11 Taskbar Styler" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Tip: You can search by partial name in Windhawk's 'Explore' tab." -ForegroundColor DarkGray
Write-Host ""
