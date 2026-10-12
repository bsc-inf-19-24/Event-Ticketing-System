import 'package:flutter/material.dart';
import 'data/sample_events.dart';
import 'theme/app_colors.dart';
import 'widgets/event_card.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: EventCard(event: sampleEvents[0]),
            ),
          ),
        ),
      ),
    );
  }
}