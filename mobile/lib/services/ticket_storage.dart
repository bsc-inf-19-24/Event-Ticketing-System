import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/ticket.dart';
import 'ticket_database_factory.dart'
    if (dart.library.html) 'ticket_database_factory_web.dart';

class TicketStorage {
  TicketStorage({this.databasePath, this.databaseName = 'event_tickets.db'});

  static const _webStorageKey = 'saved_tickets_web';
  static final Map<String, Future<Database>> _databases = {};

  final String? databasePath;
  final String databaseName;
  Future<Database>? _database;

  Future<Database> get _db async {
    if (kIsWeb) throw UnsupportedError('SQLite is unavailable on web.');
    initializeTicketDatabaseFactory();
    final file =
        databasePath ?? path.join(await getDatabasesPath(), databaseName);
    final opening = _databases.putIfAbsent(file, () => _openDatabase(file));
    try {
      _database = opening;
      return await opening;
    } catch (_) {
      _databases.remove(file);
      rethrow;
    }
  }

  Future<Database> _openDatabase(String file) => openDatabase(
    file,
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

  Future<Ticket?> getTicket(String id) async {
    final saved = await getSavedTickets();
    for (final ticket in saved) {
      if (ticket.id == id) return ticket;
    }
    return null;
  }

  Future<void> saveTicket(Ticket ticket) => saveTickets([ticket]);

  Future<void> saveTickets(List<Ticket> tickets) async {
    if (tickets.isEmpty) return;
    _validateTickets(tickets);
    if (kIsWeb) {
      final existing = await _readWebTickets();
      final map = {for (final ticket in existing) _key(ticket): ticket};
      for (final ticket in tickets) {
        map[_key(ticket)] = ticket;
      }
      await _writeWebTickets(map.values.toList());
      return;
    }
    final database = await _db;
    final batch = database.batch();
    final now = DateTime.now().toIso8601String();
    for (final ticket in tickets) {
      final prepared = ticket.downloadedAt.isEmpty
          ? ticket.copyWith(downloadedAt: now)
          : ticket;
      batch.insert(
        'tickets',
        _ticketRow(prepared, now),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> synchronizeUserTickets(
    String userId,
    List<Ticket> remoteTickets,
  ) async {
    if (userId.isEmpty) throw ArgumentError.value(userId, 'userId');
    if (remoteTickets.any((ticket) => ticket.userId != userId)) {
      throw StateError('Cannot cache tickets owned by another user.');
    }
    if (kIsWeb) {
      final existing = await _readWebTickets();
      await _writeWebTickets([
        ...existing.where((ticket) => ticket.userId != userId),
        ...remoteTickets,
      ]);
      return;
    }
    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.delete(
        'tickets',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      final now = DateTime.now().toIso8601String();
      for (final ticket in remoteTickets) {
        await transaction.insert(
          'tickets',
          _ticketRow(ticket, now),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await transaction.insert('ticket_sync', {
        'user_id': userId,
        'synced_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<DateTime?> getLastSynced({String? userId}) async {
    if (kIsWeb) return null;
    final database = await _db;
    final rows = userId == null
        ? await database.query('ticket_sync', limit: 1)
        : await database.query(
            'ticket_sync',
            where: 'user_id = ?',
            whereArgs: [userId],
            limit: 1,
          );
    final value = rows.isEmpty ? null : rows.first['synced_at'];
    return value is String ? DateTime.tryParse(value) : null;
  }

  Future<void> updateTicket(Ticket ticket) async {
    final old = await getTicket(ticket.id);
    final updated = ticket.downloadedAt.isEmpty && old != null
        ? ticket.copyWith(downloadedAt: old.downloadedAt)
        : ticket;
    if (kIsWeb) {
      final tickets = await _readWebTickets();
      final key = _key(updated);
      final map = {for (final saved in tickets) _key(saved): saved};
      map[key] = updated;
      await _writeWebTickets(map.values.toList());
      return;
    }
    await (await _db).insert(
      'tickets',
      _ticketRow(updated, DateTime.now().toIso8601String()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> refreshSavedTickets(List<Ticket> remote) async {
    final saved = await getSavedTickets();
    final byId = {for (final ticket in remote) ticket.id: ticket};
    await saveTickets(
      saved.map((ticket) => byId[ticket.id] ?? ticket).toList(),
    );
  }

  Future<void> deleteTicket(String id, {String? userId}) async {
    if (kIsWeb) {
      final tickets = await _readWebTickets();
      await _writeWebTickets(
        tickets.where((ticket) {
          final sameTicket = ticket.id == id;
          return !sameTicket || (userId != null && ticket.userId != userId);
        }).toList(),
      );
      return;
    }
    final database = await _db;
    await database.delete(
      'tickets',
      where: userId == null ? 'ticket_id = ?' : 'ticket_id = ? AND user_id = ?',
      whereArgs: userId == null ? [id] : [id, userId],
    );
  }

  Future<void> close() async {
    final databaseFuture = _database;
    if (databaseFuture == null) return;
    await (await databaseFuture).close();
    _database = null;
    _databases.removeWhere((_, opening) => identical(opening, databaseFuture));
  }

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

  Future<List<Ticket>> _readWebTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_webStorageKey);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _webStorageKey,
      jsonEncode(tickets.map((ticket) => ticket.toJson()).toList()),
    );
  }

  String _key(Ticket ticket) => '${ticket.userId}:${ticket.id}';

  void _validateTickets(List<Ticket> tickets) {
    if (tickets.any((ticket) => ticket.id.isEmpty)) {
      throw StateError('Tickets must have an ID.');
    }
  }
}
