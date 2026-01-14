import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import '../models/location.dart';

class ParseProgress {
  final String message;
  final double progress; // 0.0 to 1.0

  ParseProgress(this.message, this.progress);
}

class JsonParserService {
  static Future<List<Location>> parseFile(
    String filePath,
    StreamController<ParseProgress> progressController,
  ) async {
    final receivePort = ReceivePort();
    final sendPort = receivePort.sendPort;

    await Isolate.spawn(
      _parseInIsolate,
      [sendPort, filePath],
    );

    final locations = <Location>[];
    await for (final message in receivePort) {
      if (message is SendPort) {
        // Ready to receive progress updates
        continue;
      } else if (message is ParseProgress) {
        progressController.add(message);
      } else if (message is List<Location>) {
        locations.addAll(message);
      } else if (message == 'done') {
        break;
      } else if (message is String && message.startsWith('error:')) {
        throw Exception(message.substring(6));
      }
    }

    return locations;
  }

  static Future<void> _parseInIsolate(List<dynamic> args) async {
    final sendPort = args[0] as SendPort;
    final filePath = args[1] as String;

    try {
      final file = File(filePath);
      final fileSize = await file.length();
      var bytesRead = 0;

      sendPort.send(ParseProgress('Reading file...', 0.0));

      final content = await file.readAsString();
      bytesRead = content.length;

      sendPort.send(ParseProgress('Parsing JSON...', 0.3));

      final json = jsonDecode(content) as Map<String, dynamic>;
      final locationsJson = json['locations'] as List<dynamic>?;
      final semanticSegments = json['semanticSegments'] as List<dynamic>?;

      if (locationsJson == null && semanticSegments == null) {
        sendPort.send('error:Invalid JSON format - missing "locations" or "semanticSegments" array');
        return;
      }

      final locations = <Location>[];
      var processed = 0;

      if (locationsJson != null) {
        sendPort.send(ParseProgress(
          'Processing ${locationsJson.length} locations...',
          0.5,
        ));

        for (final locationJson in locationsJson) {
          try {
            final location = Location.fromJson(locationJson as Map<String, dynamic>);
            locations.add(location);
          } catch (e) {
            // Skip invalid locations
            continue;
          }

          processed++;
          if (processed % 1000 == 0) {
            final progress = 0.5 + (processed / locationsJson.length) * 0.5;
            sendPort.send(ParseProgress(
              'Processed $processed / ${locationsJson.length} locations',
              progress,
            ));
          }
        }
      } else if (semanticSegments != null) {
        sendPort.send(ParseProgress(
          'Processing ${semanticSegments.length} segments...',
          0.5,
        ));

        for (final segment in semanticSegments) {
          final segMap = segment as Map<String, dynamic>;
          final timelinePath = segMap['timelinePath'] as List<dynamic>?;

          if (timelinePath != null) {
            for (final pointMap in timelinePath) {
              try {
                final point = pointMap['point'] as String;
                final time = pointMap['time'] as String;

                // Parse point "33.2764261°, -86.8695109°"
                final parts = point.split(', ');
                if (parts.length != 2) continue;

                final lat = double.parse(parts[0].replaceAll('°', ''));
                final lng = double.parse(parts[1].replaceAll('°', ''));
                final timestamp = DateTime.parse(time);

                locations.add(Location(
                  timestamp: timestamp,
                  latitude: lat,
                  longitude: lng,
                  accuracy: 0,
                ));

                processed++;
              } catch (e) {
                continue;
              }
            }
          }
          
          if (processed % 1000 == 0) {
            sendPort.send(ParseProgress(
              'Processed $processed locations from segments',
              0.5,
            ));
          }
        }
      }

      sendPort.send(ParseProgress(
        'Parsed ${locations.length} locations',
        1.0,
      ));

      // Send locations in chunks to avoid overwhelming the main isolate
      const chunkSize = 5000;
      for (var i = 0; i < locations.length; i += chunkSize) {
        final end = (i + chunkSize < locations.length) ? i + chunkSize : locations.length;
        sendPort.send(locations.sublist(i, end));
      }

      sendPort.send('done');
    } catch (e) {
      sendPort.send('error:${e.toString()}');
    }
  }
}
