import 'package:flutter/material.dart';
import 'package:mobile/features/auth/logic/auth_controller.dart';
import 'package:mobile/theme/app_colors.dart';
import 'package:mobile/widgets/login_required_view.dart';

import 'widgets/profile_header_card.dart';
import 'widgets/profile_menu_item.dart';

import 'package:mobile/screens/settings_screen.dart';
import 'package:mobile/screens/contact_us.dart';
import 'package:mobile/screens/privacy_policy_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authController,
      builder: (context, _) {
        if (!authController.isLoggedIn) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Profile'),
              centerTitle: true,
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.background,
              foregroundColor: Colors.white,
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            body: const LoginRequiredView(
              title: 'Log in to view your profile',
              message: 'You need an account to manage your profile.',
            ),
          );
        }

        return _buildLoggedInProfile(context);
      },
    );
  }

  Widget _buildLoggedInProfile(BuildContext context) {
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
                    // Profile Header Card (Avatar + Email)
                    ListenableBuilder(
                      listenable: authController,
                      builder: (context, child) => ProfileHeaderCard(
                        email: authController.user?.email ?? 'Not signed in',
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Menu List Items
                    ProfileMenuItem(
                      title: 'Settings',
                      showChevron: true, // Shows the right arrow icon matching prototype
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12.0),

                    ProfileMenuItem(
                      title: 'Contact Support',
                      showChevron: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ContactUsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12.0),

                    ProfileMenuItem(
                      title: 'Privacy Policy',
                      showChevron: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyScreen(),
                          ),
                        );
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
                          authController.logOut();
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