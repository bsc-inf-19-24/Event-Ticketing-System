import 'package:flutter/material.dart';

import '../features/orders/order_rules.dart';
import '../features/orders/models/order.dart';
import '../models/event.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'checkout_screen.dart';

/// Lets a customer select one ticket type for an event.
class TicketSelectionScreen extends StatefulWidget {
  const TicketSelectionScreen({super.key, required this.event});

  final Event event;

  @override
  State<TicketSelectionScreen> createState() => _TicketSelectionScreenState();
}

class _TicketSelectionScreenState extends State<TicketSelectionScreen> {
  late final List<TicketType> _types;
  int? _selectedIndex;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _types = widget.event.ticketTypes.isEmpty
        ? [TicketType(name: 'Standard', price: widget.event.price)]
        : widget.event.ticketTypes;
    if (_types.length == 1 && _types.single.isAvailable) _selectedIndex = 0;
  }

  int get _total => _selectedIndex == null
      ? 0
      : _types[_selectedIndex!].price * _quantity;

  int get _quantityLimit => _selectedIndex == null
      ? 0
      : (_types[_selectedIndex!].remainingInventory ?? maxTicketsPerOrder)
            .clamp(0, maxTicketsPerOrder);

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
                RadioGroup<int>(
                  groupValue: _selectedIndex,
                  onChanged: (value) => setState(() {
                    _selectedIndex = value;
                    _quantity = 1;
                  }),
                  child: Column(
                    children: [
                      for (var index = 0; index < _types.length; index++)
                        _ticketTypeCard(index),
                      if (_selectedIndex != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(child: Text('Quantity', style: TextStyle(color: Colors.white))),
                            IconButton(
                              onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                            ),
                            Text('$_quantity', style: const TextStyle(color: Colors.white, fontSize: 18)),
                            IconButton(
                              onPressed: _quantity < _quantityLimit ? () => setState(() => _quantity++) : null,
                              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                            ),
                          ],
                        ),
                        Text('Maximum 10 tickets per order', style: TextStyle(color: Colors.white70)),
                      ],
                    ],
                  ),
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
                    onPressed: _selectedIndex == null || _quantityLimit < 1 ? null : _continue,
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: RadioListTile<int>(
        value: index,
        enabled: type.isAvailable,
        activeColor: AppColors.accent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(type.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          'MWK ${formatPrice(type.price)}${type.remainingInventory == null ? '' : ' · ${type.remainingInventory} left'}${type.isAvailable ? '' : ' · Sold out'}',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  void _continue() {
    final selectedIndex = _selectedIndex;
    if (selectedIndex == null) return;
    final selectedType = _types[selectedIndex];
    if (!selectedType.isAvailable || _quantity > _quantityLimit) return;
    final items = [
      OrderItem(
        ticketTypeId: selectedType.id,
        ticketTypeName: selectedType.name,
        unitPrice: selectedType.price,
        quantity: _quantity,
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
