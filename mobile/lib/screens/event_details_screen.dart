import 'package:flutter/material.dart';

import '../models/event.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../utils/auth_guard.dart';

class EventDetailsScreen extends StatelessWidget {
  final Event event;

  const EventDetailsScreen({super.key, required this.event});

  static const _bodyStyle = TextStyle(color: Colors.white, fontSize: 15);

  @override
  Widget build(BuildContext context) {
    final canBuy = event.status == 'Available';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Event details'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildImage(),
                  const SizedBox(height: 16),
                  _buildInfoCard(),
                  const SizedBox(height: 16),
                  _buildTicketsCard(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: canBuy
                      ? () async {
                          final allowed = await requireLogin(context);
                          if (!allowed || !context.mounted) return;
                        }
                      : null,
                  child: Text(canBuy ? 'Buy Ticket' : 'Not available'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Image.asset(event.imagePath, fit: BoxFit.cover),
      ),
    );
  }

  // One reusable rounded box for both cards
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _buildInfoCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (event.genre.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              event.genre,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
          const SizedBox(height: 16),
          Text(event.date, style: _bodyStyle),
          Text(event.timeRange, style: _bodyStyle),
          Text(event.venue, style: _bodyStyle),
        ],
      ),
    );
  }

  Widget _buildTicketsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final ticket in event.ticketTypes) ...[
            Text(ticket.name, style: _bodyStyle),
            Text('MWK ${formatPrice(ticket.price)}', style: _bodyStyle),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text('Capacity: ${event.capacity}', style: _bodyStyle),
          Text('Status: ${event.status}', style: _bodyStyle),
        ],
      ),
    );
  }
}
