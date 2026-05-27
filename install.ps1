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
# Spotify's installer hard-blocks admin installs. The fix is to download the
# .exe directly from Spotify's CDN and launch it as the current logged-in user
# using Start-Process without -Verb RunAs (which would elevate it).
Write-Step "Installing Spotify (direct from Spotify CDN)..."
try {
    $spotifyInstaller = "$env:TEMP\SpotifySetup.exe"
    # Download directly from Spotify's CDN - this is the same file as spotify.com/download
    Invoke-WebRequest -Uri "https://download.scdn.co/SpotifySetup.exe" -OutFile $spotifyInstaller
    # -Wait means the script pauses until Spotify finishes installing before moving on
    # Without -Verb RunAs it runs as your normal user account, which Spotify requires
    Start-Process -FilePath $spotifyInstaller -Wait
    Remove-Item $spotifyInstaller -Force
    Write-Success "Spotify installed"
} catch {
    Write-Fail "Failed to install Spotify - skipping. ($_)"
}

# ---- Fluent Terminal (requires Microsoft Store) ----
# felixse.FluentTerminal via winget requires Developer Mode which isn't on by default.
# Installing via the Store source works reliably without any extra setup.
Write-Step "Installing Fluent Terminal (via Microsoft Store)..."
try {
    $result = winget install --id 9p2jp8zwnwnr --source msstore --accept-source-agreements --accept-package-agreements 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Fluent Terminal installed"
    } elseif ($result -match "already installed") {
        Write-Skipped "Fluent Terminal"
    } else {
        Write-Fail "Failed to install Fluent Terminal (exit code: $LASTEXITCODE) - skipping"
    }
} catch {
    Write-Fail "Error installing Fluent Terminal - skipping. ($_)"
}

# ---- STEP 3: Spicetify + Marketplace + Theme + Extensions ----
# Spicetify is a tool that lets you theme and mod Spotify.
# It needs to run as YOUR user (not admin), and Marketplace needs a second command after.
Write-Header "Step 3: Installing Spicetify + Marketplace + Theme + Extensions"
# IMPORTANT: Spicetify must NOT run as admin - it modifies Spotify which is a user-level app.
# We use Start-Process to relaunch just the Spicetify install as your normal user account.
Write-Step "Installing Spicetify CLI (as normal user)..."
try {
    # Start-Process launches a new PowerShell window as your normal (non-admin) user
    # -Wait means this script pauses until that window finishes
    # The script inside downloads and runs the official Spicetify installer
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1 | iex`"" -Wait
    Write-Success "Spicetify CLI installed"
} catch {
    Write-Fail "Failed to install Spicetify CLI - skipping. ($_)"
}

Write-Step "Installing Spicetify Marketplace (as normal user)..."
try {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"iwr -useb https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.ps1 | iex`"" -Wait
    Write-Success "Spicetify Marketplace installed"
} catch {
    Write-Fail "Failed to install Spicetify Marketplace - skipping. ($_)"
}

# -- Apply Matte theme --
# First we clone the official spicetify themes repo so the Matte theme files exist locally.
# git clone = downloads a copy of the repo from GitHub to your PC
# "$(spicetify -c | Split-Path)\Themes\" is the folder Spicetify looks in for themes
Write-Step "Installing Matte theme..."
try {
    $themesPath = "$(spicetify -c | Split-Path)\Themes"
    if (-not (Test-Path $themesPath)) {
        New-Item -ItemType Directory -Path $themesPath | Out-Null
    }
    git clone --depth=1 https://github.com/spicetify/spicetify-themes "$env:TEMP\spicetify-themes"
    Copy-Item "$env:TEMP\spicetify-themes\*" $themesPath -Recurse -Force
    Remove-Item "$env:TEMP\spicetify-themes" -Recurse -Force
    spicetify config current_theme matte
    Write-Success "Matte theme set"
} catch {
    Write-Fail "Failed to set Matte theme - skipping. ($_)"
}

# -- Install Full Screen extension (by daksh2k) --
# Extensions are .js files Spicetify injects into Spotify.
# We download the Wrapper version which auto-updates itself from GitHub.
Write-Step "Installing Full Screen extension..."
try {
    $extensionsPath = "$(spicetify -c | Split-Path)\Extensions"
    if (-not (Test-Path $extensionsPath)) {
        New-Item -ItemType Directory -Path $extensionsPath | Out-Null
    }
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/daksh2k/Spicetify-stuff/master/Extensions/full-screen/fullScreenWrapper.js" `
        -OutFile "$extensionsPath\fullScreenWrapper.js"
    spicetify config extensions fullScreenWrapper.js
    Write-Success "Full Screen extension installed"
} catch {
    Write-Fail "Failed to install Full Screen extension - skipping. ($_)"
}

# -- Apply everything --
# spicetify backup = saves a clean copy of Spotify before modifying it (required first time)
# spicetify apply  = patches Spotify with the theme and all extensions
Write-Step "Applying Spicetify (backup + apply)..."
try {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"spicetify backup apply`"" -Wait
    Write-Success "Spicetify applied - Spotify is now themed!"
} catch {
    Write-Fail "Failed to apply Spicetify - skipping. ($_)"
}

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
$type = Add-Type -MemberDefinition $code -Name "NativeMethods" -Namespace "Win32" -PassThru
$type::SystemParametersInfo(0x0057, 0, 0, 0x01) | Out-Null

Write-Success "Nordzy cursor theme applied!"

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
Write-Host "  [ ] Disable Taskbar Thumbnails" -ForegroundColor Magenta
Write-Host "  [ ] Hide Home, Gallery and OneDrive in Explorer" -ForegroundColor Magenta
Write-Host "  [ ] Modernize Folder Picker Dialog" -ForegroundColor Magenta
Write-Host "  [ ] Remove Context Menu Items" -ForegroundColor Magenta
Write-Host "  [ ] Remove Taskbar Window Suffixes" -ForegroundColor Magenta
Write-Host "  [ ] Start Menu Size" -ForegroundColor Magenta
Write-Host "  [ ] Start Search Bing Redirector" -ForegroundColor Magenta
Write-Host "  [ ] Taskbar Auto-Hide Instant Show" -ForegroundColor Magenta
Write-Host "  [ ] Taskbar auto-hide when maximized" -ForegroundColor Magenta
Write-Host "  [ ] Taskbar Dock Animation" -ForegroundColor Magenta
Write-Host "  [ ] Taskbar height and icon size" -ForegroundColor Magenta
Write-Host "      -> Taskbar height (default 48), Icon size (default 24), Button width (default 44)" -ForegroundColor DarkGray
Write-Host "  [ ] Taskbar Thumbnail Size" -ForegroundColor Magenta
Write-Host "  [ ] Taskbar tray system icon tweaks" -ForegroundColor Magenta
Write-Host "  [ ] Translucent Windows" -ForegroundColor Magenta
Write-Host "  [ ] Windows 11 File Explorer Styler" -ForegroundColor Magenta
Write-Host "  [ ] Windows 11 Notification Center Styler" -ForegroundColor Magenta
Write-Host "      -> Theme: TranslucentShell" -ForegroundColor DarkGray
Write-Host "      -> Style constant: thumbnailImageSize=200" -ForegroundColor DarkGray
Write-Host "  [ ] Windows 11 Start Menu Power Buttons" -ForegroundColor Magenta
Write-Host "  [ ] Windows 11 Start Menu Styler" -ForegroundColor Magenta
Write-Host "  [ ] Windows 11 Taskbar Styler" -ForegroundColor Magenta
Write-Host "      -> Theme: WindowGlass" -ForegroundColor DarkGray
Write-Host '      -> Style constant: Background=$Translucent' -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Tip: You can search by partial name in Windhawk's 'Explore' tab." -ForegroundColor DarkGray
Write-Host ""

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

# ---- ZEN MODS CHECKLIST ----
Write-Header "Zen Mods To Install Manually"
Write-Host "  Open Zen Browser -> Settings -> Mods and install these:" -ForegroundColor White
Write-Host ""
Write-Host "  [ ] Cleaned URL bar" -ForegroundColor Cyan
Write-Host "  [ ] Disable Rounded Corners" -ForegroundColor Cyan
Write-Host "  [ ] Disable Status Bar" -ForegroundColor Cyan
Write-Host "  [ ] Ghost Tabs" -ForegroundColor Cyan
Write-Host "  [ ] No Top Sites" -ForegroundColor Cyan
Write-Host "  [ ] Sidebar Expand on Hover" -ForegroundColor Cyan
Write-Host "  [ ] Zen Back Forward" -ForegroundColor Cyan
Write-Host "  [ ] Zen Context Menu" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Tip: Search by name in the Mods tab, or go to zen-browser.app/mods" -ForegroundColor DarkGray
Write-Host ""

