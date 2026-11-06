import 'dart:convert';

import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/ticket.dart';

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
    );
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
  }
}
