import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Add a file to a multipart request on mobile/desktop platforms using dart:io.
///
/// @param request The HTTP request to add the file to
/// @param file The File object from dart:io
/// @param fieldName The form field name to use
Future<void> addFileToMultipartRequest(
    http.MultipartRequest request, dynamic file, String fieldName) async {
  if (file is File) {
    // Use existing File object from dart:io
    final fileExtension = path.extension(file.path).toLowerCase();

    // Determine content type based on file extension
    String mimeType = 'image/jpeg'; // Default
    if (fileExtension == '.png') {
      mimeType = 'image/png';
    } else if (fileExtension == '.gif') {
      mimeType = 'image/gif';
    } else if (fileExtension == '.pdf') {
      mimeType = 'application/pdf';
    }

    final fileName = path.basename(file.path);

    // Add file to request
    request.files.add(await http.MultipartFile.fromPath(
      fieldName,
      file.path,
      filename: fileName,
    ));
  } else {
    throw ArgumentError(
        'Invalid file type: ${file.runtimeType}. Expected File.');
  }
}
