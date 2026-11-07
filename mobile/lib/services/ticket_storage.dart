import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/ticket.dart';
import 'ticket_database_factory.dart'
    if (dart.library.html) 'ticket_database_factory_web.dart';

class TicketStorage {
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
  }

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
