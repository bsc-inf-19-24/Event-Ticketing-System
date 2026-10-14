import 'package:flutter/material.dart';

class ProfileMenuItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool showChevron;

  const ProfileMenuItem({
    super.key,
    required this.title,
    required this.onTap,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEBEBE6), // Rounded off-white background
      borderRadius: BorderRadius.circular(16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
              ),
              if (showChevron)
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF666666),
                  size: 22.0,
                ),
            ],
          ),
        ),
      ),
    );
  }
}