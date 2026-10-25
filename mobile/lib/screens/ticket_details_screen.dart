import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';

class TicketDetailsScreen extends StatefulWidget {
  final Ticket ticket;
  final bool isSaved;
  final bool isOffline;
  final Future<bool> Function(Ticket) onDownload;
  final Future<bool> Function(Ticket)? onDelete;

  const TicketDetailsScreen({
    super.key,
    required this.ticket,
    this.isSaved = false,
    this.isOffline = false,
    required this.onDownload,
    this.onDelete,
  });

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  late bool _saved;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.isSaved;
  }

  Future<void> _deleteTicket() async {
    final onDelete = widget.onDelete;
    if (onDelete == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from this device?'),
        content: Text(
          widget.isOffline
              ? "You're offline, so you won't be able to download this ticket "
                    'again until you reconnect.'
              : 'You can download this ticket again later while online.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);

    try {
      final removed = await onDelete(widget.ticket);
      if (!mounted) return;

      if (removed) {
        if (widget.isOffline) {
          // Offline, the ticket is no longer available at all.
          Navigator.pop(context);
        } else {
          setState(() => _saved = false);
        }
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
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
    final canDownload = !_saved && !_saving && !widget.isOffline;

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
              if (widget.isOffline) ...[
                const _InfoBanner(
                  icon: Icons.cloud_off,
                  text:
                      "You're offline. Showing the copy saved on this device. "
                      'Details may have changed since it was last updated.',
                ),
                const SizedBox(height: 12),
              ],
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
                          // Drawn locally from stored qrData, no network needed.
                          child: QrImageView(
                            data: widget.ticket.qrData,
                            version: QrVersions.auto,
                            size: qrSize,
                            backgroundColor: Colors.white,
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
                          label: widget.isOffline
                              ? 'Status (last known)'
                              : 'Status',
                          value: widget.ticket.status,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Keep this QR code ready for entry verification.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        if (widget.isOffline) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Ticket validity is confirmed at the gate.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
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
                  onPressed: canDownload ? _downloadTicket : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    disabledBackgroundColor: AppColors.button,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: _buildButtonChild(),
                ),
              ),
              if (_saved && widget.onDelete != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _deleting ? null : _deleteTicket,
                    icon: _deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(
                      _deleting ? 'Removing...' : 'Remove from device',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      disabledBackgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtonChild() {
    if (_saving) {
      return const Row(
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
      );
    }

    if (_saved) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle),
          SizedBox(width: 8),
          Text('Saved offline'),
        ],
      );
    }

    if (widget.isOffline) {
      return const Text('Connect to download');
    }

    return const Text('Download Ticket');
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
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
