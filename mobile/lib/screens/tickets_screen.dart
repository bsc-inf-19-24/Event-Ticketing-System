import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../services/ticket_repository.dart';
import '../services/ticket_storage.dart';
import '../theme/app_colors.dart';
import 'ticket_details_screen.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final TicketStorage _storage = TicketStorage();
  final TicketRepository _repository = TicketRepository();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  TicketListResult? _result;
  bool _loading = true;
  String? _error;

  bool get _isOffline => _result?.isOffline ?? false;
  Set<String> get _savedIds => _result?.savedIds ?? const <String>{};

  @override
  void initState() {
    super.initState();
    _load();
    // Reload (and refresh saved tickets) whenever connectivity changes.
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<bool> _hasConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return !results.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<void> _load() async {
    try {
      final result = await _repository.load(
        hasConnection: await _hasConnection(),
      );

      if (!mounted) return;

      setState(() {
        _result = result;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not load tickets.';
      });
    }
  }

  Future<bool> _saveTicket(Ticket ticket) async {
    try {
      await _storage.saveTicket(ticket);
      await _load();

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

  Future<bool> _deleteTicket(Ticket ticket) async {
    try {
      await _storage.deleteTicket(ticket.id);
      await _load();

      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket removed from this device.')),
      );
      return true;
    } catch (_) {
      if (!mounted) return false;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not remove ticket.')));
      return false;
    }
  }

  void _openTicket(Ticket ticket) {
    final isSaved = _savedIds.contains(ticket.id);

    if (_isOffline && !isSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "This ticket isn't downloaded. Connect to the internet to view it.",
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailsScreen(
          ticket: ticket,
          isSaved: isSaved,
          isOffline: _isOffline,
          onDownload: _saveTicket,
          onDelete: _deleteTicket,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tickets = _result?.tickets ?? const <Ticket>[];

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
      body: Column(
        children: [
          if (_isOffline) _OfflineBanner(lastSynced: _result?.lastSynced),
          Expanded(child: _buildBody(tickets)),
        ],
      ),
    );
  }

  Widget _buildBody(List<Ticket> tickets) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.confirmation_number_outlined,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _isOffline
                    ? 'No tickets downloaded for offline use.\nConnect to the internet to download your tickets.'
                    : 'You have no tickets yet',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: tickets.length,
        itemBuilder: (context, index) {
          final ticket = tickets[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TicketCard(
              ticket: ticket,
              isSaved: _savedIds.contains(ticket.id),
              onTap: () => _openTicket(ticket),
            ),
          );
        },
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final DateTime? lastSynced;

  const _OfflineBanner({this.lastSynced});

  @override
  Widget build(BuildContext context) {
    final sync = lastSynced == null
        ? ''
        : ' Last updated ${TimeOfDay.fromDateTime(lastSynced!.toLocal()).format(context)}.';

    return Container(
      width: double.infinity,
      color: Colors.orange.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You're offline. Showing downloaded tickets only.$sync",
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
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
                          : Image.asset(
                              ticket.imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: AppColors.card,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white70,
                                  size: 36,
                                ),
                              ),
                            ),
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
                            _StatusChip(
                              icon: isSaved
                                  ? Icons.check_circle
                                  : Icons.cloud_outlined,
                              label: isSaved
                                  ? 'Available offline'
                                  : 'Online only',
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

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
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
