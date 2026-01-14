# Maps Timeline Viewer

A beautiful Flutter app for visualizing your Google Maps Timeline data with Material 3 design and advanced features.

## 🚀 New Features & Enhancements

### 🗺️ Advanced Map Views
- **Multiple Map Types**: Street, Satellite, Terrain, and Hybrid views
- **Interactive Map Elements**: Tap on trip lines and location markers for detailed information
- **Smart Clustering**: Automatic clustering of location markers at lower zoom levels
- **Visual Enhancements**: Glow effects for longer trips, improved marker styling

### 📊 Enhanced Data Visualization
- **8 View Modes**:
  - Timeline View (original)
  - All Time View
  - By State View
  - By City View
  - Statistics View
  - Heatmap View
  - Calendar View
  - Route View
  - Activity View
  - Favorites View

### 🔍 Improved Navigation & Search
- **Bottom Navigation Bar**: Quick access to main view modes
- **Advanced Search**: Search trips by type, date, and other attributes
- **Quick Actions FAB**: Access to share, export, and preferences
- **Enhanced Trip Drawer**: Detailed trip information and selection

### ⚡ Performance Optimizations
- **Large Dataset Support**: Optimized for files like your 110MB timeline-export.json
- **Database Indexing**: Additional indexes for faster queries
- **Pagination**: Chunked loading for large datasets
- **Caching**: Efficient location data caching
- **Memory Management**: Optimized for handling large location histories

### 👁️ Visual Enhancements
- **Material 3 Design**: Modern UI with updated color schemes
- **Enhanced Timeline Scrollbar**: Improved date labels and trip indicators
- **Trip Detail Modals**: Rich detail views for trips and locations
- **Interactive Elements**: Visual feedback for all interactive components

### 📍 Location & Trip Details
- **Trip Line Interaction**: Tap on trip lines to view detailed trip information
- **Location Marker Interaction**: Tap on location dots for detailed location info
- **Rich Trip Details**: Duration, distance, timestamps, and location count
- **Address Labels**: Location labels on map markers when available

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
- **NEW**: Multiple view modes for different perspectives
- **NEW**: Interactive map elements with detailed information
- **NEW**: Advanced search functionality
- **NEW**: Performance optimizations for large datasets
- **NEW**: Visual enhancements with Material 3 design

## How to Use

1. Export your location history from Google Takeout:
   - Go to https://takeout.google.com
   - Select only "Location History"
   - Choose JSON format
   - Download the export

2. Install the app on your Android device

3. Open the app and import your JSON file

4. Explore your location history using multiple view modes:
   - Use the bottom navigation to switch between views
   - Tap on trip lines for detailed trip information
   - Tap on location markers for detailed location information
   - Use the search function to find specific trips
   - Switch between map types using the top-right menu

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
- **Database**: SQLite via sqflite with optimized queries
- **State Management**: Provider
- **Supported**: Android 5.0+ (API 21+)
- **Performance**: Optimized for large datasets with indexing and caching

## Privacy

All data is stored locally on your device. No data is sent to any servers.
