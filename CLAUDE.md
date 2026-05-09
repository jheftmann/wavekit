# WaveKit — Claude Working Notes

## Project Overview

WaveKit is a macOS menu bar app (Swift/SwiftUI, macOS 14+) that shows surf forecasts from the Surfline API for saved favorite spots. Current version: **1.1.4**.

GitHub: https://github.com/jheftmann/wavekit

See [`MEMORY.md`](./MEMORY.md) for accumulated decisions and session context.

---

## Pending Decisions

- Distribution strategy: direct download (current) vs. Mac App Store
- Whether to require a Surfline account login or keep the free-tier flow as the primary path
- Notification/alert system design (e.g., notify when a spot hits a target rating)

---

## Roadmap (Deferred Features)

- Push notifications / alerts when a spot reaches a desired rating threshold
- Widget or Today extension
- iCloud sync for saved spots across devices
- Multiple location profiles (e.g., "Home", "On a trip")
- Offline/cached forecast for last-known conditions
- Mac App Store submission
- Auto-update mechanism (Sparkle or similar)
- Calendar subscription support for Google Calendar and non-Mac clients (ICS file export or hosted feed)
- Visual redesign of the menu bar popover (design in Figma first)

---

## Workflow

### Notes
- Changelog lives in `README.md` (not a separate `CHANGELOG.md`) — add entries under a new date heading.
- **If the next task is a significantly different feature from the current branch:** ask before starting — "This is unrelated to the current branch. Should I create a new branch first?"

### Session Startup

**GitHub:** https://github.com/jheftmann/wavekit

**Local setup:**
- Build debug app: `./bundle-debug.sh && open .build/debug/WaveKit-Dev.app`
- Website: `open docs/index.html`
- No local server needed — native macOS app (no http://localhost URLs)

---

## Build & Release

```bash
# 1. Bump VERSION file (e.g. echo "1.1.0" > VERSION)

# 2. Build, sign, and package (all-in-one)
./bundle-release.sh
# Outputs: .build/release/WaveKit.app (ad-hoc signed)
#          WaveKit-<version>.zip  ← upload to GitHub Releases as an asset named WaveKit.zip

# 3. Debug app bundle (needed for location permissions during development)
./bundle-debug.sh
open .build/debug/WaveKit-Dev.app
```

Version is stored in `VERSION` (currently `1.1.5`). Always bump it before a release, then add a changelog entry and upload the ZIP to GitHub Releases (the download button in `docs/index.html` always points to `/releases/latest/download/WaveKit.zip`, so no URL update needed — just make sure the release asset is named `WaveKit.zip`).

When shipping a new version:
1. Bump `VERSION` file
2. Run `./bundle-release.sh` — builds, signs, and packages the ZIP
3. Update `README.md` changelog section with new features
4. Update `docs/index.html`:
   - **Update download button text** (line ~294): `Download WaveKit (vX.Y.Z)` — must match VERSION
   - Update the changelog/what's new section to reflect new features
   - Update the roadmap section if any deferred items shipped or were added
   - Replace screenshots as needed (`screenshot-forecast.png`, `screenshot-today.png`, `screenshot-settings.png`, `screenshot-detail-left.png`, `screenshot-detail-right.png`)
   - Update features list / description to reflect new functionality
   - Add any new sections for major features
5. Update version reference in `CLAUDE.md` ("currently `X.Y.Z`")
6. Commit, push

---

## Key Files

| Path | Purpose |
|------|---------|
| `WaveKit/WaveKitApp.swift` | App entry point, menu bar setup |
| `WaveKit/Views/` | All SwiftUI views |
| `WaveKit/Services/` | Surfline API calls, location |
| `WaveKit/Models/` | Data models |
| `WaveKit/Resources/` | Assets |
| `VERSION` | Single source of version truth |
| `bundle-release.sh` | Builds, signs, and packages release ZIP |
| `bundle-debug.sh` | Builds debug `.app` with entitlements |
| `docs/index.html` | Website homepage (GitHub Pages) |
| `docs/terms.html` | Terms of Use page |
| `docs/wsl-2026-ct.ics` | WSL 2026 CT calendar subscription |
| `WaveKit/Services/CalendarManager.swift` | EventKit calendar sync |
| `WaveKit/Services/ICSGenerator.swift` | ICS content generator (RFC 5545) |
| `README.md` | Public-facing docs + changelog |
