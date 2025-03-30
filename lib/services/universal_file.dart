// This file provides a platform-independent File implementation
// that works on both web and mobile platforms.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// We use separate imports and implementations based on platform
// Web implementation
import 'universal_file_web.dart' if (dart.library.io) 'universal_file_io.dart';

/// A cross-platform file abstraction that works on both web and mobile.
class UniversalFile {
  /// Delegate to the platform-specific implementation
  final FileDelegate _delegate;

  /// Create a UniversalFile from a platform-specific file
  UniversalFile(dynamic file) : _delegate = createFileDelegate(file);

  /// Create a platform-specific delegate
  static UniversalFile fromFile(dynamic file) {
    return UniversalFile(file);
  }

  /// Create a MultipartFile to be used in HTTP requests
  Future<http.MultipartFile> toMultipartFile(String fieldName) async {
    return _delegate.toMultipartFile(fieldName);
  }

  /// Get the file name
  String get name => _delegate.name;
}

// Helper functions to determine the type of the file
bool isIOFile(dynamic file) {
  return !kIsWeb;
}

bool isHTMLFile(dynamic file) {
  return kIsWeb;
}
