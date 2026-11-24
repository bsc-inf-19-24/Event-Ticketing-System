import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/ticket.dart';
import '../core/storage/storage_scope.dart';
import 'ticket_database_factory.dart'
    if (dart.library.html) 'ticket_database_factory_web.dart';

class TicketStorage {
  TicketStorage({this.databasePath, this.databaseName = 'tickets.db'});

  static const _legacyStorageKey = 'saved_demo_tickets';
  static const _legacyMigrationKey = 'ticket_legacy_cleanup_v2';
  static const _legacyWebStorageKey = 'saved_tickets_web';
  static const _webStoragePrefix = 'saved_tickets_web';
  static const _syncKey = 'saved_tickets_last_synced';
  static const _ticketTable = 'tickets';
  static const _syncTable = 'ticket_sync';
  static final Map<String, Future<Database>> _databases = {};

  final String? databasePath;
  final String databaseName;
  Future<Database>? _database;
  String? _databaseKey;

  Future<Database> get _db async {
    if (kIsWeb) throw UnsupportedError('SQLite is unavailable on web.');
    initializeTicketDatabaseFactory();
    final file =
        databasePath ?? path.join(await getDatabasesPath(), databaseName);
    final opening = _databases.putIfAbsent(file, () => _openDatabase(file));
    _database = opening;
    _databaseKey = file;
    try {
      return await opening;
    } catch (_) {
      if (identical(_databases[file], opening)) _databases.remove(file);
      rethrow;
    }
  }

  Future<void> migrateLegacyRecords() async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(_legacyMigrationKey) ?? false) return;
      var removed = 0;
      final raw = preferences.getString(_legacyStorageKey);
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) removed += decoded.length;
        } on FormatException {
          // Discard malformed legacy storage during the one-time cleanup.
        }
        await preferences.remove(_legacyStorageKey);
      }
      final legacyWebJson = preferences.getString(_legacyWebStorageKey);
      if (legacyWebJson != null) {
        try {
          final decoded = jsonDecode(legacyWebJson);
          if (decoded is List) removed += decoded.length;
        } on FormatException {
          // Discard malformed globally scoped web ticket data.
        }
        await preferences.remove(_legacyWebStorageKey);
      }
      await preferences.setBool(_legacyMigrationKey, true);
      if (kDebugMode) debugPrint('Removed $removed legacy ticket records.');
      return;
    }
    await _migrateLegacyTickets(await _db);
  }

  Future<Database> _openDatabase(String file) async {
    final database = await openDatabase(
      file,
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
            );
            await db.insert(
              _ticketTable,
              _ticketRow(ticket, DateTime.now().toIso8601String()),
            );
          }
          await db.execute('DROP TABLE tickets_legacy');
        } else {
          await _createTables(db);
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
    var removed = 0;
    final legacyJson = preferences.getString(_legacyStorageKey);
    if (legacyJson != null) {
      try {
        final decoded = jsonDecode(legacyJson);
        if (decoded is List) removed += decoded.length;
      } on FormatException {
        // Discard malformed legacy storage during the one-time cleanup.
      }
      await preferences.remove(_legacyStorageKey);
    }
    final rows = await database.query(_ticketTable);
    for (final row in rows) {
      final ticket = _ticketFromRow(row);
      if ((row['user_id']?.toString().isEmpty ?? true) || _isLegacy(ticket)) {
        removed += await database.delete(
          _ticketTable,
          where: 'user_id = ? AND ticket_id = ?',
          whereArgs: [row['user_id'], row['ticket_id']],
        );
      }
    }
    if (kDebugMode) debugPrint('Removed $removed legacy ticket records.');
    final migrated = await preferences.setBool(_legacyMigrationKey, true);
    if (!migrated) throw StateError('Could not migrate saved tickets.');
  }

  Future<List<Ticket>> getSavedTickets({String? userId}) async {
    final scope = userId ?? StorageScope.currentKey();
    if (scope == null) return const [];
    if (kIsWeb) {
      final tickets = await _readWebTickets(scope);
      return tickets
          .where((ticket) => ticket.userId == scope && !_isLegacy(ticket))
          .toList();
    }

    final rows = await (await _db).query(
      _ticketTable,
      where: 'user_id = ?',
      whereArgs: [scope],
      orderBy: 'updated_at ASC',
    );
    return rows.map(_ticketFromRow).toList();
  }

  Future<Ticket?> getTicket(String id, {String? userId}) async {
    final scope = userId ?? StorageScope.currentKey();
    if (scope == null) return null;
    if (kIsWeb) {
      final tickets = await _readWebTickets(scope);
      for (final ticket in tickets) {
        if (ticket.id == id && ticket.userId == scope) {
          return ticket;
        }
      }
      return null;
    }

    final rows = await (await _db).query(
      _ticketTable,
      where: 'ticket_id = ? AND user_id = ?',
      whereArgs: [id, scope],
      limit: 1,
    );
    return rows.isEmpty ? null : _ticketFromRow(rows.first);
  }

  Future<void> saveTicket(Ticket ticket) async {
    _validateTickets([ticket]);
    if (ticket.userId.isEmpty) throw StateError('Ticket owner is required.');
    final prepared = ticket.downloadedAt.isEmpty
        ? ticket.copyWith(downloadedAt: DateTime.now().toIso8601String())
        : ticket;

    if (kIsWeb) {
      final tickets = await _readWebTickets(ticket.userId);
      if (tickets.any((saved) => _key(saved) == _key(prepared))) return;
      await _writeWebTickets([...tickets, prepared], userId: ticket.userId);
      return;
    }

    await (await _db).insert(
      _ticketTable,
      _ticketRow(prepared, DateTime.now().toIso8601String()),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> saveTickets(List<Ticket> tickets) async {
    if (tickets.isEmpty) return;
    _validateTickets(tickets);
    if (tickets.any((ticket) => ticket.userId.isEmpty)) {
      throw StateError('Ticket owners are required.');
    }
    final now = DateTime.now().toIso8601String();
    final prepared = tickets
        .map(
          (ticket) => ticket.downloadedAt.isEmpty
              ? ticket.copyWith(downloadedAt: now)
              : ticket,
        )
        .toList();

    if (kIsWeb) {
      final byUser = <String, List<Ticket>>{};
      for (final ticket in prepared) {
        byUser.putIfAbsent(ticket.userId, () => []).add(ticket);
      }
      for (final entry in byUser.entries) {
        final existing = await _readWebTickets(entry.key);
        final byKey = {for (final ticket in existing) _key(ticket): ticket};
        for (final ticket in entry.value) {
          byKey[_key(ticket)] = ticket;
        }
        await _writeWebTickets(byKey.values.toList(), userId: entry.key);
      }
      return;
    }

    final batch = (await _db).batch();
    for (final ticket in prepared) {
      batch.insert(
        _ticketTable,
        _ticketRow(ticket, now),
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
      final tickets = await _readWebTickets(updated.userId);
      await _writeWebTickets(
        tickets
            .map((saved) => _key(saved) == _key(updated) ? updated : saved)
            .toList(),
        userId: updated.userId,
      );
      return;
    }

    await (await _db).update(
      _ticketTable,
      _ticketRow(updated, DateTime.now().toIso8601String()),
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
    final now = DateTime.now().toIso8601String();
    final uniqueTickets = <String, Ticket>{
      for (final ticket in remoteTickets) ticket.id: ticket,
    }.values.toList();

    if (kIsWeb) {
      await _writeWebTickets(uniqueTickets, userId: userId);
    } else {
      final database = await _db;
      await database.transaction((transaction) async {
        await transaction.delete(
          _ticketTable,
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        for (final ticket in uniqueTickets) {
          await transaction.insert(
            _ticketTable,
            _ticketRow(ticket, now),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await transaction.insert(_syncTable, {
          'user_id': userId,
          'synced_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    }

    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_syncKeyFor(userId), now);
    if (!saved) throw StateError('Could not save the ticket sync time.');
  }

  Future<void> refreshSavedTickets(List<Ticket> remoteTickets) async {
    if (remoteTickets.isEmpty) return;
    final saved = await getSavedTickets(userId: StorageScope.currentKey());
    final byKey = {for (final ticket in remoteTickets) _key(ticket): ticket};
    final updated = saved.map((ticket) {
      final remote = byKey[_key(ticket)];
      return remote == null
          ? ticket
          : remote.copyWith(downloadedAt: ticket.downloadedAt);
    }).toList();
    await saveTickets(updated);
  }

  Future<DateTime?> getLastSynced({String? userId}) async {
    final key = userId == null || userId.isEmpty
        ? _syncKey
        : _syncKeyFor(userId);
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    if (raw != null) return DateTime.tryParse(raw);
    if (userId == null || userId.isEmpty || kIsWeb) return null;

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
    final scope = userId ?? StorageScope.currentKey();
    if (scope == null) return;
    if (kIsWeb) {
      final tickets = await _readWebTickets(scope);
      await _writeWebTickets(
        tickets
            .where((ticket) => ticket.id != id || ticket.userId != scope)
            .toList(),
        userId: scope,
      );
      return;
    }

    await (await _db).delete(
      _ticketTable,
      where: 'ticket_id = ? AND user_id = ?',
      whereArgs: [id, scope],
    );
  }

  Future<void> close() async {
    final databaseFuture = _database;
    if (databaseFuture == null) return;
    await (await databaseFuture).close();
    _database = null;
    final key = _databaseKey;
    if (key != null && identical(_databases[key], databaseFuture)) {
      _databases.remove(key);
    }
    _databaseKey = null;
  }

  bool _isLegacy(Ticket ticket) =>
      ticket.id.startsWith('TKT-') ||
      ticket.id.startsWith('TM-') ||
      ticket.source == 'demo-local' ||
      ticket.source == 'fake';

  Map<String, Object?> _ticketRow(Ticket ticket, String timestamp) => {
    'user_id': ticket.userId,
    'ticket_id': ticket.id,
    'payload': jsonEncode(ticket.toJson()),
    'updated_at': timestamp,
  };

  Ticket _ticketFromRow(Map<String, Object?> row) {
    final decoded = jsonDecode(row['payload']! as String) as Map;
    final ticket = Ticket.fromJson(Map<String, dynamic>.from(decoded));
    return ticket.copyWith(userId: row['user_id']! as String);
  }

  Future<List<Ticket>> _readWebTickets(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final key = StorageScope.key(_webStoragePrefix, userId: userId)!;
    final raw = preferences.getString(key);
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

  Future<void> _writeWebTickets(
    List<Ticket> tickets, {
    required String userId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final key = StorageScope.key(_webStoragePrefix, userId: userId)!;
    final saved = await preferences.setString(
      key,
      jsonEncode(tickets.map((ticket) => ticket.toJson()).toList()),
    );
    if (!saved) throw StateError('Could not save tickets on this device.');
  }

  String _syncKeyFor(String userId) => '$_syncKey:$userId';

  String _key(Ticket ticket) => '${ticket.userId}:${ticket.id}';

  void _validateTickets(List<Ticket> tickets) {
    if (tickets.any((ticket) => ticket.id.isEmpty)) {
      throw StateError('Tickets must have an ID.');
    }
  }
}
