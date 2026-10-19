import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/login_required_view.dart';
import '../utils/auth_guard.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {

    if (!isLoggedIn) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: LoginRequiredView(message: 'Log in to see your profile'),
      );
    }

    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text('Profile', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
