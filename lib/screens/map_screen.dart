import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timeline_provider.dart';
import '../widgets/trip_map.dart';
import '../widgets/timeline_scrollbar.dart';
import '../models/trip.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      drawer: _buildTripDrawer(),
      body: Consumer<TimelineProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!provider.hasData) {
            return const Center(
              child: Text('No data available. Please import a file.'),
            );
          }

          return Column(
            children: [
              Expanded(
                child: TripMapWidget(
                  trips: provider.selectedTrips,
                ),
              ),
              TimelineScrollbar(
                allTrips: provider.visibleTrips,
                selectedTripIds: provider.selectedTripIds,
                startDate: provider.startDate ?? DateTime.now(),
                endDate: provider.endDate ?? DateTime.now(),
                onDateRangeChanged: (start, end) {
                  provider.setDateRange(start, end);
                },
                onTripTapped: (tripId) {
                  provider.toggleTripVisibility(tripId);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTripDrawer() {
    return Drawer(
      child: Consumer<TimelineProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Trips',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${provider.visibleTrips.length} trips',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: provider.selectAllTrips,
                        child: const Text('Select All'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: provider.deselectAllTrips,
                        child: const Text('Clear'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.visibleTrips.length,
                  itemBuilder: (context, index) {
                    final trip = provider.visibleTrips[index];
                    final isSelected = provider.selectedTripIds.contains(trip.id);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (_) {
                        provider.toggleTripVisibility(trip.id!);
                      },
                      title: Text(trip.typeString),
                      subtitle: Text(
                        '${_formatDateTime(trip.startTime)}\n'
                        '${trip.durationString} • ${trip.locationCount} points',
                      ),
                      secondary: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: trip.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFilterDialog() {
    final provider = context.read<TimelineProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Trips'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<TripType?>(
              value: null,
              groupValue: provider.filterType,
              onChanged: (value) {
                provider.setFilterType(value);
                Navigator.pop(context);
              },
              title: const Text('All Trips'),
            ),
            RadioListTile<TripType?>(
              value: TripType.singleDrive,
              groupValue: provider.filterType,
              onChanged: (value) {
                provider.setFilterType(value);
                Navigator.pop(context);
              },
              title: const Text('Single Drives'),
            ),
            RadioListTile<TripType?>(
              value: TripType.daily,
              groupValue: provider.filterType,
              onChanged: (value) {
                provider.setFilterType(value);
                Navigator.pop(context);
              },
              title: const Text('Daily Trips'),
            ),
            RadioListTile<TripType?>(
              value: TripType.multiDay,
              groupValue: provider.filterType,
              onChanged: (value) {
                provider.setFilterType(value);
                Navigator.pop(context);
              },
              title: const Text('Road Trips'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
