import 'package:flutter/material.dart';

import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
 // bool _darkMode = false;
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Preferences'),
           /**
          // Dark Mode Switch
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme across the app'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: _darkMode,
            onChanged: (bool value) {
              setState(() {
                _darkMode = value;
              });

              // TODO: Connect to your Theme Provider / Controller
            },
          ),
            **/
          // Notifications Switch
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive alerts and updates'),
            secondary: const Icon(Icons.notifications_none_outlined),
            value: _notificationsEnabled,
            onChanged: (bool value) {
              setState(() {
                _notificationsEnabled = value;
              });
              // TODO: Update backend / local push preferences
            },
          ),

          // Language Setting
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: const Text('Language'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedLanguage,
                  style: const TextStyle(color: Colors.grey),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _showLanguageSelector(context),
          ),

          const Divider(height: 32),
          _buildSectionHeader('Account & Privacy'),
          /**
          // Edit Profile Option
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
            subtitle: const Text('Update your personal info'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to Edit Profile Screen
            },
          ),
            **/
          // Privacy Policy
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),

          // Terms of Service
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTermsOfServiceDialog(context),
          ),

          const Divider(height: 32),
          _buildSectionHeader('Support & About'),

          // Help & Support
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Navigating to Support...')),
              );
            },
          ),

          // About / App Version
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About App'),
            subtitle: const Text('Version 1.0.0 (Build 100)'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Mobile App',
                applicationVersion: '1.0.0',
                applicationLegalese:
                    '© 2026 Mobile App Inc. All rights reserved.',
              );
            },
          ),

          const Divider(height: 32),
          _buildSectionHeader('Session'),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Log Out',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => _showLogoutDialog(context),
          ),

          // Delete Account
          ListTile(
            leading: const Icon(
              Icons.delete_forever_outlined,
              color: Colors.red,
            ),
            title: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _showDeleteAccountDialog(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Section Header Helper
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // Language Selection Bottom Sheet
  void _showLanguageSelector(BuildContext context) {
    final languages = ['English', 'Spanish', 'French', 'German', 'Chichewa'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Language',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...languages.map(
                (lang) => ListTile(
                  title: Text(lang),
                  trailing: _selectedLanguage == lang
                      ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedLanguage = lang;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Terms of Service Modal Dialog
  void _showTermsOfServiceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Terms of Service'),
          content: const SingleChildScrollView(
            child: Text(
              'Welcome to our app! By using our service, you agree to comply with and be bound by the following terms...\n\n'
              '1. Usage Rules\n'
              '2. User Conduct\n'
              '3. Intellectual Property Rights\n'
              '4. Limitation of Liability',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Logout Dialog
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text(
            'Are you sure you want to log out of your account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Execute sign-out logic
              },
              child: const Text('Log Out', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // Delete Account Dialog
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'This action is permanent and cannot be undone. All your data will be erased.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Trigger delete account API
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
