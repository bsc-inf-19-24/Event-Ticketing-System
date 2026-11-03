import 'package:flutter/material.dart';

import '../features/auth/logic/auth_controller.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../theme/app_colors.dart';

/// Returns true if the user may continue, otherwise shows a sign-in prompt.
Future<bool> requireLogin(
  BuildContext context, {
  String title = 'Log in to buy tickets',
  String message = 'You need an account to buy and keep your tickets.',
}) async {
  if (authController.isLoggedIn) return true;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          AuthPromptButtons(
            onBeforeNavigate: () => Navigator.pop(sheetContext),
          ),
        ],
      ),
    ),
  );
  return false;
}

/// Offers navigation to the login or sign-up screen.
class AuthPromptButtons extends StatelessWidget {
  const AuthPromptButtons({super.key, this.onBeforeNavigate});

  final VoidCallback? onBeforeNavigate;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.button,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          onPressed: () {
            final navigator = Navigator.of(context);
            onBeforeNavigate?.call();
            navigator.push(
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            );
          },
          child: const Text('Log in'),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white70),
            shape: const StadiumBorder(),
          ),
          onPressed: () {
            final navigator = Navigator.of(context);
            onBeforeNavigate?.call();
            navigator.push(
              MaterialPageRoute<void>(builder: (_) => const SignupScreen()),
            );
          },
          child: const Text('Create an account'),
        ),
      ),
    ],
  );
}
