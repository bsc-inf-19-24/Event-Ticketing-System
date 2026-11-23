import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/features/auth/data/presentation/provider/auth_provider.dart';
import 'package:mobile/features/auth/logic/auth_controller.dart';
import 'package:mobile/theme/app_colors.dart';
import 'package:mobile/widgets/login_required_view.dart';

import '../data/profile_repository.dart';

import 'widgets/profile_header_card.dart';
import 'widgets/profile_menu_item.dart';

import 'package:mobile/screens/settings_screen.dart';
import 'package:mobile/screens/contact_us.dart';
import 'package:mobile/screens/privacy_policy_screen.dart';
import 'package:mobile/features/interests/ui/interests_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _phone;
  String? _city;
  String? _profileUserId;
  bool _profileLoading = false;

  @override
  void initState() {
    super.initState();
    authController.addListener(_loadProfile);
    _loadProfile();
  }

  @override
  void dispose() {
    authController.removeListener(_loadProfile);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final userId = authController.stableUserId;
    if (userId == null) {
      _profileUserId = null;
      if (mounted) {
        setState(() {
          _phone = null;
          _city = null;
        });
      }
      return;
    }
    if (_profileUserId == userId || _profileLoading) return;
    _profileLoading = true;
    if (mounted) {
      setState(() {
        _phone = null;
        _city = null;
      });
    }
    try {
      final profile = await ProfileRepository().fetchUserProfile();
      if (!mounted) {
        return;
      }
      _profileUserId = userId;
      setState(() {
        _phone =
            (profile['phone'] ??
                    profile['phoneNumber'] ??
                    profile['phone_number'])
                ?.toString();
        final location = profile['location'] is Map
            ? Map<String, dynamic>.from(profile['location'] as Map)
            : const <String, dynamic>{};
        _city = (profile['city'] ?? location['city'])?.toString();
      });
    } catch (_) {
      _profileUserId = userId;
    } finally {
      _profileLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authController,
      builder: (context, _) {
        if (!authController.isLoggedIn) {
          final sessionRestoreError = context
              .watch<AuthProvider>()
              .sessionRestoreError;
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
            body: Column(
              children: [
                const Expanded(
                  child: LoginRequiredView(
                    title: 'Log in to view your profile',
                    message: 'You need an account to manage your profile.',
                  ),
                ),
                if (sessionRestoreError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Text(
                          sessionRestoreError,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await context.read<AuthProvider>().restoreSession();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text(
                    'Settings',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }

        return _buildLoggedInProfile(context);
      },
    );
  }

  Widget _buildLoggedInProfile(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                child: Column(
                  children: [
                    // Profile Header Card (Avatar + Email)
                    ListenableBuilder(
                      listenable: authController,
                      builder: (context, child) => ProfileHeaderCard(
                        name: authController.user?.name ?? '',
                        email: authController.user?.email ?? 'Not signed in',
                      ),
                    ),
                    if (_phone?.isNotEmpty == true)
                      _ProfileValue(label: 'Phone', value: _phone!),
                    if (_city?.isNotEmpty == true)
                      _ProfileValue(label: 'City', value: _city!),
                    const SizedBox(height: 24.0),

                    // Menu List Items
                    if ((authController.user?.role ?? '')
                        .toUpperCase()
                        .contains('CUSTOMER')) ...[
                      ProfileMenuItem(
                        title: 'My Interests',
                        showChevron: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const InterestsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12.0),
                    ],
                    ProfileMenuItem(
                      title: 'Settings',
                      showChevron:
                          true, // Shows the right arrow icon matching prototype
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
                          foregroundColor: const Color(
                            0xFFE53935,
                          ), // Red text color for logout
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24.0),
                          ),
                        ),
                        onPressed: () async {
                          try {
                            await context.read<AuthProvider>().logout();
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    error.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
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

class _ProfileValue extends StatelessWidget {
  const _ProfileValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label, style: const TextStyle(color: Colors.white70)),
    subtitle: Text(value, style: const TextStyle(color: Colors.white)),
  );
}
