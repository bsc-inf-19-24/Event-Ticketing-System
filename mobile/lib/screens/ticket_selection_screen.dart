import 'package:flutter/material.dart';

import '../features/orders/models/order.dart';
import '../models/event.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'checkout_screen.dart';

/// Lets a customer select up to ten tickets for one event.
class TicketSelectionScreen extends StatefulWidget {
  const TicketSelectionScreen({super.key, required this.event});

  final Event event;

  @override
  State<TicketSelectionScreen> createState() => _TicketSelectionScreenState();
}

class _TicketSelectionScreenState extends State<TicketSelectionScreen> {
  late final List<TicketType> _types;
  late final List<int> _quantities;

  @override
  void initState() {
    super.initState();
    _types = widget.event.ticketTypes.isEmpty
        ? [TicketType(name: 'Standard', price: widget.event.price)]
        : widget.event.ticketTypes;
    _quantities = List.filled(_types.length, 0);
  }

  int get _quantity => _quantities.fold(0, (sum, quantity) => sum + quantity);
  int get _total => List.generate(
    _types.length,
    (index) => _types[index].price * _quantities[index],
  ).fold(0, (sum, price) => sum + price);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Select tickets'),
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
                Text(
                  widget.event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                for (var index = 0; index < _types.length; index++)
                  _ticketTypeCard(index),
                const SizedBox(height: 8),
                const Text(
                  'Maximum 10 tickets per order',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                    Text(
                      'MWK ${formatPrice(_total)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _quantity == 0 ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _ticketTypeCard(int index) {
    final type = _types[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.name, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  'MWK ${formatPrice(type.price)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _quantities[index] == 0
                ? null
                : () => setState(() => _quantities[index]--),
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.accent,
          ),
          Text(
            '${_quantities[index]}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          IconButton(
            onPressed: _quantity >= 10
                ? null
                : () => setState(() => _quantities[index]++),
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }

  void _continue() {
    final items = <OrderItem>[
      for (var index = 0; index < _types.length; index++)
        if (_quantities[index] > 0)
          OrderItem(
            ticketTypeName: _types[index].name,
            unitPrice: _types[index].price,
            quantity: _quantities[index],
          ),
    ];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CheckoutScreen(event: widget.event, items: items, total: _total),
      ),
    );
  }
}
