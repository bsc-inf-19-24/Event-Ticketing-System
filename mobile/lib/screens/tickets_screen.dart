import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class TicketsScreen extends StatelessWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text('My Tickets', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
