import 'package:flutter/material.dart';

import '../features/auth/logic/auth_controller.dart';
import '../features/tickets/logic/tickets_controller.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../widgets/login_required_view.dart';
import '../widgets/offline_banner.dart';
import '../widgets/retry_error_view.dart';
import 'main_shell.dart';
import 'ticket_details_screen.dart';

/// Displays tickets purchased by the currently authenticated customer.
class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ticketsController.addListener(_onTicketsChanged);
    _load();
  }

  @override
  void dispose() {
    ticketsController.removeListener(_onTicketsChanged);
    super.dispose();
  }

  void _onTicketsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      await ticketsController.load();
    } catch (_) {
      // TicketsController exposes the failure while keeping any cached tickets.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openTicket(Ticket ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailsScreen(
          ticket: ticket,
          isSaved: true,
          isOffline: ticketsController.isOffline,
          onDownload: (_) async => true,
          onRefresh: ticketsController.loadTicketDetails,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authController,
      builder: (context, _) {
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
          body: authController.isLoggedIn
              ? ListenableBuilder(
                  listenable: ticketsController,
                  builder: (context, _) =>
                      _buildBody(ticketsController.tickets),
                )
              : const LoginRequiredView(
                  title: 'Log in to view your tickets',
                  message: 'You need an account to buy and keep your tickets.',
                ),
        );
      },
    );
  }

  Widget _buildBody(List<Ticket> tickets) {
    if (_loading || ticketsController.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tickets.isEmpty) {
      final errorMessage = ticketsController.errorMessage;
      if (errorMessage != null) {
        return RetryErrorView(message: errorMessage, onRetry: _load);
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.confirmation_number_outlined,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'You have no tickets yet',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  mainTabIndex.value = 0;
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Browse events'),
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
        itemCount: tickets.length + (ticketsController.isOffline ? 1 : 0),
        itemBuilder: (context, index) {
          if (ticketsController.isOffline && index == 0) {
            return const OfflineBanner();
          }
          final ticketIndex = index - (ticketsController.isOffline ? 1 : 0);
          final ticket = tickets[ticketIndex];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TicketCard(
              ticket: ticket,
              onTap: () => _openTicket(ticket),
            ),
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final imageWidth = constraints.maxWidth * 0.4;
      return Container(
        constraints: const BoxConstraints(minHeight: 180),
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
                        : ticket.imagePath.startsWith('http')
                        ? Image.network(
                            ticket.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const _TicketImageError(),
                          )
                        : Image.asset(
                            ticket.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const _TicketImageError(),
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
                          const _StatusChip(),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 14),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              'Saved offline',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TicketText extends StatelessWidget {
  const _TicketText(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: style ?? const TextStyle(color: AppColors.textDark),
  );
}

class _TicketImageError extends StatelessWidget {
  const _TicketImageError();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.card,
    child: Icon(Icons.broken_image_outlined, color: Colors.white70, size: 36),
  );
}
