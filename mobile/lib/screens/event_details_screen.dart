import 'dart:async';

import 'package:flutter/material.dart';

import '../models/event.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../utils/auth_guard.dart';
import '../widgets/event_image.dart';
import 'ticket_selection_screen.dart';
import '../features/favorites/data/event_favorites_repository.dart';
import '../features/interests/data/interest_repository.dart';

class EventDetailsScreen extends StatefulWidget {
  static const routeName = '/event-details';
  final Event event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final EventFavoritesRepository _favoritesRepository =
      EventFavoritesRepository();
  final InterestRepository _interestRepository = InterestRepository();
  bool _favorite = false;

  static const _bodyStyle = TextStyle(color: Colors.white, fontSize: 15);

  Event get event => widget.event;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
    if (event.category.isNotEmpty) {
      unawaited(_interestRepository.trackCategoryView(event.category));
    }
  }

  Future<void> _loadFavorite() async {
    final eventId = event.id;
    if (eventId == null || eventId.isEmpty) return;
    final favorite = await _favoritesRepository.isFavorite(eventId);
    if (!mounted) return;
    setState(() => _favorite = favorite);
  }

  Future<void> _toggleFavorite() async {
    final eventId = event.id;
    if (eventId == null || eventId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This event cannot be favorited.')),
      );
      return;
    }
    final favorite = await _favoritesRepository.toggleFavorite(eventId);
    if (!mounted) return;
    setState(() => _favorite = favorite);
  }

  @override
  Widget build(BuildContext context) {
    final canBuy =
        event.isAvailable &&
        event.ticketTypes.any((ticket) => ticket.isAvailable);
    final buyLabel = !event.isAvailable
        ? event.statusLabel
        : event.ticketTypes.isNotEmpty &&
              !event.ticketTypes.any((ticket) => ticket.isAvailable)
        ? 'Sold out'
        : 'Buy Ticket';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Event details'),
        actions: [
          IconButton(
            tooltip: _favorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: _toggleFavorite,
            icon: Icon(
              _favorite ? Icons.favorite : Icons.favorite_border,
              color: _favorite ? AppColors.accent : Colors.white,
            ),
          ),
        ],
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TicketSelectionScreen(event: event),
                            ),
                          );
                        }
                      : null,
                  child: Text(buyLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: AspectRatio(
      aspectRatio: 16 / 10,
      child: EventImage(imagePath: event.imagePath, iconSize: 64),
    ),
  );

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
          if (event.displayGenre.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              event.displayGenre,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
          if (event.description.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(event.description.trim(), style: _bodyStyle),
          ],
          if (event.hasStart) ...[
            const SizedBox(height: 16),
            Text(event.displayDate, style: _bodyStyle),
            Text(event.timeRange, style: _bodyStyle),
          ],
          if (event.place.isNotEmpty) Text(event.place, style: _bodyStyle),
        ],
      ),
    );
  }

  Widget _buildTicketsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.ticketTypes.isEmpty)
            Text('No tickets on sale yet', style: _bodyStyle),
          for (final ticket in event.ticketTypes) ...[
            Row(
              children: [
                Expanded(
                  child: Text('${ticket.name} Ticket', style: _bodyStyle),
                ),
                if (ticket.remainingInventory == 0)
                  const Text('Sold out', style: _bodyStyle),
              ],
            ),
            Text('Price: MWK ${formatPrice(ticket.price)}', style: _bodyStyle),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text('Capacity: ${event.capacity}', style: _bodyStyle),
          Text('Status: ${event.statusLabel}', style: _bodyStyle),
        ],
      ),
    );
  }
}
