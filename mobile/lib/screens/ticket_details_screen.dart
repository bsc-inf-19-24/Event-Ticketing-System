import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/ticket.dart';

class TicketDetailsScreen extends StatelessWidget {
  final Ticket ticket;
  final bool isSaved;

  const TicketDetailsScreen({
    super.key,
    required this.ticket,
    this.isSaved = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Details'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(ticket.eventName),
            Text('Ticket ID: ${ticket.id}'),
            Text('Date: ${ticket.date}'),
            Text('Venue: ${ticket.venue}'),
            Text('Status: ${ticket.status}'),
            Text(isSaved ? 'Saved offline' : 'Not saved offline'),
            const SizedBox(height: 20),
            QrImageView(
              data: ticket.qrData,
              version: QrVersions.auto,
              size: 200,
            ),
          ],
        ),
      ),
    );
  }
}