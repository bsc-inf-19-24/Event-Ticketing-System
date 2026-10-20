import 'package:flutter/material.dart';

import '../features/auth/logic/auth_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/login_required_view.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {

    if (!authController.isLoggedIn) {
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
