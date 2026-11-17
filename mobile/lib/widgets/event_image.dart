import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/api_config.dart';
import '../utils/server_image_url.dart';

class EventImage extends StatelessWidget {
  static final Set<String> _loggedFailures = {};
  const EventImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 44,
    this.fallbackIcon = Icons.event,
  });

  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final resolvedPath = resolveServerImageUrl(imagePath, ApiConfig.baseUrl);
    final uri = Uri.tryParse(resolvedPath);
    final remote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final fallback = SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: Colors.grey.shade300,
        child: Center(
          child: Icon(
            fallbackIcon,
            color: Colors.grey.shade700,
            size: iconSize,
          ),
        ),
      ),
    );
    if (resolvedPath.isEmpty) return fallback;
    final image = remote
        ? Image.network(
            resolvedPath,
            width: width,
            height: height,
            fit: fit,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode && _loggedFailures.add(resolvedPath)) {
                debugPrint('Image failed to load: ${_safeUrl(resolvedPath)}');
              }
              return SizedBox(
                width: width,
                height: height,
                child: ColoredBox(
                  color: Colors.grey.shade300,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey.shade700,
                      size: iconSize,
                    ),
                  ),
                ),
              );
            },
          )
        : Image.asset(
            resolvedPath,
            width: width,
            height: height,
            fit: fit,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) => fallback,
          );
    return image;
  }

  String _safeUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return value;
    final query = Map<String, String>.from(uri.queryParameters)
      ..removeWhere(
        (key, _) => const {
          'token',
          'access_token',
          'refresh_token',
          'password',
          'authorization',
        }.contains(key.toLowerCase()),
      );
    return uri
        .replace(queryParameters: query.isEmpty ? null : query)
        .toString();
  }
}
