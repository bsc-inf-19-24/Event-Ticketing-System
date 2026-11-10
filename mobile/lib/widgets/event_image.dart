import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class EventImage extends StatelessWidget {
  const EventImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 44,
  });

  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(imagePath);
    final remote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final fallback = SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: AppColors.surface,
        child: Center(
          child: Icon(Icons.event, color: Colors.white54, size: iconSize),
        ),
      ),
    );
    if (imagePath.isEmpty) return fallback;
    final image = remote
        ? Image.network(
            imagePath,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : Image.asset(
            imagePath,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => fallback,
          );
    return image;
  }
}
