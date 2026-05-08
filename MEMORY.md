# WaveKit — Memory

Accumulated decisions and context from past sessions.

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
- Release app is ad-hoc signed (`codesign --force --deep --sign -`) before packaging; enables Gatekeeper "Open Anyway" flow on macOS Sonoma/Sequoia for downloaded ZIPs (2026-05-08)
