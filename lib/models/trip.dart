import 'package:flutter/material.dart';
import 'location.dart';

enum TripType {
  singleDrive,  // < 4 hours
  daily,        // same calendar day
  multiDay,     // spans multiple days (road trips)
}

enum ViewMode {
  timeline,      // Original timeline view
  allTime,       // Show all trips regardless of date
  byState,       // Group trips by state
  byCity,        // Group trips by city
  statistics,    // Statistics view
  heatmap,       // Heatmap view
  calendar,      // Calendar view
  route,         // Route-focused view
  activity,      // Activity-based view
  favorites,     // Favorite locations view
}

class Trip {
  final int? id;
  final DateTime startTime;
  final DateTime endTime;
  final TripType type;
  final Color color;
  final int locationCount;
  List<Location>? locations;

  Trip({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.color,
    required this.locationCount,
    this.locations,
  });

  Duration get duration => endTime.difference(startTime);

  String get durationString {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get typeString {
    switch (type) {
      case TripType.singleDrive:
        return 'Single Drive';
      case TripType.daily:
        return 'Daily Trip';
      case TripType.multiDay:
        return 'Road Trip';
    }
  }

  double? get totalDistance {
    if (locations == null || locations!.length < 2) return null;
    double total = 0;
    for (int i = 0; i < locations!.length - 1; i++) {
      total += locations![i].distanceTo(locations![i + 1]);
    }
    return total;
  }

  String? get distanceString {
    final dist = totalDistance;
    if (dist == null) return null;
    if (dist >= 1000) {
      return '${(dist / 1000).toStringAsFixed(1)} km';
    }
    return '${dist.toStringAsFixed(0)} m';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'type': type.index,
      'color': color.value,
      'location_count': locationCount,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] as int?,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int),
      type: TripType.values[map['type'] as int],
      color: Color(map['color'] as int),
      locationCount: map['location_count'] as int,
    );
  }
}
