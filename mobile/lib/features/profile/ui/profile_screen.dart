import 'package:flutter/material.dart';

import 'widgets/profile_header_card.dart';
import 'widgets/profile_menu_item.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Soft blue background color extracted from your prototype mockup
    const backgroundColor = Color(0xFFB5D1E4);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  // Left spacer balancing the right spacer for a centered title
                  SizedBox(width: 40.0),
                  Expanded(
                    child: Text(
                      'Profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  // Right spacer balancing the title position
                  SizedBox(width: 40.0),
                ],
              ),
            ),

            // Main Body Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  children: [
                    // Profile Header Card (Avatar + Name)
                    const ProfileHeaderCard(
                      name: 'James Doet',
                    ),
                    const SizedBox(height: 24.0),

                    // Menu List Items
                    ProfileMenuItem(
                      title: 'Settings',
                      showChevron: true, // Shows the right arrow icon matching prototype
                      onTap: () {
                        // TODO: Navigate to Settings screen
                      },
                    ),
                    const SizedBox(height: 12.0),

                    ProfileMenuItem(
                      title: 'Contact Support',
                      showChevron: false,
                      onTap: () {
                        // TODO: Navigate to Support screen
                      },
                    ),
                    const SizedBox(height: 12.0),

                    ProfileMenuItem(
                      title: 'Privacy Policy',
                      showChevron: false,
                      onTap: () {
                        // TODO: Navigate to Privacy Policy screen
                      },
                    ),
                    const SizedBox(height: 48.0),

                    // Log Out Button
                    SizedBox(
                      width: 180.0,
                      height: 48.0,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFE53935), // Red text color for logout
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24.0),
                          ),
                        ),
                        onPressed: () {
                          // TODO: Trigger log out logic
                        },
                        child: const Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}