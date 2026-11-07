import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/ticket.dart';
import 'ticket_database_factory.dart'
    if (dart.library.html) 'ticket_database_factory_web.dart';

class TicketStorage {
  TicketStorage({this.databasePath, this.databaseName = 'tickets.db'});

  static const _legacyStorageKey = 'saved_demo_tickets';
  static const _legacyMigrationKey = 'saved_tickets_sqlite_migrated';
  static const _webStorageKey = 'saved_tickets_web';
  static const _syncKey = 'saved_tickets_last_synced';
  static const _ticketTable = 'tickets';
  static const _syncTable = 'ticket_sync';

  final String? databasePath;
  final String databaseName;
  Future<Database>? _database;

  Future<Database> get _db => _database ??= _openDatabase();

  Future<Database> _openDatabase() async {
    if (!kIsWeb) initializeTicketDatabaseFactory();
    final resolvedPath =
        databasePath ?? path.join(await getDatabasesPath(), databaseName);
    final database = await openDatabase(
      resolvedPath,
      version: 2,
      onCreate: (db, version) => _createTables(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        final columns = await db.rawQuery('PRAGMA table_info($_ticketTable)');
        final names = columns.map((column) => column['name']).toSet();
        if (names.contains('id') && !names.contains('ticket_id')) {
          final oldTickets = await db.query(_ticketTable);
          await db.execute(
            'ALTER TABLE $_ticketTable RENAME TO tickets_legacy',
          );
          await _createTables(db);
          for (final row in oldTickets) {
            final ticket = Ticket(
              id: row['id']?.toString() ?? '',
              eventName: row['event_name']?.toString() ?? 'Event',
              date: row['event_date']?.toString() ?? '',
              venue: row['venue']?.toString() ?? '',
              price: (row['ticket_price'] as num?)?.toInt() ?? 0,
              status: row['status']?.toString() ?? 'Confirmed',
              qrData: row['qr_code_data']?.toString() ?? '',
              downloadedAt: row['download_date']?.toString() ?? '',
              ticketType: row['ticket_type']?.toString() ?? 'Standard',
              purchasedOn: row['purchased_on']?.toString() ?? '',
              imagePath: row['image_path']?.toString() ?? '',
            );
            await db.insert(_ticketTable, _ticketRow(ticket, DateTime.now()));
          }
          await db.execute('DROP TABLE tickets_legacy');
        } else {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_syncTable (
              user_id TEXT PRIMARY KEY NOT NULL,
              synced_at TEXT NOT NULL
            )
          ''');
        }
      },
    );
    await _migrateLegacyTickets(database);
    return database;
  }

  Future<void> _createTables(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $_ticketTable (
        user_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, ticket_id)
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $_syncTable (
        user_id TEXT PRIMARY KEY NOT NULL,
        synced_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _migrateLegacyTickets(Database database) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_legacyMigrationKey) ?? false) return;

    final legacyJson = preferences.getString(_legacyStorageKey);
    if (legacyJson != null) {
      final decoded = jsonDecode(legacyJson);
      if (decoded is! List) {
        throw const FormatException('Saved ticket data is invalid.');
      }
      final tickets = decoded
          .whereType<Map>()
          .map((item) => Ticket.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      await database.transaction((transaction) async {
        for (final ticket in tickets) {
          await transaction.insert(
            _ticketTable,
            _ticketRow(ticket, DateTime.now()),
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

  Future<List<Ticket>> getSavedTickets({String? userId}) async {
    if (kIsWeb) {
      final tickets = await _readWebTickets();
      return userId == null
          ? tickets
          : tickets.where((ticket) => ticket.userId == userId).toList();
    }

    final rows = await (await _db).query(
      _ticketTable,
      where: userId == null ? null : 'user_id = ?',
      whereArgs: userId == null ? null : [userId],
      orderBy: 'updated_at ASC',
    );
    return rows.map(_ticketFromRow).toList();
  }

  Future<Ticket?> getTicket(String id, {String? userId}) async {
    if (kIsWeb) {
      final tickets = await _readWebTickets();
      for (final ticket in tickets) {
        if (ticket.id == id && (userId == null || ticket.userId == userId)) {
          return ticket;
        }
      }
      return null;
    }

    final rows = await (await _db).query(
      _ticketTable,
      where: userId == null ? 'ticket_id = ?' : 'ticket_id = ? AND user_id = ?',
      whereArgs: userId == null ? [id] : [id, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : _ticketFromRow(rows.first);
  }

  Future<void> saveTicket(Ticket ticket) async {
    _validateTickets([ticket]);
    if (kIsWeb) {
      final tickets = await _readWebTickets();
      if (tickets.any((saved) => _key(saved) == _key(ticket))) return;
      await _writeWebTickets([...tickets, ticket]);
      return;
    }

    await (await _db).insert(
      _ticketTable,
      _ticketRow(ticket, DateTime.now()),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> saveTickets(List<Ticket> tickets) async {
    if (tickets.isEmpty) return;
    _validateTickets(tickets);
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
    final timestamp = DateTime.now();
    for (final ticket in tickets) {
      batch.insert(
        _ticketTable,
        _ticketRow(ticket, timestamp),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateTicket(Ticket ticket) async {
    final existing = await getTicket(ticket.id, userId: ticket.userId);
    if (existing == null) return;
    final updated = ticket.copyWith(downloadedAt: existing.downloadedAt);

    if (kIsWeb) {
      final tickets = await _readWebTickets();
      await _writeWebTickets(
        tickets
            .map((saved) => _key(saved) == _key(updated) ? updated : saved)
            .toList(),
      );
      return;
    }

    await (await _db).update(
      _ticketTable,
      _ticketRow(updated, DateTime.now()),
      where: 'ticket_id = ? AND user_id = ?',
      whereArgs: [updated.id, updated.userId],
    );
  }

  Future<void> synchronizeUserTickets(
    String userId,
    List<Ticket> remoteTickets,
  ) async {
    if (userId.isEmpty) throw ArgumentError.value(userId, 'userId');
    if (remoteTickets.any((ticket) => ticket.userId != userId)) {
      throw StateError('Cannot cache tickets owned by another user.');
    }

    final timestamp = DateTime.now();
    if (kIsWeb) {
      final saved = await _readWebTickets();
      final otherUsers = saved.where((ticket) => ticket.userId != userId);
      await _writeWebTickets([...otherUsers, ...remoteTickets]);
    } else {
      final database = await _db;
      await database.transaction((transaction) async {
        await transaction.delete(
          _ticketTable,
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        for (final ticket in remoteTickets) {
          await transaction.insert(
            _ticketTable,
            _ticketRow(ticket, timestamp),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await transaction.insert(_syncTable, {
          'user_id': userId,
          'synced_at': timestamp.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    }

    final preferences = await SharedPreferences.getInstance();
    final updated = await preferences.setString(
      _syncKey,
      timestamp.toIso8601String(),
    );
    if (!updated) throw StateError('Could not save the ticket sync time.');
  }

  Future<void> refreshSavedTickets(List<Ticket> remoteTickets) async {
    if (remoteTickets.isEmpty) return;
    final saved = await getSavedTickets();
    final byKey = {for (final ticket in remoteTickets) _key(ticket): ticket};
    final updatedTickets = saved.map((ticket) {
      final remote = byKey[_key(ticket)];
      return remote == null
          ? ticket
          : remote.copyWith(downloadedAt: ticket.downloadedAt);
    }).toList();

    if (kIsWeb) {
      await _writeWebTickets(updatedTickets);
    } else {
      final database = await _db;
      await database.transaction((transaction) async {
        for (final ticket in updatedTickets) {
          await transaction.update(
            _ticketTable,
            _ticketRow(ticket, DateTime.now()),
            where: 'ticket_id = ? AND user_id = ?',
            whereArgs: [ticket.id, ticket.userId],
          );
        }
      });
    }

    final preferences = await SharedPreferences.getInstance();
    final updated = await preferences.setString(
      _syncKey,
      DateTime.now().toIso8601String(),
    );
    if (!updated) throw StateError('Could not save the ticket sync time.');
  }

  Future<DateTime?> getLastSynced({String? userId}) async {
    if (userId == null || userId.isEmpty) {
      final raw = (await SharedPreferences.getInstance()).getString(_syncKey);
      return raw == null ? null : DateTime.tryParse(raw);
    }
    if (kIsWeb) return null;

    final rows = await (await _db).query(
      _syncTable,
      columns: ['synced_at'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    final value = rows.isEmpty ? null : rows.first['synced_at'];
    return value is String ? DateTime.tryParse(value) : null;
  }

  Future<void> deleteTicket(String id, {String? userId}) async {
    final ownerId = userId ?? '';
    if (kIsWeb) {
      final tickets = await _readWebTickets();
      await _writeWebTickets(
        tickets
            .where((ticket) => ticket.id != id || ticket.userId != ownerId)
            .toList(),
      );
      return;
    }

    await (await _db).delete(
      _ticketTable,
      where: 'ticket_id = ? AND user_id = ?',
      whereArgs: [id, ownerId],
    );
  }

  Future<void> close() async {
    final databaseFuture = _database;
    if (databaseFuture == null) return;
    await (await databaseFuture).close();
    _database = null;
  }

  Map<String, Object?> _ticketRow(Ticket ticket, DateTime updatedAt) => {
    'user_id': ticket.userId,
    'ticket_id': ticket.id,
    'payload': jsonEncode(
      ticket
          .copyWith(
            downloadedAt: ticket.downloadedAt.isEmpty
                ? updatedAt.toIso8601String()
                : ticket.downloadedAt,
          )
          .toJson(),
    ),
    'updated_at': updatedAt.toIso8601String(),
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
    final saved = await preferences.setString(
      _webStorageKey,
      jsonEncode(tickets.map((ticket) => ticket.toJson()).toList()),
    );
    if (!saved) throw StateError('Could not save tickets on this device.');
  }

  String _key(Ticket ticket) => '${ticket.userId}:${ticket.id}';

  void _validateTickets(List<Ticket> tickets) {
    if (tickets.any((ticket) => ticket.id.isEmpty)) {
      throw StateError('Tickets must have an ID.');
    }
  }
}
