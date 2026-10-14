import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../models/ticket.dart';
import '../data/sample_tickets.dart';
import '../services/ticket_storage.dart';
import 'ticket_details_screen.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final TicketStorage _storage = TicketStorage();

  List<Ticket> _savedTickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedTickets();
  }

  Future<void> _loadSavedTickets() async {
    try {
      final tickets = await _storage.getSavedTickets();

      if (!mounted) return;

      setState(() {
        _savedTickets = tickets;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not load saved tickets.';
      });
    }
  }

  Future<void> _saveTicket(Ticket ticket) async {
    try {
      await _storage.saveTicket(ticket);
      await _loadSavedTickets();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket saved on this device.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save ticket.'),
        ),
      );
    }
  }

  void _openTicket(Ticket ticket) {
    final isSaved =
    _savedTickets.any((saved) => saved.id == ticket.id);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailsScreen(
          ticket: ticket,
          isSaved: isSaved,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedIds =
    _savedTickets.map((ticket) => ticket.id).toSet();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Tickets'),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _error != null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            ElevatedButton(
              onPressed: _loadSavedTickets,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'DEMO MODE — SAMPLE TICKETS ONLY',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Available Tickets',
            style: Theme.of(context)
                .textTheme.titleLarge
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),

          ...sampleTickets.map((ticket) {
            final isSaved = savedIds.contains(ticket.id);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.eventName,
                      style: Theme.of(context)
                          .textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Ticket ID: ${ticket.id}'),
                    Text('Date: ${ticket.date}'),
                    Text('Venue: ${ticket.venue}'),
                    Text('Status: ${ticket.status}'),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () =>
                              _openTicket(ticket),
                          child: const Text('View details'),
                        ),
                        ElevatedButton.icon(
                          onPressed: isSaved
                              ? null
                              : () => _saveTicket(ticket),
                          icon: Icon(
                            isSaved
                                ? Icons.check
                                : Icons.download,
                          ),
                          label: Text(
                            isSaved ? 'Saved' : 'Save offline',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

          const Divider(height: 32),

          Text(
            'Saved Offline (${_savedTickets.length})',
            style: Theme.of(context)
                .textTheme.titleLarge
                ?.copyWith(color: Colors.white),
          ),

          if (_savedTickets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No tickets saved yet.',
                style: TextStyle(color: Colors.white70),
              ),
            ),

          ..._savedTickets.map(
                (ticket) => Card(
              child: ListTile(
                leading: const Icon(Icons.offline_pin),
                title: Text(ticket.eventName),
                subtitle: Text('Ticket ID: ${ticket.id}'),
                onTap: () => _openTicket(ticket),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

