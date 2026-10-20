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

  Future<bool> _saveTicket(Ticket ticket) async {
    try {
      await _storage.saveTicket(ticket);
      await _loadSavedTickets();

      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket saved on this device.')),
      );
      return true;
    } catch (_) {
      if (!mounted) return false;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save ticket.')));
      return false;
    }
  }

  void _openTicket(Ticket ticket) {
    final isSaved = _savedTickets.any((saved) => saved.id == ticket.id);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailsScreen(
          ticket: ticket,
          isSaved: isSaved,
          onDownload: _saveTicket,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedIds = _savedTickets.map((ticket) => ticket.id).toSet();
    final ticketsById = {for (final ticket in sampleTickets) ticket.id: ticket};
    for (final ticket in _savedTickets) {
      ticketsById[ticket.id] = ticket;
    }
    final tickets = ticketsById.values.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Tickets'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
          : tickets.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    color: Colors.white70,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'You have no tickets yet',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TicketCard(
                    ticket: ticket,
                    isSaved: savedIds.contains(ticket.id),
                    onTap: () => _openTicket(ticket),
                  ),
                );
              },
            ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Ticket ticket;
  final bool isSaved;
  final VoidCallback onTap;

  const _TicketCard({
    required this.ticket,
    required this.isSaved,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = constraints.maxWidth * 0.4;

        return Container(
          height: 190,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Row(
                  children: [
                    SizedBox(
                      width: imageWidth,
                      height: 190,
                      child: ticket.imagePath.isEmpty
                          ? const ColoredBox(
                              color: AppColors.card,
                              child: Icon(
                                Icons.image_outlined,
                                color: Colors.white70,
                                size: 36,
                              ),
                            )
                          : Image.asset(ticket.imagePath, fit: BoxFit.cover),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _TicketText(
                              ticket.eventName,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            _TicketText('Ticket ID: ${ticket.id}'),
                            _TicketText(ticket.date),
                            _TicketText(ticket.venue),
                            _TicketText('Status: ${ticket.status}'),
                            if (isSaved)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Saved offline',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TicketText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _TicketText(this.text, {this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style ?? const TextStyle(color: AppColors.textDark),
    );
  }
}
