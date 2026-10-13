class Event {
  final String title;
  final String date;
  final String time;
  final String venue;
  final int price;
  final String imagePath;
  final String category;

  const Event({
    required this.title,
    required this.date,
    required this.time,
    required this.venue,
    required this.price,
    required this.imagePath,
    required this.category,
  });
}
