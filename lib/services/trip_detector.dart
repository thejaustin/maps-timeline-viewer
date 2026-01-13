import 'package:flutter/material.dart';
import '../models/location.dart';
import '../models/trip.dart';

class TripDetector {
  static const Duration _tripGapThreshold = Duration(minutes: 10);
  static const Duration _singleDriveThreshold = Duration(hours: 4);

  static List<Trip> detectTrips(
    List<Location> locations,
    ColorScheme colorScheme,
  ) {
    if (locations.isEmpty) return [];

    // Sort by timestamp
    locations.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final trips = <Trip>[];
    var currentTripLocations = <Location>[];
    DateTime? lastTimestamp;

    for (final location in locations) {
      if (lastTimestamp == null ||
          location.timestamp.difference(lastTimestamp) <= _tripGapThreshold) {
        // Continue current trip
        currentTripLocations.add(location);
      } else {
        // Gap detected - save current trip and start new one
        if (currentTripLocations.isNotEmpty) {
          trips.add(_createTrip(currentTripLocations, trips.length, colorScheme));
        }
        currentTripLocations = [location];
      }
      lastTimestamp = location.timestamp;
    }

    // Don't forget the last trip
    if (currentTripLocations.isNotEmpty) {
      trips.add(_createTrip(currentTripLocations, trips.length, colorScheme));
    }

    return trips;
  }

  static Trip _createTrip(
    List<Location> locations,
    int tripIndex,
    ColorScheme colorScheme,
  ) {
    final startTime = locations.first.timestamp;
    final endTime = locations.last.timestamp;
    final duration = endTime.difference(startTime);

    // Classify trip type
    TripType type;
    if (duration < _singleDriveThreshold) {
      type = TripType.singleDrive;
    } else if (_isSameDay(startTime, endTime)) {
      type = TripType.daily;
    } else {
      type = TripType.multiDay;
    }

    // Assign color from Material 3 palette
    final color = _getColorForTrip(tripIndex, type, colorScheme);

    return Trip(
      startTime: startTime,
      endTime: endTime,
      type: type,
      color: color,
      locationCount: locations.length,
      locations: locations,
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static Color _getColorForTrip(
    int index,
    TripType type,
    ColorScheme colorScheme,
  ) {
    // Different color schemes based on trip type
    final colors = <Color>[];

    switch (type) {
      case TripType.singleDrive:
        colors.addAll([
          colorScheme.primary,
          colorScheme.primaryContainer,
          colorScheme.secondary,
          colorScheme.secondaryContainer,
        ]);
        break;
      case TripType.daily:
        colors.addAll([
          colorScheme.tertiary,
          colorScheme.tertiaryContainer,
          colorScheme.primary.withOpacity(0.8),
          colorScheme.secondary.withOpacity(0.8),
        ]);
        break;
      case TripType.multiDay:
        colors.addAll([
          colorScheme.error,
          colorScheme.errorContainer,
          Colors.deepOrange,
          Colors.orange,
        ]);
        break;
    }

    return colors[index % colors.length];
  }
}
