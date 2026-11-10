import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../features/payment/logic/payment_controller.dart';
import '../models/event.dart';
import '../theme/app_colors.dart';

class PaymentResultScreen extends StatefulWidget {
  const PaymentResultScreen({
    super.key,
    required this.event,
    required this.controller,
    this.initialPaid,
    this.initialMessage,
  });

  final Event event;
  final PaymentController controller;
  final bool? initialPaid;
  final String? initialMessage;

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  bool _checking = false;
  bool? _paid;
  String? _message;

  @override
  void initState() {
    super.initState();
    _paid = widget.initialPaid;
    _message = widget.initialMessage;
  }

  Future<void> _verify() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final result = await widget.controller.verifyPendingOrder(widget.event);
      if (!mounted) return;
      setState(() {
        _paid = result;
        _message = result
            ? 'Your payment is confirmed and your tickets are ready.'
            : widget.controller.failureReason ?? 'Payment remains pending.';
      });
      if (result) {
        await Navigator.pushReplacement<void, void>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentResultScreen(
              event: widget.event,
              controller: widget.controller,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = _paid == true || widget.controller.paymentState == 'paid';
    final state = paid
        ? 'Payment confirmed'
        : widget.controller.paymentState == 'failed'
        ? 'Payment failed'
        : 'Payment pending';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Payment status')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                paid ? Icons.check_circle : Icons.hourglass_top,
                size: 64,
                color: paid ? Colors.greenAccent : Colors.orangeAccent,
              ),
              const SizedBox(height: 16),
              Text(
                state,
                style: const TextStyle(color: Colors.white, fontSize: 22),
              ),
              if (_message != null) ...[
                const SizedBox(height: 10),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
              const SizedBox(height: 20),
              if (!paid)
                FilledButton(
                  onPressed: _checking ? null : _verify,
                  child: _checking
                      ? const CircularProgressIndicator()
                      : const Text('Verify payment again'),
                ),
              if (paid)
                for (final ticket in widget.controller.purchasedTickets) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            ticket.eventName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('${ticket.ticketType} · ${ticket.date}'),
                          const SizedBox(height: 12),
                          if (ticket.qrPayload.isNotEmpty)
                            QrImageView(
                              data: ticket.qrPayload,
                              version: QrVersions.auto,
                              size: 220,
                            ),
                          SelectableText(ticket.id),
                        ],
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
}
