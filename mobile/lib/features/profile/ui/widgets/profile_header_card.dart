import 'package:flutter/material.dart';

class ProfileHeaderCard extends StatelessWidget {
  final String name;
  final VoidCallback? onAvatarTap;

  const ProfileHeaderCard({
    super.key,
    required this.name,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFEBEBE6), // Light off-white background matching prototype
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // User Avatar Icon
          GestureDetector(
            onTap: onAvatarTap,
            child: const Icon(
              Icons.account_circle,
              size: 90.0,
              color: Color(0xFF1E293B), // Dark blue/grey icon color
            ),
          ),
          const SizedBox(height: 16.0),

          // Name Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D6), // Grey badge background
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14.0,
                color: Color(0xFF4A4A4A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}