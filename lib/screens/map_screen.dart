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

  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: Consumer<TimelineProvider>(
        builder: (context, provider, child) {
          if (_isSearching) {
            return AppBar(
              title: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search trips...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  provider.setSearchQuery(value);
                },
                onSubmitted: (value) {
                  // Close search when submitted
                  setState(() {
                    _isSearching = false;
                  });
                },
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                  });
                  provider.setSearchQuery(''); // Clear search
                },
              ),
              actions: [
                if (provider.searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      provider.setSearchQuery('');
                    },
                  ),
              ],
            );
          } else {
            return AppBar(
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
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showFilterDialog();
                  },
                ),
                PopupMenuButton<ViewMode>(
                  icon: const Icon(Icons.view_carousel),
                  onSelected: (ViewMode mode) {
                    HapticFeedback.lightImpact();
                    context.read<TimelineProvider>().setViewMode(mode);
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<ViewMode>>[
                    PopupMenuItem<ViewMode>(
                      value: ViewMode.timeline,
                      child: Row(
                        children: [
                          Icon(_getViewModeIcon(ViewMode.timeline)),
                          const SizedBox(width: 8),
                          const Text('Timeline View'),
                        ],
                      ),
                    ),
                    PopupMenuItem<ViewMode>(
                      value: ViewMode.allTime,
                      child: Row(
                        children: [
                          Icon(_getViewModeIcon(ViewMode.allTime)),
                          const SizedBox(width: 8),
                          const Text('All Time View'),
                        ],
                      ),
                    ),
                    PopupMenuItem<ViewMode>(
                      value: ViewMode.byState,
                      child: Row(
                        children: [
                          Icon(_getViewModeIcon(ViewMode.byState)),
                          const SizedBox(width: 8),
                          const Text('By State View'),
                        ],
                      ),
                    ),
                    PopupMenuItem<ViewMode>(
                      value: ViewMode.byCity,
                      child: Row(
                        children: [
                          Icon(_getViewModeIcon(ViewMode.byCity)),
                          const SizedBox(width: 8),
                          const Text('By City View'),
                        ],
                      ),
                    ),
                    PopupMenuItem<ViewMode>(
                      value: ViewMode.statistics,
                      child: Row(
                        children: [
                          Icon(_getViewModeIcon(ViewMode.statistics)),
                          const SizedBox(width: 8),
                          const Text('Statistics View'),
                        ],
                      ),
                    ),
                    PopupMenuItem<ViewMode>(
                      value: ViewMode.heatmap,
                      child: Row(
                        children: [
                          Icon(_getViewModeIcon(ViewMode.heatmap)),
                          const SizedBox(width: 8),
                          const Text('Heatmap View'),
                        ],
                      ),
                    ),
                    PopupMenuItem<ViewMode>(
                      value: ViewMode.calendar,
                      child: Row(
                        children: [
                          Icon(_getViewModeIcon(ViewMode.calendar)),
                          const SizedBox(width: 8),
                          const Text('Calendar View'),
                        ],
                      ),
                    ),
                    PopupMenuItem<ViewMode>(
                      value: ViewMode.route,
                      child: Row(
                        children: [
                          Icon(_getViewModeIcon(ViewMode.route)),
                          const SizedBox(width: 8),
                          const Text('Route View'),
                        ],
                      ),
                    ),
                    PopupMenuItem<ViewMode>(
                      value: ViewMode.activity,
                      child: Row(
                        children: [
                          Icon(_getViewModeIcon(ViewMode.activity)),
                          const SizedBox(width: 8),
                          const Text('Activity View'),
                        ],
                      ),
                    ),
                    PopupMenuItem<ViewMode>(
                      value: ViewMode.favorites,
                      child: Row(
                        children: [
                          Icon(_getViewModeIcon(ViewMode.favorites)),
                          const SizedBox(width: 8),
                          const Text('Favorites View'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
        },
      ),
      drawer: _buildTripDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showQuickActions(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('Actions'),
      ),
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

          // Preload locations for visible trips to improve performance
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (provider.visibleTrips.isNotEmpty) {
              provider.preloadVisibleTripLocations();
            }
          });

          // Determine which trips to display based on search and view mode
          List<Trip> tripsToDisplay = provider.selectedTrips;
          List<Trip> allTripsForScrollbar = provider.visibleTrips;

          // If search is active, use search results instead
          if (provider.searchQuery.isNotEmpty) {
            tripsToDisplay = provider.searchResults;
            allTripsForScrollbar = provider.searchResults;
          }

          // Render different views based on the selected ViewMode
          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // Main content based on view mode
                    switch (provider.viewMode) {
                      case ViewMode.timeline:
                        Stack(
                          children: [
                            Column(
                              children: [
                                Expanded(
                                  child: TripMapWidget(
                                    trips: tripsToDisplay,
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  height: 120,
                                  child: TimelineScrollbar(
                                    allTrips: allTripsForScrollbar,
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
                            ),
                            // Progress indicator for large datasets
                            if (tripsToDisplay.any((trip) => trip.locationCount > 1000))
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardTheme.color,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Loading large dataset...',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      case ViewMode.allTime:
                        Column(
                          children: [
                            Expanded(
                              child: TripMapWidget(
                                trips: provider.allTrips,
                              ),
                            ),
                            // For all-time view, show a summary instead of timeline scrollbar
                            Container(
                              height: 120,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'All Time Summary',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          _buildSummaryCard('Total Trips', provider.allTrips.length.toString()),
                                          const SizedBox(width: 8),
                                          _buildSummaryCard('Total Days', _calculateTotalDays(provider.allTrips).toString()),
                                          const SizedBox(width: 8),
                                          _buildSummaryCard('Types', _getTripTypeCounts(provider.allTrips)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      case ViewMode.byState:
                      case ViewMode.byCity:
                        _buildGeographicView(provider),
                      case ViewMode.statistics:
                        _buildStatisticsView(provider),
                      case ViewMode.heatmap:
                        _buildHeatmapView(provider),
                      case ViewMode.calendar:
                        _buildCalendarView(provider),
                      case ViewMode.route:
                        _buildRouteView(provider),
                      case ViewMode.activity:
                        _buildActivityView(provider),
                      case ViewMode.favorites:
                        _buildFavoritesView(provider),
                    },
                  ],
                ),
              ),
              // Bottom Navigation Bar
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
                child: BottomNavigationBar(
                  currentIndex: _getViewModeIndex(provider.viewMode),
                  onTap: (index) {
                    HapticFeedback.selectionClick();
                    context.read<TimelineProvider>().setViewMode(_getViewModeFromIndex(index));
                  },
                  type: BottomNavigationBarType.fixed,
                  items: [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.timeline),
                      label: 'Timeline',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.calendar_today),
                      label: 'Calendar',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.route),
                      label: 'Routes',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.bar_chart),
                      label: 'Stats',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.bookmark),
                      label: 'Favs',
                    ),
                  ],
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
            // Use search results if search is active, otherwise use visible trips
            final tripsToShow = provider.searchQuery.isNotEmpty 
                ? provider.searchResults 
                : provider.visibleTrips;

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
                            // Select all trips based on current view
                            if (provider.searchQuery.isNotEmpty) {
                              provider.setSelectedTripIds(tripsToShow.map((t) => t.id!).toSet());
                            } else {
                              provider.selectAllTrips();
                            }
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
                    itemCount: tripsToShow.length,
                    itemBuilder: (context, index) {
                      final trip = tripsToShow[index];
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
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _showTripDetails(context, trip);
                        },
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

  IconData _getViewModeIcon(ViewMode mode) {
    switch (mode) {
      case ViewMode.timeline:
        return Icons.timeline;
      case ViewMode.allTime:
        return Icons.access_time;
      case ViewMode.byState:
        return Icons.flag;
      case ViewMode.byCity:
        return Icons.location_city;
      case ViewMode.statistics:
        return Icons.bar_chart;
      case ViewMode.heatmap:
        return Icons.heat_map;
      case ViewMode.calendar:
        return Icons.calendar_month;
      case ViewMode.route:
        return Icons.route;
      case ViewMode.activity:
        return Icons.directions_walk;
      case ViewMode.favorites:
        return Icons.bookmark;
    }
  }

  int _getViewModeIndex(ViewMode mode) {
    switch (mode) {
      case ViewMode.timeline:
        return 0;
      case ViewMode.calendar:
        return 1;
      case ViewMode.route:
        return 2;
      case ViewMode.statistics:
        return 3;
      case ViewMode.favorites:
        return 4;
      // For modes not shown in bottom nav, return a default
      case ViewMode.allTime:
      case ViewMode.byState:
      case ViewMode.byCity:
      case ViewMode.heatmap:
      case ViewMode.activity:
        return 0; // Default to timeline
    }
  }

  ViewMode _getViewModeFromIndex(int index) {
    switch (index) {
      case 0:
        return ViewMode.timeline;
      case 1:
        return ViewMode.calendar;
      case 2:
        return ViewMode.route;
      case 3:
        return ViewMode.statistics;
      case 4:
        return ViewMode.favorites;
      default:
        return ViewMode.timeline;
    }
  }

  Widget _buildGeographicView(TimelineProvider provider) {
    // Group trips by location (state/city)
    Map<String, List<Trip>> groupedTrips = {};
    
    for (final trip in provider.allTrips) {
      if (trip.locations != null && trip.locations!.isNotEmpty) {
        // For demo purposes, we'll use a simple location identifier
        // In a real implementation, you would geocode the locations to get state/city
        String locationKey = 'Unknown Location';
        
        // Use the first location as representative
        final firstLocation = trip.locations!.first;
        // In a real implementation, you would reverse geocode to get state/city
        // For now, we'll just use coordinates as a placeholder
        locationKey = 'Lat: ${firstLocation.latitude.toStringAsFixed(2)}, Lng: ${firstLocation.longitude.toStringAsFixed(2)}';
        
        if (!groupedTrips.containsKey(locationKey)) {
          groupedTrips[locationKey] = [];
        }
        groupedTrips[locationKey]!.add(trip);
      }
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<ViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: ViewMode.byState,
                      label: Text('By State'),
                      icon: Icon(Icons.flag),
                    ),
                    ButtonSegment(
                      value: ViewMode.byCity,
                      label: Text('By City'),
                      icon: Icon(Icons.location_city),
                    ),
                  ],
                  selected: {provider.viewMode},
                  onSelectionChanged: (Set<ViewMode> newSelection) {
                    if (newSelection.isNotEmpty) {
                      context.read<TimelineProvider>().setViewMode(newSelection.first);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: groupedTrips.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No trips to display',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groupedTrips.length,
                  itemBuilder: (context, index) {
                    final entry = groupedTrips.entries.elementAt(index);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(entry.key),
                        subtitle: Text('${entry.value.length} trips'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: entry.value.map((trip) {
                                return ListTile(
                                  leading: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: trip.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  title: Text(trip.typeString),
                                  subtitle: Text(
                                    '${_formatDateTime(trip.startTime)} • ${trip.locationCount} pts',
                                  ),
                                  trailing: Text(
                                    trip.durationString ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatisticsView(TimelineProvider provider) {
    // Calculate statistics for the timeline data
    int totalTrips = provider.allTrips.length;
    int totalLocations = 0;
    int singleDrives = 0;
    int dailyTrips = 0;
    int multiDayTrips = 0;
    Duration totalTime = Duration.zero;
    double totalDistance = 0;
    
    for (final trip in provider.allTrips) {
      totalLocations += trip.locationCount;
      totalTime += trip.duration;
      
      switch (trip.type) {
        case TripType.singleDrive:
          singleDrives++;
        case TripType.daily:
          dailyTrips++;
        case TripType.multiDay:
          multiDayTrips++;
      }
      
      if (trip.totalDistance != null) {
        totalDistance += trip.totalDistance!;
      }
    }
    
    int totalDays = provider.allTrips.isNotEmpty 
        ? provider.allTrips.last.endTime.difference(provider.allTrips.first.startTime).inDays 
        : 0;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline Statistics',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildStatCard('Total Trips', totalTrips.toString()),
                const SizedBox(height: 12),
                _buildStatCard('Total Locations', totalLocations.toString()),
                const SizedBox(height: 12),
                _buildStatCard('Total Days', totalDays.toString()),
                const SizedBox(height: 12),
                _buildStatCard('Total Time', '${(totalTime.inHours ~/ 24)} days, ${(totalTime.inHours % 24)} hrs'),
                const SizedBox(height: 12),
                _buildStatCard('Total Distance', totalDistance > 1000 
                    ? '${(totalDistance / 1000).toStringAsFixed(1)} km' 
                    : '${totalDistance.toStringAsFixed(0)} m'),
                const SizedBox(height: 16),
                Text(
                  'Trip Type Distribution',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildTripTypeChart(singleDrives, dailyTrips, multiDayTrips),
                const SizedBox(height: 16),
                Text(
                  'Top Locations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildTopLocations(provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  int _calculateTotalDays(List<Trip> trips) {
    if (trips.isEmpty) return 0;
    
    DateTime earliest = trips.first.startTime;
    DateTime latest = trips.first.endTime;
    
    for (final trip in trips) {
      if (trip.startTime.isBefore(earliest)) earliest = trip.startTime;
      if (trip.endTime.isAfter(latest)) latest = trip.endTime;
    }
    
    return latest.difference(earliest).inDays;
  }

  String _getTripTypeCounts(List<Trip> trips) {
    int singleDrives = 0;
    int dailyTrips = 0;
    int multiDayTrips = 0;
    
    for (final trip in trips) {
      switch (trip.type) {
        case TripType.singleDrive:
          singleDrives++;
        case TripType.daily:
          dailyTrips++;
        case TripType.multiDay:
          multiDayTrips++;
      }
    }
    
    return '${singleDrives} SD, ${dailyTrips} DT, ${multiDayTrips} RT';
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripTypeChart(int singleDrives, int dailyTrips, int multiDayTrips) {
    int total = singleDrives + dailyTrips + multiDayTrips;
    if (total == 0) total = 1; // Avoid division by zero
    
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        children: [
          _buildChartSegment(
            singleDrives.toDouble() / total,
            Colors.blue.shade300,
            'Single Drives (${singleDrives})',
          ),
          _buildChartSegment(
            dailyTrips.toDouble() / total,
            Colors.green.shade300,
            'Daily Trips (${dailyTrips})',
          ),
          _buildChartSegment(
            multiDayTrips.toDouble() / total,
            Colors.orange.shade300,
            'Multi-Day (${multiDayTrips})',
          ),
        ],
      ),
    );
  }

  Widget _buildChartSegment(double ratio, Color color, String label) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 20,
            color: color,
            width: double.infinity,
            child: Center(
              child: Text(
                '${(ratio * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Timeline'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement share functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share functionality coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Data'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement export functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export functionality coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add),
              title: const Text('Save Current View'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement save view functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Save view functionality coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Preferences'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement preferences
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preferences coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTripDetails(BuildContext context, Trip trip) {
    Navigator.pop(context); // Close the drawer

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
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTopLocations(TimelineProvider provider) {
    // Group locations by frequency (for trips that have location data)
    Map<String, int> locationCounts = {};

    for (final trip in provider.allTrips) {
      if (trip.locations != null && trip.locations!.isNotEmpty) {
        // For demo, we'll use the first location's coordinates as a proxy for location
        // In a real implementation, you would reverse geocode to get actual place names
        final firstLoc = trip.locations!.first;
        final locationKey = '${firstLoc.latitude.toStringAsFixed(4)}, ${firstLoc.longitude.toStringAsFixed(4)}';

        locationCounts[locationKey] = (locationCounts[locationKey] ?? 0) + 1;
      }
    }

    // Sort by count
    final sortedLocations = locationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: sortedLocations.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No location data available'),
            )
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedLocations.take(5).length,
              itemBuilder: (context, index) {
                final entry = sortedLocations[index];
                return ListTile(
                  leading: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text('Location ${index + 1}'),
                  subtitle: Text(entry.key),
                  trailing: Text(
                    '${entry.value} visits',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHeatmapView(TimelineProvider provider) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.heat_map, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Heatmap View',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Visualize location density',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(TimelineProvider provider) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Calendar View',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'View trips by date',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteView(TimelineProvider provider) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Route View',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Focus on travel routes',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityView(TimelineProvider provider) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_walk, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Activity View',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'See different activities',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesView(TimelineProvider provider) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Favorites View',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Your favorite locations',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}