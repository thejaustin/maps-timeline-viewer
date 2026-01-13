# Maps Timeline Viewer

A beautiful Flutter app for visualizing your Google Maps Timeline data with Material 3 design.

## Features

- Import Google Takeout location history JSON files
- Automatic trip detection and classification
  - Single drives (< 4 hours)
  - Daily trips (same day)
  - Road trips (multi-day)
- Color-coded polylines on interactive map
- Timeline scrollbar with week/month views
- Trip filtering and selection
- SQLite database for efficient storage
- Material 3 expressive theming

## How to Use

1. Export your location history from Google Takeout:
   - Go to https://takeout.google.com
   - Select only "Location History"
   - Choose JSON format
   - Download the export

2. Install the app on your Android device

3. Open the app and import your JSON file

4. Explore your location history on the map!

## Building

This app is automatically built using GitHub Actions.

To download the latest APK:
1. Go to the Actions tab
2. Click on the latest successful build
3. Download the `maps-timeline-viewer-apk` artifact
4. Extract and install the APK on your device

## Technical Details

- **Framework**: Flutter 3.24+
- **Map Library**: flutter_map (OpenStreetMap)
- **Database**: SQLite via sqflite
- **State Management**: Provider
- **Supported**: Android 5.0+ (API 21+)

## Privacy

All data is stored locally on your device. No data is sent to any servers.
