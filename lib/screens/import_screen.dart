import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        icon: const Icon(Icons.storage),
        title: const Text('Existing Data Found'),
        content: Text('Found $count locations in database. Load existing data or import new file?'),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              _clearAndImport();
            },
            child: const Text('Import New'),
          ),
          FilledButton.tonal(
            onPressed: () {
              HapticFeedback.mediumImpact();
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
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MapScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        ),
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
      HapticFeedback.mediumImpact();
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
        if (progress.progress >= 0.7) {
          HapticFeedback.selectionClick();
        }
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

      await DatabaseService.instance.saveTrips(trips, (progress) {
        if (mounted) {
          setState(() {
            _progress = 0.85 + progress * 0.15;
            _statusMessage = 'Saved ${(_progress * 100).toInt()}% of trips';
          });
        }
      });

      _addLog('Database saved successfully');

      // Load data and navigate
      setState(() {
        _progress = 1.0;
        _statusMessage = 'Complete!';
      });
      _addLog('Import complete!');
      HapticFeedback.heavyImpact();

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        final provider = context.read<TimelineProvider>();
        await provider.loadAllTrips();

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MapScreen(),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    } catch (e) {
      _addLog('ERROR: $e');
      HapticFeedback.vibrate();
      setState(() {
        _statusMessage = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Import failed: $e'),
            action: SnackBarAction(label: 'Retry', onPressed: _pickFile),
          ),
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _isImporting ? _buildImportingState() : _buildInitialState(),
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      key: const ValueKey('initial'),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 1),
              builder: (context, double value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.5 + (value * 0.5),
                    child: child,
                  ),
                );
              },
              child: Icon(
                Icons.map,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Maps Timeline Viewer',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Import your Google Maps Timeline data',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 64),
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _pickFile();
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Select JSON File'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportingState() {
    return Center(
      key: const ValueKey('importing'),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: _progress),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, child) {
                    return Column(
                      children: [
                        LinearProgressIndicator(
                          value: value,
                          borderRadius: BorderRadius.circular(8),
                          minHeight: 12,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${(value * 100).toInt()}%',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _statusMessage,
                    key: ValueKey(_statusMessage),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final logIndex = _logs.length - 1 - index;
                      return FadeInLog(
                        key: ValueKey(_logs[logIndex]),
                        message: _logs[logIndex],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FadeInLog extends StatelessWidget {
  final String message;
  const FadeInLog({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
          ),
        );
      },
    );
  }
}