import 'package:flutter/material.dart';

import '../features/orders/models/order.dart';
import '../features/payment/logic/payment_controller.dart';
import '../features/payment/models/payment_models.dart';
import '../features/payment/services/payment_service.dart';
import '../features/payment/services/fake_payment_service.dart';
import '../models/event.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'payment_flow_screens.dart';

/// Confirms the selected tickets before handing payment off to PayChangu.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.event,
    required this.items,
    required this.total,
  });

  final Event event;
  final List<OrderItem> items;
  final int total;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _paymentController = PaymentController();
  static const _method = PaymentMethod.card;
  bool _processing = false;
  bool _cancelRequested = false;
  Future<void>? _beginOperation;
  Future<bool?>? _cancelPrompt;
  String? _error;

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_processing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _processing) {
          _confirmCancelDuringStart();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Checkout'),
          centerTitle: true,
          backgroundColor: AppColors.background,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.event.title, style: _title),
                          if (widget.event.hasStart) ...[
                            const SizedBox(height: 8),
                            Text(widget.event.displayDate, style: _muted),
                            Text(widget.event.timeRange, style: _muted),
                          ],
                          if (widget.event.place.isNotEmpty)
                            Text(widget.event.place, style: _muted),
                          const Divider(color: Colors.white24, height: 24),
                          for (final item in widget.items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.ticketTypeName} Ticket × ${item.quantity}',
                                      style: _muted,
                                    ),
                                  ),
                                  Text(
                                    'MWK ${formatPrice(item.unitPrice * item.quantity)}',
                                    style: _muted,
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Total', style: _title),
                              ),
                              Text(
                                'MWK ${formatPrice(widget.total)}',
                                style: _title,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment', style: _title),
                          SizedBox(height: 8),
                          Text(
                            'You will enter your payment details securely on PayChangu.',
                            style: _muted,
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    const Text(
                      useFakePayments
                          ? 'TEST MODE - no real money is charged'
                          : 'Payment is securely processed by PayChangu',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _processing ? null : _pay,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.button,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                        child: _processing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Proceed to payment'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _title = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const _muted = TextStyle(color: Colors.white70);

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Future<void> _pay() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final operation = _paymentController.begin(
        event: widget.event,
        items: widget.items,
        total: widget.total,
        method: _method,
        phone: '',
      );
      _beginOperation = operation;
      await operation;
      if (!mounted) return;
      final cancelPrompt = _cancelPrompt;
      if (cancelPrompt != null) await cancelPrompt;
      if (!mounted || _cancelRequested) return;
      final page = useFakePayments
          ? FakeHostedCheckoutScreen(
              event: widget.event,
              controller: _paymentController,
            )
          : PayChanguCheckoutScreen(
              event: widget.event,
              controller: _paymentController,
            );
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    } catch (error) {
      if (mounted && !_cancelRequested) {
        setState(
          () => _error = error is PaymentException
              ? error.message
              : 'We could not start the payment. Please try again.',
        );
      }
    } finally {
      _beginOperation = null;
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _confirmCancelDuringStart() async {
    if (_cancelPrompt != null) return;
    final prompt = showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel payment?'),
        content: const Text('The payment setup will be cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep paying'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel payment'),
          ),
        ],
      ),
    );
    _cancelPrompt = prompt;
    final confirmed = await prompt;
    _cancelPrompt = null;
    if (confirmed != true) return;

    _cancelRequested = true;
    final operation = _beginOperation;
    if (operation != null) {
      try {
        await operation;
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = 'Payment setup did not complete and was cancelled.',
          );
        }
      }
    }
    if (!mounted) return;
    if (_paymentController.order != null) {
      await _paymentController.finish(widget.event, PaymentOutcome.cancelled);
    }
    if (!mounted) return;
    setState(() => _processing = false);
    Navigator.pop(context);
  }
}
