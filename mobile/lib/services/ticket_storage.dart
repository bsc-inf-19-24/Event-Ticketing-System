
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ticket.dart';

class TicketStorage {
  static const _storageKey = 'saved_demo_tickets';

  Future<List<Ticket>> getSavedTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null) return [];

    try {
      final List<dynamic> data = jsonDecode(jsonString);
      return data
          .map((item) => Ticket.fromJson(
        Map<String, dynamic>.from(item as Map),
      ))
          .toList();
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
  }
}
