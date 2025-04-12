import 'package:woosh/utils/config.dart';

class ImageUtils {
  static String getOptimizedImageUrl(String? originalUrl, {
    int width = 300,
    int height = 300,
    int quality = 80,
    String format = 'webp',
    bool progressive = true,
  }) {
    if (originalUrl?.isEmpty ?? true) {
      // Return a network URL for the placeholder
      return '${Config.baseUrl}/assets/images/ben.png';
    }

    // If URL already has transformations, return as is
    if (originalUrl!.contains('tr=')) {
      return originalUrl;
    }

    // If it's an ImageKit URL, add transformations
    if (originalUrl.contains('ik.imagekit.io')) {
      final transformations = [
        'tr:w-$width',
        'h-$height',
        'q-$quality',
        'f-$format',
        if (progressive) 'pr-true'
      ];

      final separator = originalUrl.contains('?') ? '&' : '?';
      return '$originalUrl$separator${transformations.join(",")}';
    }

    // For other URLs, return as is
    return originalUrl;

  }

  static String getThumbnailUrl(String? originalUrl) => getOptimizedImageUrl(
        originalUrl,
        width: 120,
        height: 120,
        quality: 60,
      );

  static String getDetailUrl(String? originalUrl) => getOptimizedImageUrl(
        originalUrl,
        width: 800,
        height: 800,
        quality: 90,
      );

  static String getGridUrl(String? originalUrl) => getOptimizedImageUrl(
        originalUrl,
        width: 300,
        height: 300,
        quality: 75,
      );
}
