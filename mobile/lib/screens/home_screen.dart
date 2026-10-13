import 'package:flutter/material.dart';

import '../data/sample_events.dart';
import '../models/event.dart';
import '../theme/app_colors.dart';
import '../widgets/event_card.dart';

class HomeScreen extends StatefulWidget {
  final String? customerName;
  final int ticketCount;
  final VoidCallback onViewTickets;

  const HomeScreen({
    super.key,
    this.customerName,
    this.ticketCount = 0,
    required this.onViewTickets,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> categories = ['For you', 'Sports', 'Concerts', 'Workshop'];
  String selectedCategory = 'For you';

  // Events to show, based on the selected chip
  List<Event> get filteredEvents {
    if (selectedCategory == 'For you') {
      return sampleEvents;
    }
    return sampleEvents
        .where((event) => event.category == selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'TICKET MASTER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildWelcome(),
            const SizedBox(height: 12),
            _buildTicketsBanner(),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildCategoryChips(),
            const SizedBox(height: 16),
            Expanded(child: _buildEventList()),
          ],
        ),
      ),
    );
  }

  // Builds the welcome message
  Widget _buildWelcome() {
    final name = widget.customerName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          (name == null || name.isEmpty) ? 'Welcome!' : 'Welcome back, $name!',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildTicketsBanner() {
    final count = widget.ticketCount;
    final hasTickets = count > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: hasTickets ? widget.onViewTickets : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.confirmation_number_outlined,
                color: AppColors.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasTickets
                      ? 'You have $count ${count == 1 ? 'ticket' : 'tickets'}'
                      : "You don't have any tickets yet. Pick an event below to get started.",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              if (hasTickets)
                const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  // Builds the search bar
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: const Color(0xFFF1F1F1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // Builds the chips for the categories
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;

          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            showCheckmark: false,
            selectedColor: Colors.black,
            backgroundColor: Colors.white,
            shape: const StadiumBorder(),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
            ),
            onSelected: (_) {
              setState(() {
                selectedCategory = category;
              });
            },
          );
        },
      ),
    );
  }

  // Builds the list of events
  Widget _buildEventList() {
    final events = filteredEvents;

    if (events.isEmpty) {
      return const Center(
        child: Text(
          'No events in this category yet',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: events.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => EventCard(event: events[index]),
    );
  }
}
