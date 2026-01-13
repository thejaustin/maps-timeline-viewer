import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';

class TimelineScrollbar extends StatefulWidget {
  final List<Trip> allTrips;
  final Set<int> selectedTripIds;
  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTime start, DateTime end) onDateRangeChanged;
  final Function(int tripId) onTripTapped;

  const TimelineScrollbar({
    super.key,
    required this.allTrips,
    required this.selectedTripIds,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
    required this.onTripTapped,
  });

  @override
  State<TimelineScrollbar> createState() => _TimelineScrollbarState();
}

class _TimelineScrollbarState extends State<TimelineScrollbar> {
  final ScrollController _scrollController = ScrollController();
  static const double _dayWidth = 60.0;
  int _zoomLevel = 1; // 0=day, 1=week, 2=month

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rangeDays = widget.endDate.difference(widget.startDate).inDays + 1;

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Zoom controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                Text(
                  '${DateFormat.MMMd().format(widget.startDate)} - ${DateFormat.MMMd().format(widget.endDate)}',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove),
                  iconSize: 20,
                  onPressed: _zoomOut,
                  tooltip: 'Zoom out',
                ),
                Text(_zoomLevelText),
                IconButton(
                  icon: const Icon(Icons.add),
                  iconSize: 20,
                  onPressed: _zoomIn,
                  tooltip: 'Zoom in',
                ),
              ],
            ),
          ),
          // Timeline
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: rangeDays,
              itemBuilder: (context, index) {
                final date = widget.startDate.add(Duration(days: index));
                final tripsOnDay = _getTripsOnDay(date);

                return _buildDayColumn(date, tripsOnDay, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(DateTime date, List<Trip> trips, ThemeData theme) {
    final isToday = _isToday(date);

    return Container(
      width: _dayWidth,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        color: isToday ? theme.colorScheme.primaryContainer.withOpacity(0.3) : null,
      ),
      child: Column(
        children: [
          // Date label
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              children: [
                Text(
                  DateFormat.E().format(date),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  DateFormat.d().format(date),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          // Trip indicators
          Expanded(
            child: trips.isEmpty
                ? const SizedBox()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    itemCount: trips.length,
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      final isSelected = widget.selectedTripIds.contains(trip.id);

                      return GestureDetector(
                        onTap: () => widget.onTripTapped(trip.id!),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          height: 8,
                          decoration: BoxDecoration(
                            color: isSelected ? trip.color : trip.color.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<Trip> _getTripsOnDay(DateTime date) {
    return widget.allTrips.where((trip) {
      final tripStart = DateTime(
        trip.startTime.year,
        trip.startTime.month,
        trip.startTime.day,
      );
      final tripEnd = DateTime(
        trip.endTime.year,
        trip.endTime.month,
        trip.endTime.day,
      );
      final checkDate = DateTime(date.year, date.month, date.day);

      return checkDate.compareTo(tripStart) >= 0 && checkDate.compareTo(tripEnd) <= 0;
    }).toList();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  void _zoomIn() {
    if (_zoomLevel > 0) {
      setState(() => _zoomLevel--);
      _updateDateRange();
    }
  }

  void _zoomOut() {
    if (_zoomLevel < 2) {
      setState(() => _zoomLevel++);
      _updateDateRange();
    }
  }

  String get _zoomLevelText {
    switch (_zoomLevel) {
      case 0:
        return 'Day';
      case 1:
        return 'Week';
      case 2:
        return 'Month';
      default:
        return 'Week';
    }
  }

  void _updateDateRange() {
    final now = DateTime.now();
    DateTime start, end;

    switch (_zoomLevel) {
      case 0: // Day view
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
        break;
      case 1: // Week view
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = start.add(const Duration(days: 7));
        break;
      case 2: // Month view
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0);
        break;
      default:
        start = now.subtract(const Duration(days: 7));
        end = now;
    }

    widget.onDateRangeChanged(start, end);
  }
}
