import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../models/location.dart';
import '../providers/timeline_provider.dart';

class TripMapWidget extends StatefulWidget {
  final List<Trip> trips;

  const TripMapWidget({
    super.key,
    required this.trips,
  });

  @override
  State<TripMapWidget> createState() => _TripMapWidgetState();
}

class _TripMapWidgetState extends State<TripMapWidget> {
  final MapController _mapController = MapController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTripLocations();
  }

  @override
  void didUpdateWidget(TripMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trips != widget.trips) {
      _loadTripLocations();
    }
  }

  Future<void> _loadTripLocations() async {
    setState(() => _isLoading = true);

    final provider = context.read<TimelineProvider>();
    for (final trip in widget.trips) {
      await provider.loadLocationsForTrip(trip);
    }

    setState(() => _isLoading = false);

    // Fit bounds to show all trips
    if (widget.trips.isNotEmpty && mounted) {
      _fitBounds();
    }
  }

  void _fitBounds() {
    final allPoints = <LatLng>[];
    for (final trip in widget.trips) {
      if (trip.locations != null) {
        allPoints.addAll(trip.locations!.map((loc) => loc.latLng));
      }
    }

    if (allPoints.isEmpty) return;

    // Calculate bounds
    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final point in allPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final polylines = _buildPolylines();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(37.7749, -122.4194), // San Francisco
        initialZoom: 12,
        minZoom: 3,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.maps_timeline_viewer',
          maxZoom: 19,
        ),
        PolylineLayer(
          polylines: polylines,
        ),
        // Start/end markers
        MarkerLayer(
          markers: _buildMarkers(),
        ),
      ],
    );
  }

  List<Polyline> _buildPolylines() {
    final polylines = <Polyline>[];

    for (final trip in widget.trips) {
      if (trip.locations == null || trip.locations!.isEmpty) continue;

      // Simplify polyline for performance (Douglas-Peucker algorithm)
      final points = _simplifyPolyline(
        trip.locations!.map((loc) => loc.latLng).toList(),
        tolerance: 0.0001, // ~10 meters
      );

      // Vary stroke width by trip type
      double strokeWidth;
      switch (trip.type) {
        case TripType.singleDrive:
          strokeWidth = 3.0;
          break;
        case TripType.daily:
          strokeWidth = 4.0;
          break;
        case TripType.multiDay:
          strokeWidth = 5.0;
          break;
      }

      polylines.add(
        Polyline(
          points: points,
          color: trip.color,
          strokeWidth: strokeWidth,
          borderStrokeWidth: strokeWidth + 2,
          borderColor: trip.color.withOpacity(0.3),
        ),
      );
    }

    return polylines;
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (final trip in widget.trips) {
      if (trip.locations == null || trip.locations!.isEmpty) continue;

      // Start marker
      markers.add(
        Marker(
          point: trip.locations!.first.latLng,
          width: 16,
          height: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      );

      // End marker
      markers.add(
        Marker(
          point: trip.locations!.last.latLng,
          width: 16,
          height: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  // Douglas-Peucker algorithm for polyline simplification
  List<LatLng> _simplifyPolyline(List<LatLng> points, {required double tolerance}) {
    if (points.length < 3) return points;

    // Find point with maximum distance from line segment
    double maxDistance = 0;
    int maxIndex = 0;
    final end = points.length - 1;

    for (int i = 1; i < end; i++) {
      final distance = _perpendicularDistance(points[i], points[0], points[end]);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    // If max distance is greater than tolerance, recursively simplify
    if (maxDistance > tolerance) {
      final left = _simplifyPolyline(points.sublist(0, maxIndex + 1), tolerance: tolerance);
      final right = _simplifyPolyline(points.sublist(maxIndex), tolerance: tolerance);

      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [points[0], points[end]];
    }
  }

  double _perpendicularDistance(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    final mag = dx * dx + dy * dy;
    if (mag == 0) return _distance(point, lineStart);

    final u = ((point.longitude - lineStart.longitude) * dx +
            (point.latitude - lineStart.latitude) * dy) /
        mag;

    if (u < 0) {
      return _distance(point, lineStart);
    } else if (u > 1) {
      return _distance(point, lineEnd);
    }

    final intersection = LatLng(
      lineStart.latitude + u * dy,
      lineStart.longitude + u * dx,
    );

    return _distance(point, intersection);
  }

  double _distance(LatLng p1, LatLng p2) {
    final dx = p1.longitude - p2.longitude;
    final dy = p1.latitude - p2.latitude;
    return dx * dx + dy * dy;
  }
}
