# midell — Windows Setup Script

Fresh Windows install? One command gets everything set up.

## Run It

Open PowerShell as Administrator and paste:

```powershell
irm https://raw.githubusercontent.com/klatr/midell/main/install.ps1 | iex
```

---

## What It Installs

| App | What it is |
|---|---|
| Zen Browser | Privacy-focused Firefox-based browser |
| Discord | Chat |
| Spotify + Spicetify | Music, themed with Matte + Full Screen extension |
| Steam | Gaming |
| Surfshark | VPN |
| Tailscale | Personal mesh VPN |
| Windhawk | Windows customization mods |
| Fluent Terminal | Terminal emulator |
| Fastfetch | System info display |
| Yazi | Terminal file manager |
| WinSCP | SFTP/FTP file transfer |
| qBittorrent | Torrent client |
| balenaEtcher | Flash USB drives / ISOs |
| Dell Command \| Update | Driver & BIOS updater (XPS 16 9460) |

---

## What It Configures

- **Spicetify** — Matte theme + Full Screen extension applied automatically
- **Zen Browser** — uBlock Origin, Dark Reader, SponsorBlock, Bitwarden auto-installed on first launch
- **Windows** — file extensions visible, hidden files visible, Aero Shake disabled

---

## After It Finishes

The script will print two checklists:

- **Windhawk mods** to install manually in the Windhawk app
- **Zen Mods** to install manually in Zen → Settings → Mods
- **Spinning CD Cover Art** to install in Spotify's Spicetify Marketplace
