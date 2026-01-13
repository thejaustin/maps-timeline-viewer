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

  List<Trip> get allTrips => _allTrips;
  List<Trip> get visibleTrips => _visibleTrips;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  Set<int> get selectedTripIds => _selectedTripIds;
  bool get isLoading => _isLoading;
  TripType? get filterType => _filterType;

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

  void selectAllTrips() {
    _selectedTripIds = _visibleTrips.map((t) => t.id!).toSet();
    notifyListeners();
  }

  void deselectAllTrips() {
    _selectedTripIds.clear();
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

    final locations = await DatabaseService.instance.getLocationsForTrip(trip.id!);
    trip.locations = locations;
    notifyListeners();
  }

  List<Trip> get selectedTrips {
    return _visibleTrips.where((t) => _selectedTripIds.contains(t.id)).toList();
  }
}
