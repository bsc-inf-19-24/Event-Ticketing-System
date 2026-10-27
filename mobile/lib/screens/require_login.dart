import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/features/auth/data/presentation/provider/auth_provider.dart';

/// Returns true if the user is logged in (or has just logged in / signed up).
Future<bool> requireLogin(BuildContext context) async {
  final auth = context.read<AuthProvider>();

  if (auth.isLoggedIn) return true; // rename to match your provider

  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );
  return result == true;
}