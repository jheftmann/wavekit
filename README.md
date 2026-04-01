# WaveKit

**https://jheftmann.github.io/wavekit/**

A macOS menu bar app for tracking surf conditions at your favorite spots using Surfline data.

## Description

WaveKit lives in your menu bar and gives you quick access to surf forecasts for your favorite spots. It pulls data from Surfline's API to show wave heights, surf ratings, wind conditions, and tide times.

**Features:**
- **Forecast View** - 16-day extended forecast with daily ratings (AM/Noon/PM) and wave heights
- **Today View** - Detailed current conditions including swell data, wind speed/direction, and tide times
- **Location Sorting** - Automatically sorts spots by distance from your current location
- **Surfline Integration** - Click any spot to open it directly on Surfline.com

## Installation

### Requirements
- macOS 14.0 (Sonoma) or later
- Surfline account (free or premium) for extended forecasts

### Building from Source

1. Clone the repository:
   ```bash
   git clone <repo-url>
   cd WaveKit
   ```

2. Build the release version:
   ```bash
   swift build -c release
   ```

3. Copy to Applications:
   ```bash
   cp -r .build/release/WaveKit /Applications/
   ```

### Development Build

For development with location permissions:
```bash
./bundle-debug.sh
open .build/debug/WaveKit-Dev.app
```

## Usage

### Adding Spots

1. Go to any surf spot on [Surfline.com](https://www.surfline.com)
2. Copy the URL from your browser (e.g., `https://www.surfline.com/surf-report/venice-breakwater/590927576a2e4300134fbed8`)
3. Click the **+** button in WaveKit
4. Paste the URL and click Add

### Viewing Forecasts

- **Forecast tab** - Shows 16-day outlook with color-coded ratings and wave heights. Scroll horizontally to see more days.
- **Today tab** - Shows detailed AM/Noon/PM conditions with swell, wind, and tide data.

### Settings

- **Sign In** - Log in with your Surfline account to access extended 16-day forecasts (otherwise limited to 1 day)
- **Manage Spots** - Reorder or remove spots from your favorites

### Location Sorting

Grant location permission when prompted to automatically sort spots by distance from your current location.

## Changelog

### 2025-01-25
- Add horizontal scroll to Forecast view for 16-day forecasts
- Add location-based spot sorting
- Fix timezone handling for international spots
- Increase window width to fit 6 days
- Add debug app bundle script for development

### 2026-03-31 — v1.1.0
- Custom app icon and menu bar icon
- Per-spot calendar subscription via Apple Calendar / Notion Calendar (experimental)
- Manual drag-to-reorder and distance sort toggle for saved spots
- 2026 WSL Championship Tour calendar subscription (website)
- Terms of Use page
- Website redesign
- OG image, favicon, apple touch icon

### 2025-01-24
- Add tide and wind data to Today view
- Compact layout with inline swell/wind display
- Add wave height "+" indicator for overhead conditions
- Fix data accuracy (noon values, swell selection)
- Unify rating bar style across views
- Visual cleanup and alignment fixes

### 2025-01-23
- Add multi-day Forecast view with Today/Forecast toggle
- Color-coded ratings matching Surfline's guide
- Star indicator for good surf days

### 2025-01-22
- Rename project from SurflineFavorites to WaveKit
- Add welcome instructions to empty state
- Remove redundant UI elements

### 2025-01-21
- Initial release
- Menu bar app with Surfline API integration
- Add spots via URL
- Basic surf conditions display
