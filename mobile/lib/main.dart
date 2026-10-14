import 'package:flutter/material.dart';
import 'package:mobile/screens/main_shell.dart';
import 'package:mobile/features/profile/ui/profile_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const MainShell(),
    );
  }
}
