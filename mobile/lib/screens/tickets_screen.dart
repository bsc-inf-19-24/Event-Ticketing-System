import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/storage/pending_checkout_store.dart';
import '../features/payment/services/pending_checkout_manager.dart';
import '../features/auth/logic/auth_controller.dart';
import '../features/tickets/logic/tickets_controller.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../widgets/login_required_view.dart';
import '../widgets/event_image.dart';
import '../widgets/offline_banner.dart';
import '../widgets/retry_error_view.dart';
import 'main_shell.dart';
import 'ticket_details_screen.dart';

/// Displays tickets purchased by the currently authenticated customer.
class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key, this.pendingCheckoutManager});

  final PendingCheckoutManager? pendingCheckoutManager;

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  bool _loading = true;
  PendingCheckout? _pendingCheckout;
  bool _checkingPending = false;
  bool _verifyingPayment = false;
  late final PendingCheckoutManager _pendingManager =
      widget.pendingCheckoutManager ?? PendingCheckoutManager();

  @override
  void initState() {
    super.initState();
    ticketsController.addListener(_onTicketsChanged);
    authController.addListener(_onAuthChanged);
    mainTabIndex.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    ticketsController.removeListener(_onTicketsChanged);
    authController.removeListener(_onAuthChanged);
    mainTabIndex.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() => _pendingCheckout = null);
    if (authController.isLoggedIn) {
      unawaited(_checkPendingCheckout());
    }
  }

  void _onTabChanged() {
    if (mainTabIndex.value == 1) unawaited(_checkPendingCheckout());
  }

  Future<void> _checkPendingCheckout() async {
    final userId = authController.stableUserId;
    if (userId == null || _checkingPending) return;
    _checkingPending = true;
    if (mounted) setState(() => _pendingCheckout = null);
    try {
      final store = PendingCheckoutStore();
      final pending = await store.read(userId: userId);
      if (pending == null) {
        if (mounted) setState(() => _pendingCheckout = null);
        return;
      }
      if (DateTime.now().difference(pending.createdAt) >
          const Duration(minutes: 30)) {
        await store.clear(userId: userId);
        if (mounted) setState(() => _pendingCheckout = null);
        return;
      }
      final result = await _pendingManager.check(pending, userId: userId);
      if (result == PendingCheckoutResolution.paid && mounted) {
        setState(() => _pendingCheckout = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Payment confirmed')));
      } else if (result == PendingCheckoutResolution.pending && mounted) {
        setState(() => _pendingCheckout = pending);
      } else if (result == PendingCheckoutResolution.cleared && mounted) {
        setState(() => _pendingCheckout = null);
      }
    } catch (_) {
      // Keep the record and stay quiet when the server cannot be reached.
    } finally {
      _checkingPending = false;
    }
  }

  Future<void> _verifyPendingCheckout() async {
    final pending = _pendingCheckout;
    final userId = authController.stableUserId;
    if (pending == null || userId == null || _verifyingPayment) return;
    setState(() => _verifyingPayment = true);
    try {
      final result = await _pendingManager.verify(pending, userId: userId);
      if (result == PendingCheckoutResolution.paid && mounted) {
        setState(() => _pendingCheckout = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Payment confirmed')));
      } else if (result == PendingCheckoutResolution.pending && mounted) {
        setState(() => _pendingCheckout = pending);
      } else if (result == PendingCheckoutResolution.cleared && mounted) {
        setState(() => _pendingCheckout = null);
      }
    } catch (_) {
      // A network failure keeps the pending checkout available for a later retry.
    } finally {
      if (mounted) setState(() => _verifyingPayment = false);
    }
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

  Widget _pendingNotice() => Card(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    color: AppColors.card,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You have a payment that was not completed.',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: _verifyingPayment ? null : _verifyPendingCheckout,
                child: _verifyingPayment
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify payment'),
              ),
              TextButton(
                onPressed: () async {
                  await PendingCheckoutStore().clear(
                    userId: authController.stableUserId,
                  );
                  if (mounted) setState(() => _pendingCheckout = null);
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

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
              ? SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      if (_pendingCheckout != null) _pendingNotice(),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: ticketsController,
                          builder: (context, _) =>
                              _buildBody(ticketsController.tickets),
                        ),
                      ),
                    ],
                  ),
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
    final refreshError = ticketsController.errorMessage;
    final showRefreshWarning =
        !ticketsController.isOffline && refreshError != null;
    final offlineItemCount = ticketsController.isOffline ? 1 : 0;
    final warningItemCount = showRefreshWarning ? 1 : 0;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: tickets.length + offlineItemCount + warningItemCount,
        itemBuilder: (context, index) {
          if (ticketsController.isOffline && index == 0) {
            return const OfflineBanner();
          }
          final indexAfterOfflineBanner = index - offlineItemCount;
          if (showRefreshWarning && indexAfterOfflineBanner == 0) {
            return _TicketRefreshWarning(message: refreshError, onRetry: _load);
          }
          final ticketIndex = indexAfterOfflineBanner - warningItemCount;
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

class _TicketRefreshWarning extends StatelessWidget {
  const _TicketRefreshWarning({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white24),
    ),
    child: Row(
      children: [
        const Icon(Icons.sync_problem, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message == null
                ? 'Could not refresh tickets. Showing saved tickets.'
                : 'Could not refresh tickets. Showing saved tickets. $message',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
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
                    child: EventImage(
                      imagePath: ticket.imagePath,
                      fit: BoxFit.cover,
                      iconSize: 36,
                      fallbackIcon: Icons.image_outlined,
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
                          _TicketText(_formatEventDate(ticket.date)),
                          _TicketText(ticket.venue),
                          if (ticket.location.isNotEmpty)
                            _TicketText(ticket.location),
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

  String _formatEventDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${DateFormat('EEEE, d MMMM yyyy').format(parsed)} · ${DateFormat('h:mm a').format(parsed)}';
  }
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
