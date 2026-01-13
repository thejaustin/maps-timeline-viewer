import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/json_parser.dart';
import '../services/database_service.dart';
import '../services/trip_detector.dart';
import '../providers/timeline_provider.dart';
import '../models/location.dart';
import 'map_screen.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _isImporting = false;
  double _progress = 0.0;
  String _statusMessage = '';
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _checkExistingData();
  }

  Future<void> _checkExistingData() async {
    final count = await DatabaseService.instance.getTotalLocationCount();
    if (count > 0 && mounted) {
      _showExistingDataDialog(count);
    }
  }

  void _showExistingDataDialog(int count) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Existing Data Found'),
        content: Text('Found $count locations in database. Load existing data or import new file?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAndImport();
            },
            child: const Text('Import New'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _loadExistingData();
            },
            child: const Text('Load Existing'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadExistingData() async {
    final provider = context.read<TimelineProvider>();
    await provider.loadAllTrips();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MapScreen()),
      );
    }
  }

  Future<void> _clearAndImport() async {
    await DatabaseService.instance.clearAllData();
    _pickFile();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      _importFile(result.files.single.path!);
    }
  }

  Future<void> _importFile(String filePath) async {
    setState(() {
      _isImporting = true;
      _progress = 0.0;
      _statusMessage = 'Starting import...';
      _logs.clear();
    });

    try {
      _addLog('Selected file: $filePath');

      // Parse JSON
      final progressController = StreamController<ParseProgress>();
      progressController.stream.listen((progress) {
        setState(() {
          _progress = progress.progress * 0.7; // 70% for parsing
          _statusMessage = progress.message;
          _addLog(progress.message);
        });
      });

      final locations = await JsonParserService.parseFile(filePath, progressController);
      await progressController.close();

      _addLog('Parsed ${locations.length} locations');

      // Detect trips
      setState(() {
        _progress = 0.75;
        _statusMessage = 'Detecting trips...';
      });
      _addLog('Detecting trips...');

      final colorScheme = Theme.of(context).colorScheme;
      final trips = TripDetector.detectTrips(locations, colorScheme);
      _addLog('Detected ${trips.length} trips');

      // Save to database
      setState(() {
        _progress = 0.85;
        _statusMessage = 'Saving to database...';
      });
      _addLog('Saving to database...');

      final db = DatabaseService.instance;
      for (var i = 0; i < trips.length; i++) {
        final trip = trips[i];
        final tripId = await db.insertTrip(trip);

        // Update trip_id for all locations
        final tripLocations = trip.locations!.map((loc) {
          return Location(
            tripId: tripId,
            timestamp: loc.timestamp,
            latitude: loc.latitude,
            longitude: loc.longitude,
            accuracy: loc.accuracy,
          );
        }).toList();

        await db.insertLocations(tripLocations);

        if ((i + 1) % 10 == 0) {
          setState(() {
            _progress = 0.85 + (i / trips.length) * 0.15;
            _statusMessage = 'Saved ${i + 1} / ${trips.length} trips';
          });
        }
      }

      _addLog('Database saved successfully');

      // Load data and navigate
      setState(() {
        _progress = 1.0;
        _statusMessage = 'Complete!';
      });
      _addLog('Import complete!');

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        final provider = context.read<TimelineProvider>();
        await provider.loadAllTrips();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      }
    } catch (e) {
      _addLog('ERROR: $e');
      setState(() {
        _statusMessage = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Maps Timeline Viewer',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Import your Google Maps Timeline data',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),
                if (!_isImporting) ...[
                  FilledButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Select JSON File'),
                  ),
                ] else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LinearProgressIndicator(value: _progress),
                          const SizedBox(height: 16),
                          Text(
                            _statusMessage,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: ListView.builder(
                              reverse: true,
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                final logIndex = _logs.length - 1 - index;
                                return Text(
                                  _logs[logIndex],
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
