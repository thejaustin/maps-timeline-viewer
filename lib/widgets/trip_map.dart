import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../models/trip.dart';
import '../models/location.dart';
import '../providers/timeline_provider.dart';

// Define map types
enum MapType {
  street,
  satellite,
  terrain,
  hybrid,
}

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
  MapType _currentMapType = MapType.street; // Default to street view (non-satellite)
  double _currentZoom = 12.0; // Default zoom level

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
      // For large trips, use pagination to load locations in chunks
      if (trip.locationCount > 1000) {
        int offset = 0;
        const limit = 1000;
        bool hasMore = true;

        while (hasMore) {
          await provider.loadLocationsForTripPaginated(trip, offset: offset, limit: limit);

          // Check if we've loaded all locations for this trip
          if (trip.locations != null && trip.locations!.length >= trip.locationCount) {
            hasMore = false;
          } else {
            offset += limit;
          }

          // Small delay to allow UI to update
          await Future.delayed(const Duration(milliseconds: 10));
        }
      } else {
        await provider.loadLocationsForTrip(trip);
      }
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

  // Get the tile layer URL based on the map type
  String _getTileUrl(MapType mapType) {
    switch (mapType) {
      case MapType.street:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapType.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapType.terrain:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Terrain_Base/MapServer/tile/{z}/{y}/{x}';
      case MapType.hybrid:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final polylines = _buildPolylines();

    return Stack(
      children: [
        GestureDetector(
          onTapUp: (TapUpDetails details) {
            _handleMapTap(details.globalPosition);
          },
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(37.7749, -122.4194), // San Francisco
              initialZoom: 12,
              minZoom: 3,
              maxZoom: 18,
              onPositionChanged: (camera, hasGesture) {
                final newZoom = camera.zoom ?? _currentZoom;
                if (newZoom != _currentZoom) {
                  setState(() {
                    _currentZoom = newZoom;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _getTileUrl(_currentMapType),
                userAgentPackageName: 'com.example.maps_timeline_viewer',
                maxZoom: 19,
              ),
              PolylineLayer(
                polylines: polylines,
              ),
              // Start/end markers
              MarkerLayer(
                markers: _shouldShowClusters() ? _buildClusteredMarkers() : _buildMarkers(),
              ),
            ],
          ),
        ),
        // Map type selector button
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: PopupMenuButton<MapType>(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getMapIcon(_currentMapType),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getMapTypeName(_currentMapType),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              onSelected: (MapType mapType) {
                setState(() {
                  _currentMapType = mapType;
                });
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<MapType>>[
                PopupMenuItem<MapType>(
                  value: MapType.street,
                  child: Row(
                    children: [
                      Icon(_getMapIcon(MapType.street)),
                      const SizedBox(width: 8),
                      const Text('Street View'),
                    ],
                  ),
                ),
                PopupMenuItem<MapType>(
                  value: MapType.satellite,
                  child: Row(
                    children: [
                      Icon(_getMapIcon(MapType.satellite)),
                      const SizedBox(width: 8),
                      const Text('Satellite View'),
                    ],
                  ),
                ),
                PopupMenuItem<MapType>(
                  value: MapType.terrain,
                  child: Row(
                    children: [
                      Icon(_getMapIcon(MapType.terrain)),
                      const SizedBox(width: 8),
                      const Text('Terrain View'),
                    ],
                  ),
                ),
                PopupMenuItem<MapType>(
                  value: MapType.hybrid,
                  child: Row(
                    children: [
                      Icon(_getMapIcon(MapType.hybrid)),
                      const SizedBox(width: 8),
                      const Text('Hybrid View'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper methods to get map icons and names
  IconData _getMapIcon(MapType mapType) {
    switch (mapType) {
      case MapType.street:
        return Icons.map;
      case MapType.satellite:
        return Icons.satellite_alt;
      case MapType.terrain:
        return Icons.terrain;
      case MapType.hybrid:
        return Icons.layers;
    }
  }

  String _getMapTypeName(MapType mapType) {
    switch (mapType) {
      case MapType.street:
        return 'Street';
      case MapType.satellite:
        return 'Satellite';
      case MapType.terrain:
        return 'Terrain';
      case MapType.hybrid:
        return 'Hybrid';
    }
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
      Color lineColor;
      switch (trip.type) {
        case TripType.singleDrive:
          strokeWidth = 3.0;
          lineColor = trip.color.withOpacity(0.8);
          break;
        case TripType.daily:
          strokeWidth = 4.0;
          lineColor = trip.color.withOpacity(0.85);
          break;
        case TripType.multiDay:
          strokeWidth = 5.0;
          lineColor = trip.color.withOpacity(0.9);
          break;
      }

      // Create gradient effect for longer trips
      if (trip.locations!.length > 50) {
        // For longer trips, we'll add a subtle glow effect
        polylines.add(
          Polyline(
            points: points,
            color: lineColor.withOpacity(0.4), // Glow/base layer
            strokeWidth: strokeWidth + 4,
            borderStrokeWidth: 0,
          ),
        );
      }

      polylines.add(
        Polyline(
          points: points,
          color: lineColor,
          strokeWidth: strokeWidth,
          borderStrokeWidth: 0, // Removed border for cleaner look
        ),
      );
    }

    return polylines;
  }

  // Build interactive polylines with click handlers
  List<Polyline> _buildInteractivePolylines() {
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
          isDotted: false,
        ),
      );
    }

    return polylines;
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (final trip in widget.trips) {
      if (trip.locations == null || trip.locations!.isEmpty) continue;

      // Start marker with label
      markers.add(
        Marker(
          point: trip.locations!.first.latLng,
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.flag,
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
      );

      // Add label for start location if available
      if (trip.locations!.first.address != null && trip.locations!.first.address!.isNotEmpty) {
        markers.add(
          Marker(
            point: trip.locations!.first.latLng,
            width: 180,
            height: 36,
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade300, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Start: ${trip.locations!.first.address}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      }

      // End marker with label
      markers.add(
        Marker(
          point: trip.locations!.last.latLng,
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.flag,
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
      );

      // Add label for end location if available
      if (trip.locations!.last.address != null && trip.locations!.last.address!.isNotEmpty) {
        markers.add(
          Marker(
            point: trip.locations!.last.latLng,
            width: 180,
            height: 36,
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade300, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'End: ${trip.locations!.last.address}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      }

      // Add intermediate location markers for longer trips
      if (trip.locations!.length > 10) { // Only for longer trips
        final interval = (trip.locations!.length / 5).floor(); // Show ~5 intermediate points
        for (int i = interval; i < trip.locations!.length; i += interval) {
          if (i != 0 && i != trip.locations!.length - 1) { // Skip start and end
            final location = trip.locations![i];

            // Create a more visually appealing marker
            markers.add(
              Marker(
                point: location.latLng,
                width: 16,
                height: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: trip.color.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            );

            // Add label for intermediate location if available
            if (location.address != null && location.address!.isNotEmpty) {
              markers.add(
                Marker(
                  point: location.latLng,
                  width: 180,
                  height: 36,
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      location.address!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            }
          }
        }
      }
    }

    return markers;
  }

  // Method to create clustered markers for dense areas
  List<Marker> _buildClusteredMarkers() {
    final markers = <Marker>[];
    final clusterThreshold = 0.001; // Threshold for clustering (adjust as needed)

    for (final trip in widget.trips) {
      if (trip.locations == null || trip.locations!.isEmpty) continue;

      // Group nearby locations into clusters
      final clusters = <LatLng, List<Location>>{};

      for (final location in trip.locations!) {
        bool addedToCluster = false;

        // Check if location is close to existing cluster
        for (final clusterPoint in clusters.keys) {
          final distance = _distanceBetween(clusterPoint, location.latLng);
          if (distance < clusterThreshold) {
            clusters[clusterPoint]!.add(location);
            addedToCluster = true;
            break;
          }
        }

        // If not added to existing cluster, create new cluster
        if (!addedToCluster) {
          clusters[location.latLng] = [location];
        }
      }

      // Create markers for clusters
      for (final clusterEntry in clusters.entries) {
        final clusterLocations = clusterEntry.value;
        final center = clusterEntry.key;

        if (clusterLocations.length > 1) {
          // Create cluster marker with enhanced visual design
          markers.add(
            Marker(
              point: center,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    clusterLocations.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 2,
                          color: Colors.black45,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          // Single location marker with enhanced visual design
          final location = clusterLocations.first;
          markers.add(
            Marker(
              point: location.latLng,
              width: 16,
              height: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: trip.color.withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 3,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return markers;
  }

  // Helper method to determine if clusters should be shown based on zoom level
  bool _shouldShowClusters() {
    // Show clusters when zoom level is less than 12 (showing larger areas)
    return _currentZoom < 12;
  }

  // Handle map tap events to detect polyline and marker clicks
  void _handleMapTap(Offset globalPosition) async {
    // Convert screen position to map position
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(globalPosition);
    final mapPosition = _mapController.camera.pointToLatLng(math.Point(localPosition.dx, localPosition.dy));

    // Check if tap is near any polyline
    for (final trip in widget.trips) {
      if (trip.locations == null || trip.locations!.length < 2) continue;

      // Check if tap is near this trip's polyline
      if (_isNearPolyline(mapPosition, trip)) {
        _showTripDetails(trip);
        return;
      }
    }

    // Check if tap is near any marker
    for (final trip in widget.trips) {
      if (trip.locations == null || trip.locations!.isEmpty) continue;

      // Check start marker
      if (_isNearPoint(mapPosition, trip.locations!.first.latLng, 0.001)) {
        _showLocationDetails(trip.locations!.first, trip);
        return;
      }

      // Check end marker
      if (_isNearPoint(mapPosition, trip.locations!.last.latLng, 0.001)) {
        _showLocationDetails(trip.locations!.last, trip);
        return;
      }

      // Check intermediate markers for longer trips
      if (trip.locations!.length > 10) {
        final interval = (trip.locations!.length / 5).floor();
        for (int i = interval; i < trip.locations!.length; i += interval) {
          if (i != 0 && i != trip.locations!.length - 1) {
            final location = trip.locations![i];
            if (_isNearPoint(mapPosition, location.latLng, 0.001)) {
              _showLocationDetails(location, trip);
              return;
            }
          }
        }
      }
    }
  }

  // Check if a point is near a polyline
  bool _isNearPolyline(LatLng tapPoint, Trip trip) {
    if (trip.locations == null || trip.locations!.length < 2) return false;

    final locations = trip.locations!;
    for (int i = 0; i < locations.length - 1; i++) {
      final point1 = locations[i].latLng;
      final point2 = locations[i + 1].latLng;

      // Calculate distance from tap point to line segment
      final distance = _distanceToLineSegment(tapPoint, point1, point2);

      // Adjust threshold based on zoom level
      final threshold = 0.001 / math.pow(2, _currentZoom - 10); // Smaller threshold when zoomed in

      if (distance < threshold) {
        return true;
      }
    }

    return false;
  }

  // Calculate distance from a point to a line segment
  double _distanceToLineSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final A = point.latitude - lineStart.latitude;
    final B = point.longitude - lineStart.longitude;
    final C = lineEnd.latitude - lineStart.latitude;
    final D = lineEnd.longitude - lineStart.longitude;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;

    if (lenSq == 0) return _distanceBetween(point, lineStart);

    final param = dot / lenSq;

    LatLng xx, yy;
    if (param < 0) {
      xx = lineStart;
      yy = point;
    } else if (param > 1) {
      xx = lineEnd;
      yy = point;
    } else {
      final xxLat = lineStart.latitude + param * C;
      final xxLng = lineStart.longitude + param * D;
      xx = LatLng(xxLat, xxLng);
      yy = point;
    }

    return _distanceBetween(xx, yy);
  }

  // Check if a point is near another point
  bool _isNearPoint(LatLng point1, LatLng point2, double threshold) {
    return _distanceBetween(point1, point2) < threshold;
  }

  // Show trip details when polyline is tapped
  void _showTripDetails(Trip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: trip.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      trip.typeString,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Start Time', _formatDateTime(trip.startTime)),
                _buildDetailRow('End Time', _formatDateTime(trip.endTime)),
                _buildDetailRow('Duration', trip.durationString ?? 'N/A'),
                _buildDetailRow('Locations', trip.locationCount.toString()),
                if (trip.distanceString != null) _buildDetailRow('Distance', trip.distanceString!),
                const SizedBox(height: 24),
                Text(
                  'Trip Path',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Trip visualization would appear here',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Show location details when marker is tapped
  void _showLocationDetails(Location location, Trip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.6,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: trip.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Location Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Timestamp', _formatDateTime(location.timestamp)),
                _buildDetailRow('Coordinates', '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}'),
                _buildDetailRow('Accuracy', '${location.accuracy}m'),
                if (location.address != null && location.address!.isNotEmpty)
                  _buildDetailRow('Address', location.address!),
                const SizedBox(height: 24),
                Text(
                  'On ${trip.typeString}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build detail row widget
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to format date/time
  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // Helper method to calculate distance between two points
  double _distanceBetween(LatLng point1, LatLng point2) {
    final dx = point1.longitude - point2.longitude;
    final dy = point1.latitude - point2.latitude;
    return math.sqrt(dx * dx + dy * dy);
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
