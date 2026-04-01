# WaveKit — Claude Working Notes

## Project Overview

WaveKit is a macOS menu bar app (Swift/SwiftUI, macOS 14+) that shows surf forecasts from the Surfline API for saved favorite spots. Current version: **1.1.0**.

GitHub: https://github.com/jheftmann/wavekit

---

## Past Decisions

- Renamed from SurflineFavorites → WaveKit (2025-01-22)
- `docs/` is the GitHub Pages root (not `website/` — that folder only holds ZIPs)
- WSL 2026 CT calendar subscription added to `docs/` as a standalone sub-project; hosted at `jheftmann.github.io/wavekit/wsl-2026-ct.ics`
- Calendar section added to top of `docs/index.html` above the WaveKit app section
- Surfline API used without an official key (reverse-engineered endpoints from surfline.com)
- Location permission uses a debug `.app` bundle (`bundle-debug.sh`) because `swift run` doesn't support entitlements
- Forecast view uses horizontal scroll to show 16 days; window was widened to fit 6 days visible at once
- Focus effects disabled on all buttons for a cleaner macOS menu bar aesthetic
- Version tracked in a `VERSION` file (used by the website build and ZIP packaging)
- Per-spot calendar subscription uses EventKit (writes directly to macOS calendar store); works with Apple Calendar and Notion Calendar. Google Calendar and PC support deferred to roadmap.
- Apple Calendar blocks webcal://localhost subscriptions — EventKit is the correct Mac-native approach
- ICS line folding (RFC 5545, 75-byte limit) required for Apple Calendar compatibility; fold() helper in ICSGenerator.swift
- Forecasts are fetched on app launch (WaveKitApp.init Task) so CalendarManager has data before the user opens the popover
- App icon uses .icns (generated via iconutil from .iconset); menu bar icon is a template image (macOS auto-tints for light/dark)
- Website is plain HTML in docs/ — decided against Jekyll/Markdown since the complexity is in CSS/layout, not content
- Terms of Use page at docs/terms.html — covers no-warranty, liability, no-affiliation (Surfline/WSL), third-party data, MIT license
- App version read from `CFBundleShortVersionString` in `Bundle.main` — hook writes VERSION into Info.plist on every build, no hardcoding needed
- Calendar names prefixed with 🌊 (e.g. "🌊 Lower Trestles"); existing calendars auto-renamed on next sync
- Forecasts refresh every 30 minutes via `Timer.scheduledTimer` in `WaveKitApp.init` (in addition to on-launch and on-popover-open)
- `screenshots/` and `docs/WaveKit-*.zip` are .gitignored (local working files)
- Website two-column layout at ≥1100px breakpoint; single column below
- Post-commit hook handles full release: build, copy to /Applications, package ZIP, restart app — committing to main IS deploying

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

### Starting a session (project-specific)
- Repo: https://github.com/jheftmann/wavekit
- Project dir: `/Users/studio/Dev/WaveKit`
- Build debug app: `./bundle-debug.sh && open .build/debug/WaveKit-Dev.app`
- No local server needed — native macOS app. For the website: `open docs/index.html`

---

## Build & Release

```bash
# 1. Bump VERSION file (e.g. echo "1.1.0" > VERSION)

# 2. Release build
swift build -c release

# 3. Package app bundle into versioned ZIP for website download
VERSION=$(cat VERSION)
cd .build/release
zip -r "../../docs/WaveKit-${VERSION}.zip" WaveKit.app
cd ../..
# Also update the unversioned alias used by the download button:
cp "docs/WaveKit-${VERSION}.zip" docs/WaveKit.zip

# 4. Debug app bundle (needed for location permissions during development)
./bundle-debug.sh
open .build/debug/WaveKit-Dev.app
```

Version is stored in `VERSION` (currently `1.1.0`). Always bump it before a release, then update the download button label in `docs/index.html` and add a changelog entry.

When shipping a new version:
1. Bump `VERSION` file
2. Build release + package ZIP (steps above — hook does this automatically on commit)
3. Update `README.md` changelog section with new features
4. Update `docs/index.html`:
   - Increment version label (`<span class="version">vX.Y.Z</span>`)
   - Replace `docs/screenshot.png` with a fresh screenshot of the latest app
   - Update features list / description to reflect new functionality
   - Add any new sections for major features
5. Commit, push, merge PR

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
| `bundle-debug.sh` | Builds debug `.app` with entitlements |
| `docs/index.html` | Website homepage (GitHub Pages) |
| `docs/terms.html` | Terms of Use page |
| `docs/wsl-2026-ct.ics` | WSL 2026 CT calendar subscription |
| `WaveKit/Services/CalendarManager.swift` | EventKit calendar sync |
| `WaveKit/Services/ICSGenerator.swift` | ICS content generator (RFC 5545) |
| `README.md` | Public-facing docs + changelog |
