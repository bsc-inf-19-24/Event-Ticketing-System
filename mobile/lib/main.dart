

import 'package:flutter/material.dart';
import 'package:mobile/screens/signup_screen.dart';
import 'package:mobile/screens/main_shell.dart';
import 'package:mobile/features/profile/ui/profile_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ticket Master',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home:  const MainShell(),
    );
  }
}