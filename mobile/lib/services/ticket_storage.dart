import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ticket.dart';

class TicketStorage {
  static const _storageKey = 'saved_demo_tickets';

  Future<List<Ticket>> getSavedTickets({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null) return [];

    try {
      final List<dynamic> data = jsonDecode(jsonString);
      final tickets = data
          .map(
            (item) => Ticket.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      if (userId == null) return tickets;
      return tickets.where((ticket) => ticket.userId == userId).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTicket(Ticket ticket) async {
    final tickets = await getSavedTickets();

    if (tickets.any((saved) => saved.id == ticket.id)) return;

    tickets.add(ticket);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(tickets.map((t) => t.toJson()).toList()),
    );
    await _writeAll(tickets);
  }

  /// Saves tickets together so the purchase appears immediately in the list.
  Future<void> saveTickets(List<Ticket> newTickets) async {
    if (newTickets.isEmpty) return;
    final tickets = await getSavedTickets();
    final ids = tickets.map((ticket) => ticket.id).toSet();
    for (final ticket in newTickets) {
      if (ids.add(ticket.id)) tickets.add(ticket);
    }
    await _writeAll(tickets);
  }

  // NEW FUNCTIONS
  static const _syncKey = 'saved_tickets_last_synced';

  Future<void> _writeAll(List<Ticket> tickets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(tickets.map((t) => t.toJson()).toList()),
    );
  }

  /// Updates already-saved tickets with fresh server data.
  /// Never adds new tickets and never removes saved ones.
  Future<void> refreshSavedTickets(List<Ticket> remote) async {
    final saved = await getSavedTickets();
    if (saved.isEmpty) return;

    final remoteById = {for (final t in remote) t.id: t};
    final updated = saved.map((t) => remoteById[t.id] ?? t).toList();

    await _writeAll(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncKey, DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastSynced() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_syncKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Removes a saved ticket from this device only.
  Future<void> deleteTicket(String id, {String? userId}) async {
    final tickets = await getSavedTickets();
    final remaining = tickets
        .where(
          (ticket) =>
              ticket.id != id || (userId != null && ticket.userId != userId),
        )
        .toList();
    if (remaining.length == tickets.length) return;

    await _writeAll(remaining);
  }
}
