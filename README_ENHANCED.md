# Maps Timeline Viewer - Enhanced Edition

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

## 📋 Features Overview

### Core Features
- Import Google Takeout location history JSON files
- Automatic trip detection and classification
  - Single drives (< 4 hours)
  - Daily trips (same calendar day)
  - Multi-day road trips
- Color-coded polylines on interactive map
- Timeline scrollbar with zoom controls
- SQLite database for efficient storage

### Enhanced Features
- **Multiple View Modes**: 8 different ways to visualize your timeline data
- **Interactive Map**: Tap on elements for detailed information
- **Advanced Search**: Find trips quickly with search functionality
- **Performance Optimized**: Handles large datasets efficiently
- **Visual Polish**: Material 3 design with enhanced UI elements
- **Quick Actions**: Easy access to common functions via FAB

## 🛠️ Technical Details

### Framework
- **Framework**: Flutter 3.24+
- **Map Library**: flutter_map with OpenStreetMap tiles
- **Database**: SQLite via sqflite with optimized queries
- **State Management**: Provider pattern
- **Supported**: Android 5.0+ (API 21+)

### Performance Optimizations
- Database indexing on key columns (time, location, type)
- Pagination for large dataset queries
- Location data caching
- Polyline simplification algorithms
- Smart clustering for dense areas

### Privacy
All data is stored locally on your device. No data is sent to any servers.

## 📦 Building

This app is automatically built using GitHub Actions.

To download the latest APK:
1. Go to the Actions tab
2. Click on the latest successful build
3. Download the `maps-timeline-viewer-apk` artifact
4. Extract and install the APK on your device

## 🎯 Usage Instructions

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

## 🤝 Contributing

Contributions are welcome! Feel free to submit issues or pull requests.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆕 Recent Updates

### Version 1.0.1+2 Enhancements
- Added 4 new view modes (Calendar, Route, Activity, Favorites)
- Implemented interactive map elements (tap on trip lines/markers)
- Enhanced visual design with Material 3 guidelines
- Optimized for large datasets (tested with 110MB files)
- Added clustering for dense location areas
- Improved timeline scrollbar with better date visualization
- Added quick actions floating action button
- Enhanced search functionality
- Performance improvements for large datasets
- Visual enhancements for trip lines and markers