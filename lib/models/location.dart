import 'dart:math';
import 'package:latlong2/latlong.dart';

class Location {
  final int? id;
  final int? tripId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final int accuracy;
  final String? address;

  Location({
    this.id,
    this.tripId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.address,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  // Calculate distance to another location in meters
  double distanceTo(Location other) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, latLng, other.latLng);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'address': address,
    };
  }

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      id: map['id'] as int?,
      tripId: map['trip_id'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      accuracy: map['accuracy'] as int,
      address: map['address'] as String?,
    );
  }

  // Parse from Google Takeout JSON format
  factory Location.fromJson(Map<String, dynamic> json) {
    // Google uses E7 format (multiply by 10^-7 to get decimal degrees)
    final latE7 = json['latitudeE7'] as int?;
    final lngE7 = json['longitudeE7'] as int?;

    if (latE7 == null || lngE7 == null) {
      throw FormatException('Invalid location data: missing coordinates');
    }

    final timestamp = json['timestamp'] as String?;
    if (timestamp == null) {
      throw FormatException('Invalid location data: missing timestamp');
    }

    return Location(
      timestamp: DateTime.parse(timestamp),
      latitude: latE7 / 1e7,
      longitude: lngE7 / 1e7,
      accuracy: json['accuracy'] as int? ?? 0,
    );
  }
}
