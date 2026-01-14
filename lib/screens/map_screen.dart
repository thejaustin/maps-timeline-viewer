import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Timeline Map'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            HapticFeedback.lightImpact();
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showFilterDialog();
            },
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map_outlined, size: 64, opacity: 0.5),
                  const SizedBox(height: 16),
                  const Text('No data available. Please import a file.'),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Import'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: TripMapWidget(
                  trips: provider.selectedTrips,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 120,
                child: TimelineScrollbar(
                  allTrips: provider.visibleTrips,
                  selectedTripIds: provider.selectedTripIds,
                  startDate: provider.startDate ?? DateTime.now(),
                  endDate: provider.endDate ?? DateTime.now(),
                  onDateRangeChanged: (start, end) {
                    HapticFeedback.selectionClick();
                    provider.setDateRange(start, end);
                  },
                  onTripTapped: (tripId) {
                    HapticFeedback.selectionClick();
                    provider.toggleTripVisibility(tripId);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTripDrawer() {
    return NavigationDrawer(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text(
            'Timeline Trips',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Consumer<TimelineProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            provider.selectAllTrips();
                          },
                          child: const Text('Select All'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            provider.deselectAllTrips();
                          },
                          child: const Text('Clear'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(indent: 28, endIndent: 28),
                SizedBox(
                  height: MediaQuery.of(context).size.height - 250,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: provider.visibleTrips.length,
                    itemBuilder: (context, index) {
                      final trip = provider.visibleTrips[index];
                      final isSelected = provider.selectedTripIds.contains(trip.id);

                      return NavigationDrawerDestination(
                        icon: Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? trip.color : null,
                        ),
                        label: Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(trip.typeString),
                              Text(
                                '${_formatDateTime(trip.startTime)} • ${trip.locationCount} pts',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
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
      ],
      onDestinationSelected: (index) {
        final provider = context.read<TimelineProvider>();
        final trip = provider.visibleTrips[index];
        HapticFeedback.selectionClick();
        provider.toggleTripVisibility(trip.id!);
      },
    );
  }

  void _showFilterDialog() {
    final provider = context.read<TimelineProvider>();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Filter Trips', style: Theme.of(context).textTheme.titleLarge),
            ),
            _buildFilterOption(null, 'All Trips', provider),
            _buildFilterOption(TripType.singleDrive, 'Single Drives', provider),
            _buildFilterOption(TripType.daily, 'Daily Trips', provider),
            _buildFilterOption(TripType.multiDay, 'Road Trips', provider),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(TripType? type, String label, TimelineProvider provider) {
    final isSelected = provider.filterType == type;
    return ListTile(
      leading: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off),
      title: Text(label),
      selected: isSelected,
      onTap: () {
        HapticFeedback.mediumImpact();
        provider.setFilterType(type);
        Navigator.pop(context);
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
