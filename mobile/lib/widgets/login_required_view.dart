import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/auth_guard.dart';

class LoginRequiredView extends StatelessWidget {
  final String message;

  const LoginRequiredView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () => requireLogin(context),
              child: const Text('Log in or sign up'),
            ),
          ],
        ),
      ),
    );
  }
}