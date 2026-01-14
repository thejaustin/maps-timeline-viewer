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
        color: theme.cardTheme.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Zoom controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${DateFormat.MMMd().format(widget.startDate)} - ${DateFormat.MMMd().format(widget.endDate)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        iconSize: 18,
                        onPressed: _zoomOut,
                        tooltip: 'Zoom out',
                        splashRadius: 20,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _zoomLevelText,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        iconSize: 18,
                        onPressed: _zoomIn,
                        tooltip: 'Zoom in',
                        splashRadius: 20,
                      ),
                    ],
                  ),
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
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isToday
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    DateFormat.E().format(date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isToday
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isToday
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainer,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isToday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      width: isToday ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat.d().format(date),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                        color: isToday
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
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
                          margin: const EdgeInsets.only(bottom: 3),
                          height: 10,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? trip.color
                                : trip.color.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: isSelected
                                  ? trip.color
                                  : trip.color.withOpacity(0.6),
                              width: isSelected ? 1.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: trip.color.withOpacity(0.3),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
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
