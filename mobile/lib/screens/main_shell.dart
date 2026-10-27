import 'package:flutter/material.dart';

import '../features/auth/logic/auth_controller.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';

import 'package:mobile/features/profile/ui/profile_screen.dart';

import 'tickets_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: authController,
        builder: (context, child) {
          final pages = [
            HomeScreen(
              customerName: null,
              ticketCount: 0, // TODO: replace with real ticket count (saved tickets / API).
              onViewTickets: () {
                setState(() {
                  currentIndex = 1; // switch to the Tickets tab
                });
              },
            ),
            TicketsScreen(),
            ProfileScreen(),
          ];

          return IndexedStack(index: currentIndex, children: pages);
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: NavigationBar(
              height: 64,
              backgroundColor: AppColors.background,
              indicatorColor: Colors.transparent,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              labelTextStyle: WidgetStateProperty.all(
                const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  label: 'Home',
                  icon: Icon(Icons.home_outlined, color: Colors.white70),
                  selectedIcon: Icon(Icons.home, color: AppColors.accent),
                ),
                NavigationDestination(
                  label: 'Tickets',
                  icon: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white70,
                  ),
                  selectedIcon: Icon(
                    Icons.account_balance_wallet,
                    color: AppColors.accent,
                  ),
                ),
                NavigationDestination(
                  label: 'Profile',
                  icon: Icon(Icons.person_outline, color: Colors.white70),
                  selectedIcon: Icon(Icons.person, color: AppColors.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
