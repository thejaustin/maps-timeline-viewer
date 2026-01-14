import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../models/location.dart';
import '../services/database_service.dart';

class TimelineProvider extends ChangeNotifier {
  List<Trip> _allTrips = [];
  List<Trip> _visibleTrips = [];
  DateTime? _startDate;
  DateTime? _endDate;
  Set<int> _selectedTripIds = {};
  bool _isLoading = false;
  TripType? _filterType;

  // Cache for loaded locations to prevent repeated DB queries
  final Map<int, List<Location>> _locationCache = {};

  // View mode for different data visualization
  ViewMode _viewMode = ViewMode.timeline;

  List<Trip> get allTrips => _allTrips;
  List<Trip> get visibleTrips => _visibleTrips;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  Set<int> get selectedTripIds => _selectedTripIds;
  bool get isLoading => _isLoading;
  TripType? get filterType => _filterType;
  ViewMode get viewMode => _viewMode;

  bool get hasData => _allTrips.isNotEmpty;

  Future<void> loadAllTrips() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allTrips = await DatabaseService.instance.getAllTrips();

      if (_allTrips.isNotEmpty) {
        // Set default date range to show last week
        _endDate = _allTrips.last.endTime;
        _startDate = _endDate!.subtract(const Duration(days: 7));

        // Select all trips by default
        _selectedTripIds = _allTrips.map((t) => t.id!).toSet();

        await _updateVisibleTrips();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setDateRange(DateTime start, DateTime end) async {
    _startDate = start;
    _endDate = end;
    await _updateVisibleTrips();
    notifyListeners();
  }

  Future<void> setFilterType(TripType? type) async {
    _filterType = type;
    await _updateVisibleTrips();
    notifyListeners();
  }

  void toggleTripVisibility(int tripId) {
    if (_selectedTripIds.contains(tripId)) {
      _selectedTripIds.remove(tripId);
    } else {
      _selectedTripIds.add(tripId);
    }
    notifyListeners();
  }

  void setViewMode(ViewMode mode) {
    _viewMode = mode;
    // Reset filters when changing view modes
    if (mode != ViewMode.timeline) {
      _filterType = null;
    }
    notifyListeners();
  }

  void selectAllTrips() {
    _selectedTripIds = _visibleTrips.map((t) => t.id!).toSet();
    notifyListeners();
  }

  void deselectAllTrips() {
    _selectedTripIds.clear();
    notifyListeners();
  }

  void setSelectedTripIds(Set<int> ids) {
    _selectedTripIds = ids;
    notifyListeners();
  }

  Future<void> _updateVisibleTrips() async {
    if (_startDate == null || _endDate == null) {
      _visibleTrips = [];
      return;
    }

    // Get trips in date range
    var trips = await DatabaseService.instance.getTripsInRange(_startDate!, _endDate!);

    // Apply type filter
    if (_filterType != null) {
      trips = trips.where((t) => t.type == _filterType).toList();
    }

    _visibleTrips = trips;

    // Update selected trips to only include visible ones
    _selectedTripIds = _selectedTripIds.where((id) =>
      _visibleTrips.any((t) => t.id == id)
    ).toSet();
  }

  Future<void> loadLocationsForTrip(Trip trip) async {
    if (trip.locations != null) return; // Already loaded

    // Check cache first
    if (_locationCache.containsKey(trip.id)) {
      trip.locations = _locationCache[trip.id]!;
      return;
    }

    final locations = await DatabaseService.instance.getLocationsForTrip(trip.id!);
    trip.locations = locations;

    // Store in cache
    _locationCache[trip.id!] = locations;

    notifyListeners();
  }

  // Load locations for trip with pagination for large datasets
  Future<void> loadLocationsForTripPaginated(Trip trip, {int offset = 0, int limit = 100}) async {
    if (trip.locations == null) {
      trip.locations = [];
    }

    // Check if we already have all locations cached
    if (_locationCache.containsKey(trip.id)) {
      trip.locations = _locationCache[trip.id]!;
      return;
    }

    final locations = await DatabaseService.instance.getLocationsForTripPaginated(
      trip.id!,
      offset: offset,
      limit: limit
    );

    // Append to existing locations if paginating
    if (offset == 0) {
      trip.locations = locations;
    } else {
      trip.locations!.addAll(locations);
    }

    // Store in cache when all locations are loaded
    if (offset == 0) {
      final totalLocations = await DatabaseService.instance.getLocationCountForTrip(trip.id!);
      if (trip.locations!.length >= totalLocations) {
        _locationCache[trip.id!] = trip.locations!;
      }
    }

    notifyListeners();
  }

  // Preload locations for visible trips to improve performance
  Future<void> preloadVisibleTripLocations() async {
    for (final trip in _visibleTrips) {
      if (!_locationCache.containsKey(trip.id)) {
        final locations = await DatabaseService.instance.getLocationsForTrip(trip.id!);
        _locationCache[trip.id!] = locations;
      }
    }
  }

  // Clear location cache when needed
  void clearLocationCache() {
    _locationCache.clear();
    notifyListeners();
  }

  // Search functionality
  String _searchQuery = '';
  List<Trip> _searchResults = [];

  String get searchQuery => _searchQuery;
  List<Trip> get searchResults => _searchResults;

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    if (_searchQuery.isEmpty) {
      _searchResults.clear();
    } else {
      _searchResults = _allTrips.where((trip) {
        // Search in trip type, date, or other relevant fields
        final tripInfo = '${trip.typeString} '
            '${trip.startTime.year}-${trip.startTime.month}-${trip.startTime.day} '
            '${trip.endTime.year}-${trip.endTime.month}-${trip.endTime.day} '
            '${trip.durationString ?? ''} '
            '${trip.distanceString ?? ''}';

        return tripInfo.toLowerCase().contains(_searchQuery);
      }).toList();
    }
    notifyListeners();
  }

  List<Trip> get selectedTrips {
    // If search is active, return search results that are also selected
    if (_searchQuery.isNotEmpty) {
      return _searchResults.where((t) => _selectedTripIds.contains(t.id)).toList();
    }
    return _visibleTrips.where((t) => _selectedTripIds.contains(t.id)).toList();
  }
}
