import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/location.dart';
import '../models/trip.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('timeline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE trips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        type INTEGER NOT NULL,
        color INTEGER NOT NULL,
        location_count INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy INTEGER NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX idx_trips_time ON trips (start_time, end_time)');
    await db.execute('CREATE INDEX idx_locations_trip ON locations (trip_id)');
    await db.execute('CREATE INDEX idx_locations_time ON locations (timestamp)');
  }

  Future<int> insertTrip(Trip trip) async {
    final db = await database;
    return await db.insert('trips', trip.toMap());
  }

  Future<List<int>> insertLocations(List<Location> locations) async {
    final db = await database;
    final batch = db.batch();
    for (final location in locations) {
      batch.insert('locations', location.toMap());
    }
    final results = await batch.commit();
    return results.cast<int>();
  }

  Future<List<Trip>> getTripsInRange(DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.query(
      'trips',
      where: 'start_time <= ? AND end_time >= ?',
      whereArgs: [end.millisecondsSinceEpoch, start.millisecondsSinceEpoch],
      orderBy: 'start_time ASC',
    );
    return result.map((map) => Trip.fromMap(map)).toList();
  }

  Future<List<Location>> getLocationsForTrip(int tripId) async {
    final db = await database;
    final result = await db.query(
      'locations',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
    );
    return result.map((map) => Location.fromMap(map)).toList();
  }

  Future<List<Trip>> getAllTrips() async {
    final db = await database;
    final result = await db.query('trips', orderBy: 'start_time ASC');
    return result.map((map) => Trip.fromMap(map)).toList();
  }

  Future<int> getTotalLocationCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM locations');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('locations');
    await db.delete('trips');
  }

  // Optimized method to save all trips and locations in a single transaction
  Future<void> saveTrips(List<Trip> trips, Function(double) onProgress) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < trips.length; i++) {
        final trip = trips[i];
        
        // Insert trip using the transaction
        final tripId = await txn.insert('trips', trip.toMap());
        
        // Batch insert locations for this trip
        final batch = txn.batch();
        if (trip.locations != null) {
          for (final loc in trip.locations!) {
            batch.insert('locations', {
              'trip_id': tripId,
              'timestamp': loc.timestamp.millisecondsSinceEpoch,
              'latitude': loc.latitude,
              'longitude': loc.longitude,
              'accuracy': loc.accuracy,
            });
          }
        }
        await batch.commit(noResult: true);
        
        if (i % 10 == 0) {
          onProgress(i / trips.length);
        }
      }
    });
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
