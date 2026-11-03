import 'package:flutter/material.dart';
import 'package:mobile/features/auth/logic/auth_controller.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/signup_screen.dart';

import '../theme/app_colors.dart';

/// Returns true if the user may continue.
/// If not logged in, shows the prompt and returns false.
Future<bool> requireLogin(
  BuildContext context, {
  String title = 'Log in to buy tickets',
  String message = 'You need an account to buy and keep your tickets.',
}) async {
  if (authController.isLoggedIn) return true;

  await showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
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
      );
    },
  );

  return false;
}

void openLogin(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );
}

void openSignup(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SignupScreen()),
  );
}

class AuthPromptButtons extends StatelessWidget {
  final VoidCallback? onBeforeNavigate;

  const AuthPromptButtons({super.key, this.onBeforeNavigate});

  @override
  Widget build(BuildContext context) {
    return Column(
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
              onBeforeNavigate?.call();
              openLogin(context);
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
              onBeforeNavigate?.call();
              openSignup(context);
            },
            child: const Text('Create an account'),
          ),
        ),
      ],
    );
  }
}
