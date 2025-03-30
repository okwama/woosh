import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// Platform-specific imports
import 'image_upload_io.dart' if (dart.library.html) 'image_upload_web.dart';

/// Adds a file to an HTTP request based on the current platform.
/// This function delegates to platform-specific implementations
/// from either image_upload_io.dart (mobile/desktop) or image_upload_web.dart (web).
///
/// @param request The HTTP MultipartRequest to add the file to
/// @param file The file to upload (either File from dart:io or HTML File from dart:html)
/// @param fieldName The field name to use in the request
Future<void> addFileToRequest(
    http.MultipartRequest request, dynamic file, String fieldName) async {
  return await addFileToMultipartRequest(request, file, fieldName);
}
