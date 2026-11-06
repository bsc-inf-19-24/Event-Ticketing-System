# mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Offline ticket storage

Downloaded tickets are stored in the application's SQLite database, including
their event details, price, status, QR data, and download date. Ticket IDs are
unique, and downloaded tickets remain available after the app is closed and
reopened. Tickets saved by earlier versions in local preferences are imported
into SQLite the first time the database is opened.
