# WaveKit — Claude Working Notes

## Project Overview

WaveKit is a macOS menu bar app (Swift/SwiftUI, macOS 14+) that shows surf forecasts from the Surfline API for saved favorite spots. Current version: **1.0.0**.

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

### General Rules

- Keep `CHANGELOG` section in `README.md` current — add entries under a new date heading with each meaningful change.
- Keep `CLAUDE.md` updated at the end of every session (decisions, roadmap, pending items).
- Keep `README.md` accurate: features list, installation steps, usage.
- **Before building a new feature:** open a GitHub issue first. Work on a feature branch named after the issue (e.g., `feature/42-notifications`).
- **If the next task is a significantly different feature from the current branch:** ask before starting — "This is unrelated to the current branch. Should I create a new branch first?" Do not silently pile unrelated features onto an existing branch.
- **After deploying a feature:** update the issue to "needs verification" or open a new verification issue, then close it once confirmed working.
- If old open PRs are piling up, flag them and ask to merge or close before starting new work.
- Clean up merged branches after PRs are merged.
- "Push", "deploy", or "ship" means: bump `VERSION` if needed, build release, update changelog, commit, push, merge PR.

### Starting a New Session

1. Open the project repo: https://github.com/jheftmann/wavekit
2. Open project directory in Finder: `open /Users/studio/Dev/WaveKit`
3. Open project directory in Terminal: `cd /Users/studio/Dev/WaveKit`
4. Open in VSCode: `code /Users/studio/Dev/WaveKit`
5. Build debug app for local testing: `./bundle-debug.sh && open .build/debug/WaveKit-Dev.app`
6. No local server needed — this is a native macOS app, not a web app.
   - For the **website**: `cd website && open index.html` (static HTML, no server required)

### Ending a Session

1. Update `CLAUDE.md`: log any new decisions, pending items, or roadmap changes.
2. Update `README.md` changelog section with what changed.
3. Commit any loose changes with a descriptive message.
4. Confirm all open issues reflect current state.

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

Version is stored in `VERSION` (currently `1.0.0`). Always bump it before a release, then update the version string in `docs/index.html` (`<span class="version">vX.Y.Z</span>`) and the `href` on the download button if using a versioned filename.

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
