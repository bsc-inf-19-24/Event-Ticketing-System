import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/orders/models/order.dart';
import '../features/payment/logic/payment_controller.dart';
import '../features/payment/models/payment_models.dart';
import '../features/payment/services/payment_service.dart';
import '../features/payment/services/fake_payment_service.dart';
import '../features/tickets/logic/tickets_controller.dart';
import '../models/event.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'event_details_screen.dart';
import 'main_shell.dart';

void _showVerifying(
  BuildContext context,
  Event event,
  PaymentController controller,
  PaymentOutcome outcome, {
  String? failureMessage,
}) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => VerifyingScreen(
        event: event,
        controller: controller,
        outcome: outcome,
        failureMessage: failureMessage,
      ),
    ),
  );
}

/// Opens the backend hosted checkout in the device browser.
class PayChanguCheckoutScreen extends StatefulWidget {
  const PayChanguCheckoutScreen({
    super.key,
    required this.event,
    required this.controller,
  });

  final Event event;
  final PaymentController controller;

  @override
  State<PayChanguCheckoutScreen> createState() =>
      _PayChanguCheckoutScreenState();
}

class _PayChanguCheckoutScreenState extends State<PayChanguCheckoutScreen> {
  String? _error;
  bool _opening = false;

  Future<void> _openCheckout() async {
    final url = widget.controller.checkoutSession?.checkoutUrl;
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(
        () =>
            _error = 'A secure checkout link is unavailable. Restart checkout.',
      );
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw const PaymentException(
          'Could not open checkout in your browser. Your order is saved; retry opening payment or return to the app to verify it.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => _PaymentScaffold(
    title: useFakePayments ? 'Student demo checkout' : 'PayChangu checkout',
    controller: widget.controller,
    event: widget.event,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoCard(
          children: [
            Icon(
              useFakePayments ? Icons.school_outlined : Icons.lock_outline,
              color: AppColors.accent,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              useFakePayments
                  ? 'A fake PayChangu page will open in your browser. Select Simulate successful payment there. No real payment is made.'
                  : 'Pay MWK ${formatPrice(widget.controller.order?.total ?? 0)} securely on PayChangu.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            SelectableText(
              widget.controller.order?.txRef ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _actionButton(
          label: _opening
              ? 'Opening checkout...'
              : useFakePayments
              ? 'Open student demo page'
              : 'Open PayChangu checkout',
          onPressed: _opening ? () {} : _openCheckout,
        ),
        const SizedBox(height: 8),
        Text(
          useFakePayments
              ? 'After simulating payment in the browser, return here. The app will verify with the backend before showing tickets.'
              : 'After paying, return here and verify your payment. Tickets are issued only after the server confirms payment.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 12),
        if (widget.controller.isPendingVerification) ...[
          const SizedBox(height: 8),
          const Text(
            'Your order is pending. No ticket is issued until the backend confirms payment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orangeAccent),
          ),
        ],
        _actionButton(
          label: widget.controller.isPendingVerification
              ? 'Recheck payment status'
              : 'I completed payment - verify',
          secondary: true,
          onPressed: () => _showVerifying(
            context,
            widget.event,
            widget.controller,
            PaymentOutcome.success,
          ),
        ),
      ],
    ),
  );
}

/// Simulates an approval prompt from a mobile-money operator.
class MobileMoneyApprovalScreen extends StatefulWidget {
  const MobileMoneyApprovalScreen({
    super.key,
    required this.event,
    required this.controller,
    required this.phone,
  });

  final Event event;
  final PaymentController controller;
  final String phone;

  @override
  State<MobileMoneyApprovalScreen> createState() =>
      _MobileMoneyApprovalScreenState();
}

class _MobileMoneyApprovalScreenState extends State<MobileMoneyApprovalScreen> {
  Timer? _timer;
  int _remaining = 60;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining <= 1) {
        timer.cancel();
        _continue(PaymentOutcome.failed, 'Payment timed out');
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PaymentScaffold(
    title: 'Approve payment',
    controller: widget.controller,
    event: widget.event,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _testModeLabel(),
        const SizedBox(height: 24),
        _infoCard(
          children: [
            const Icon(Icons.phone_android, color: AppColors.accent, size: 44),
            const SizedBox(height: 12),
            Text(
              'A payment prompt was sent to ${_maskedPhone(widget.phone)}. Approve it on your phone.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Time remaining: 00:${_remaining.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _actionButton(
          label: 'Simulate approval',
          onPressed: () => _continue(PaymentOutcome.success),
        ),
        const SizedBox(height: 10),
        _actionButton(
          label: 'Simulate decline',
          secondary: true,
          onPressed: () =>
              _continue(PaymentOutcome.failed, 'The payment was declined.'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => _continue(PaymentOutcome.cancelled),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );

  void _continue(PaymentOutcome outcome, [String? reason]) {
    if (!mounted) return;
    _timer?.cancel();
    _showVerifying(
      context,
      widget.event,
      widget.controller,
      outcome,
      failureMessage: reason,
    );
  }

  String _maskedPhone(String phone) =>
      '${phone.substring(0, 4)} xxx ${phone.substring(phone.length - 3)}';
}

/// Displays the verification state and finalizes the order.
class VerifyingScreen extends StatefulWidget {
  const VerifyingScreen({
    super.key,
    required this.event,
    required this.controller,
    required this.outcome,
    this.failureMessage,
  });

  final Event event;
  final PaymentController controller;
  final PaymentOutcome outcome;
  final String? failureMessage;

  @override
  State<VerifyingScreen> createState() => _VerifyingScreenState();
}

class _VerifyingScreenState extends State<VerifyingScreen> {
  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    final success = await widget.controller.finish(
      widget.event,
      widget.outcome,
      failureMessage: widget.failureMessage,
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentResultScreen(
          event: widget.event,
          controller: widget.controller,
          success: success,
          reason: widget.controller.failureReason,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verifying payment'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: 16),
            Text(
              'Verifying your payment...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows the receipt or a recoverable payment failure.
class PaymentResultScreen extends StatelessWidget {
  const PaymentResultScreen({
    super.key,
    required this.event,
    required this.controller,
    required this.success,
    this.reason,
  });

  final Event event;
  final PaymentController controller;
  final bool success;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final order = controller.order;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment result'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success ? Colors.greenAccent : Colors.orangeAccent,
              size: 72,
            ),
            const SizedBox(height: 12),
            Text(
              success ? 'Payment successful' : 'Payment unsuccessful',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!success && reason != null) ...[
              const SizedBox(height: 8),
              Text(
                reason!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 20),
            if (success && order != null) _receipt(order),
            const SizedBox(height: 20),
            if (success) ...[
              _actionButton(
                label: 'View my tickets',
                onPressed: () {
                  ticketsController.load();
                  mainTabIndex.value = 1;
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              const SizedBox(height: 10),
              _actionButton(
                label: 'Back to home',
                secondary: true,
                onPressed: () {
                  mainTabIndex.value = 0;
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ] else ...[
              _actionButton(
                label: 'Try again',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 10),
              _actionButton(
                label: 'Back to event',
                secondary: true,
                onPressed: () => Navigator.of(context).popUntil(
                  (route) =>
                      route.settings.name == EventDetailsScreen.routeName,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _receipt(Order order) => _infoCard(
    children: [
      _receiptRow('Order ID', order.id),
      _receiptRow('Transaction', order.txRef),
      _receiptRow('Event', order.eventTitle),
      if (order.items.isNotEmpty)
        _receiptRow(
          order.items.first.ticketTypeName,
          'MWK ${formatPrice(order.items.first.unitPrice)}',
        ),
      _receiptRow('Total', 'MWK ${formatPrice(order.total)}'),
      _receiptRow('Payment method', order.paymentMethod),
      _receiptRow(
        'Date',
        order.createdAt.toLocal().toString().split('.').first,
      ),
    ],
  );

  Widget _receiptRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

class _PaymentScaffold extends StatelessWidget {
  const _PaymentScaffold({
    required this.title,
    required this.controller,
    required this.event,
    required this.child,
  });

  final String title;
  final PaymentController controller;
  final Event event;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmCancel(context, event, controller);
    },
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _confirmCancel(
  BuildContext context,
  Event event,
  PaymentController controller,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel payment?'),
      content: const Text('This payment will not be completed.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep paying'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Cancel payment'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    _showVerifying(context, event, controller, PaymentOutcome.cancelled);
  }
}

Widget _testModeLabel() => const Text(
  'TEST MODE - no real money is charged',
  textAlign: TextAlign.center,
  style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
);

Widget _infoCard({required List<Widget> children}) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  ),
);

Widget _actionButton({
  required String label,
  required VoidCallback onPressed,
  bool secondary = false,
}) => SizedBox(
  height: 52,
  child: ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: secondary ? AppColors.surface : AppColors.button,
      foregroundColor: Colors.white,
      shape: const StadiumBorder(),
    ),
    child: Text(label, textAlign: TextAlign.center),
  ),
);
