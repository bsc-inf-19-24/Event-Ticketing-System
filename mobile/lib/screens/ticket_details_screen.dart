import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';

class TicketDetailsScreen extends StatefulWidget {
  final Ticket ticket;
  final bool isSaved;
  final Future<bool> Function(Ticket) onDownload;

  const TicketDetailsScreen({
    super.key,
    required this.ticket,
    this.isSaved = false,
    required this.onDownload,
  });

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  late bool _saved;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.isSaved;
  }

  Future<void> _downloadTicket() async {
    setState(() {
      _saving = true;
    });

    try {
      final saved = await widget.onDownload(widget.ticket);
      if (!mounted) return;

      setState(() {
        _saved = saved || _saved;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ticket'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final qrSize = math.min(constraints.maxWidth * 0.7, 260.0);

                    return Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: QrImageView(
                            data: widget.ticket.qrData,
                            version: QrVersions.auto,
                            size: qrSize,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _TicketDetailRow(
                          label: 'Event',
                          value: widget.ticket.eventName,
                        ),
                        _TicketDetailRow(
                          label: 'Ticket Type',
                          value: widget.ticket.ticketType,
                        ),
                        _TicketDetailRow(
                          label: 'Ticket ID',
                          value: widget.ticket.id,
                        ),
                        _TicketDetailRow(
                          label: 'Price',
                          value: 'MWK ${formatPrice(widget.ticket.price)}',
                        ),
                        _TicketDetailRow(
                          label: 'Venue',
                          value: widget.ticket.venue,
                        ),
                        _TicketDetailRow(
                          label: 'Date',
                          value: widget.ticket.date,
                        ),
                        _TicketDetailRow(
                          label: 'Status',
                          value: widget.ticket.status,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Keep this QR code ready for entry verification.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        if (widget.ticket.purchasedOn.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Purchased: ${widget.ticket.purchasedOn}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saved || _saving ? null : _downloadTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    disabledBackgroundColor: AppColors.button,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: _saving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('Saving ticket...'),
                          ],
                        )
                      : _saved
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle),
                            SizedBox(width: 8),
                            Text('Saved offline'),
                          ],
                        )
                      : const Text('Download Ticket'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _TicketDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
