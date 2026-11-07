import 'dart:convert';

import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/ticket.dart';
import 'ticket_database_factory.dart'
    if (dart.library.html) 'ticket_database_factory_web.dart';

class TicketStorage {
  TicketStorage({this.databaseName = 'tickets.db'});

  static const _tableName = 'tickets';
  static const _legacyStorageKey = 'saved_demo_tickets';
  static const _legacyMigrationKey = 'saved_tickets_sqlite_migrated';
  static const _syncKey = 'saved_tickets_last_synced';

  final String databaseName;
  Future<Database>? _database;

  Future<Database> get _db => _database ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final path = join(await getDatabasesPath(), databaseName);
    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY NOT NULL,
            event_name TEXT NOT NULL,
            event_date TEXT NOT NULL,
            venue TEXT NOT NULL,
            ticket_price INTEGER NOT NULL,
            status TEXT NOT NULL,
            qr_code_data TEXT NOT NULL,
            download_date TEXT NOT NULL,
            ticket_type TEXT NOT NULL,
            purchased_on TEXT NOT NULL,
            image_path TEXT NOT NULL
          )
        ''');
      },
    );

    await _migrateLegacyTickets(database);
    return database;
  }

  Future<void> _migrateLegacyTickets(Database database) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_legacyMigrationKey) ?? false) return;

    final legacyJson = preferences.getString(_legacyStorageKey);
    if (legacyJson != null) {
      final decoded = jsonDecode(legacyJson) as List<dynamic>;
      final legacyTickets = decoded
          .map(
            (item) => Ticket.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      await database.transaction((transaction) async {
        for (final ticket in legacyTickets) {
          await transaction.insert(
            _tableName,
            _toDatabase(ticket, downloadedAt: DateTime.now().toIso8601String()),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      });
  static const _webStorageKey = 'saved_tickets_web';
  static final Map<String, Future<Database>> _databases = {};

  TicketStorage({this.databasePath});

  final String? databasePath;

  Future<Database> get _db async {
    _initializeFactory();
    final databasePath =
        this.databasePath ??
        path.join(await getDatabasesPath(), 'event_tickets.db');
    final opening = _databases.putIfAbsent(
      databasePath,
      () => _openDatabase(databasePath),
    );
    try {
      return await opening;
    } catch (_) {
      _databases.remove(databasePath);
      rethrow;
    }

    final migrated = await preferences.setBool(_legacyMigrationKey, true);
    if (!migrated) {
      throw StateError('Could not record ticket storage migration.');
    }
  }

  Map<String, Object?> _toDatabase(
    Ticket ticket, {
    String? downloadedAt,
  }) {
    return {
      'id': ticket.id,
      'event_name': ticket.eventName,
      'event_date': ticket.date,
      'venue': ticket.venue,
      'ticket_price': ticket.price,
      'status': ticket.status,
      'qr_code_data': ticket.qrData,
      'download_date':
          downloadedAt ??
          (ticket.downloadedAt.isEmpty
              ? DateTime.now().toIso8601String()
              : ticket.downloadedAt),
      'ticket_type': ticket.ticketType,
      'purchased_on': ticket.purchasedOn,
      'image_path': ticket.imagePath,
    };
  }

  Ticket _fromDatabase(Map<String, Object?> row) {
    return Ticket(
      id: row['id']! as String,
      eventName: row['event_name']! as String,
      date: row['event_date']! as String,
      venue: row['venue']! as String,
      price: row['ticket_price']! as int,
      status: row['status']! as String,
      qrData: row['qr_code_data']! as String,
      downloadedAt: row['download_date']! as String,
      ticketType: row['ticket_type']! as String,
      purchasedOn: row['purchased_on']! as String,
      imagePath: row['image_path']! as String,
    );
  }

  Future<List<Ticket>> getSavedTickets() async {
    final rows = await (await _db).query(
      _tableName,
      orderBy: 'download_date DESC, id ASC',
    );
    return rows.map(_fromDatabase).toList();
  }

  Future<Ticket?> getTicket(String id) async {
    final rows = await (await _db).query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromDatabase(rows.first);
  }

  /// Stores a downloaded ticket once; its ID is unique in the database.
  Future<void> saveTicket(Ticket ticket) async {
    await (await _db).insert(
      _tableName,
      _toDatabase(ticket),
      conflictAlgorithm: ConflictAlgorithm.ignore,
  Future<Database> _openDatabase(String databasePath) async {
    return openDatabase(
      databasePath,
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE tickets (
            user_id TEXT NOT NULL,
            ticket_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (user_id, ticket_id)
          )
        ''');
        await database.execute('''
          CREATE TABLE ticket_sync (
            user_id TEXT PRIMARY KEY NOT NULL,
            synced_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  void _initializeFactory() {
    if (!kIsWeb) initializeTicketDatabaseFactory();
  }

  Future<List<Ticket>> getSavedTickets({String? userId}) async {
    if (kIsWeb) {
      final tickets = await _readWebTickets();
      return userId == null
          ? tickets
          : tickets.where((ticket) => ticket.userId == userId).toList();
    }

    final database = await _db;
    final rows = await database.query(
      'tickets',
      where: userId == null ? null : 'user_id = ?',
      whereArgs: userId == null ? null : [userId],
      orderBy: 'updated_at ASC',
    );
    return rows.map(_ticketFromRow).toList();
  }

  Future<void> saveTicket(Ticket ticket) => saveTickets([ticket]);

  Future<void> saveTickets(List<Ticket> tickets) async {
    if (tickets.isEmpty) return;
    _validateOwners(tickets);

    if (kIsWeb) {
      final saved = await _readWebTickets();
      final byKey = {for (final ticket in saved) _key(ticket): ticket};
      for (final ticket in tickets) {
        byKey[_key(ticket)] = ticket;
      }
      await _writeWebTickets(byKey.values.toList());
      return;
    }

    final database = await _db;
    final batch = database.batch();
    final timestamp = DateTime.now().toIso8601String();
    for (final ticket in tickets) {
      batch.insert(
        'tickets',
        _ticketRow(ticket, timestamp),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Makes the authenticated backend list authoritative for this user's cache.
  Future<void> synchronizeUserTickets(
    String userId,
    List<Ticket> remoteTickets,
  ) async {
    if (userId.isEmpty) throw ArgumentError.value(userId, 'userId');
    if (remoteTickets.any((ticket) => ticket.userId != userId)) {
      throw StateError('Cannot cache tickets owned by another user.');
    }

    if (kIsWeb) {
      final saved = await _readWebTickets();
      final otherUsers = saved.where((ticket) => ticket.userId != userId);
      await _writeWebTickets([...otherUsers, ...remoteTickets]);
      return;
    }

    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.delete(
        'tickets',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      final timestamp = DateTime.now().toIso8601String();
      for (final ticket in remoteTickets) {
        await transaction.insert(
          'tickets',
          _ticketRow(ticket, timestamp),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await transaction.insert('ticket_sync', {
        'user_id': userId,
        'synced_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<DateTime?> getLastSynced({required String userId}) async {
    if (kIsWeb) return null;
    final database = await _db;
    final rows = await database.query(
      'ticket_sync',
      columns: ['synced_at'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final value = rows.isEmpty ? null : rows.first['synced_at'];
    return value is String ? DateTime.tryParse(value) : null;
  }

  /// Updates an existing ticket without changing its original download date.
  Future<void> updateTicket(Ticket ticket) async {
    final values = _toDatabase(ticket);
    values.remove('download_date');
    await (await _db).update(
      _tableName,
      values,
      where: 'id = ?',
      whereArgs: [ticket.id],
    );
  }

  /// Updates saved tickets with server data without adding or removing tickets.
  Future<void> refreshSavedTickets(List<Ticket> remote) async {
    final database = await _db;
    await database.transaction((transaction) async {
      for (final ticket in remote) {
        final values = _toDatabase(ticket)..remove('download_date');
        await transaction.update(
          _tableName,
          values,
          where: 'id = ?',
          whereArgs: [ticket.id],
        );
      }
    });

    final updated = await (await SharedPreferences.getInstance()).setString(
      _syncKey,
      DateTime.now().toIso8601String(),
    );
    if (!updated) {
      throw StateError('Could not save the ticket sync time.');
    }
  }

  Future<DateTime?> getLastSynced() async {
    final raw = (await SharedPreferences.getInstance()).getString(_syncKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> deleteTicket(String id) async {
    await (await _db).delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final databaseFuture = _database;
    if (databaseFuture == null) return;

    await (await databaseFuture).close();
    _database = null;
  Future<void> deleteTicket(String id, {String? userId}) async {
    if (userId == null || userId.isEmpty) {
      throw ArgumentError('A userId is required to remove a saved ticket.');
    }

    if (kIsWeb) {
      final tickets = await _readWebTickets();
      await _writeWebTickets(
        tickets
            .where((ticket) => ticket.id != id || ticket.userId != userId)
            .toList(),
      );
      return;
    }

    final database = await _db;
    await database.delete(
      'tickets',
      where: 'user_id = ? AND ticket_id = ?',
      whereArgs: [userId, id],
    );
  }

  Map<String, Object?> _ticketRow(Ticket ticket, String timestamp) => {
    'user_id': ticket.userId,
    'ticket_id': ticket.id,
    'payload': jsonEncode(ticket.toJson()),
    'updated_at': timestamp,
  };

  Ticket _ticketFromRow(Map<String, Object?> row) {
    final ticket = Ticket.fromJson(
      Map<String, dynamic>.from(jsonDecode(row['payload']! as String) as Map),
    );
    return ticket.copyWith(userId: row['user_id']! as String);
  }

  Future<List<Ticket>> _readWebTickets() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_webStorageKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Saved ticket data is invalid.');
    }
    return decoded
        .whereType<Map>()
        .map((item) => Ticket.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _writeWebTickets(List<Ticket> tickets) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _webStorageKey,
      jsonEncode(tickets.map((ticket) => ticket.toJson()).toList()),
    );
  }

  String _key(Ticket ticket) => '${ticket.userId}:${ticket.id}';

  void _validateOwners(List<Ticket> tickets) {
    if (tickets.any((ticket) => ticket.userId.isEmpty || ticket.id.isEmpty)) {
      throw StateError('Tickets must have an ID and an owning user.');
    }
  }
}
