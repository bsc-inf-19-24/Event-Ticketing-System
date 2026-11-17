String resolveServerImageUrl(String imagePath, String baseUrl) {
  final path = imagePath.trim();
  if (path.isEmpty || path.startsWith('assets/')) return path;

  final uri = Uri.tryParse(path);
  if (uri == null) return '';
  final base = baseUrl.trim().isEmpty ? null : Uri.tryParse(baseUrl);
  if (!uri.hasScheme) return base?.resolveUri(uri).toString() ?? path;

  if (base != null &&
      const {
        'localhost',
        '127.0.0.1',
        '0.0.0.0',
      }.contains(uri.host.toLowerCase())) {
    return base
        .replace(
          path: uri.path,
          query: uri.hasQuery ? uri.query : null,
          fragment: uri.hasFragment ? uri.fragment : null,
        )
        .toString();
  }

  return uri.toString();
}
