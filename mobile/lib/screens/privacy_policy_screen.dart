import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: October 2026',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 20),

            _buildPolicySection(
              title: '1. Information We Collect',
              content: 'We collect information you provide directly to us when creating an account, updating your profile, or contacting support. This includes personal information such as your name, email address, and profile picture.',
            ),
            _buildPolicySection(
              title: '2. How We Use Your Information',
              content: 'We use the collected information to operate, maintain, and provide the features and functionality of the app, as well as to communicate directly with you, such as sending email messages or push notifications.',
            ),
            _buildPolicySection(
              title: '3. Data Security',
              content: 'We implement industry-standard security practices to protect your data against unauthorized access, alteration, disclosure, or destruction.',
            ),
            _buildPolicySection(
              title: '4. Your Rights',
              content: 'You have the right to access, update, or request the deletion of your personal data at any time through your account settings or by contacting support.',
            ),
            _buildPolicySection(
              title: '5. Contact Us',
              content: 'If you have any questions or suggestions about our Privacy Policy, do not hesitate to contact us at support@example.com.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
